-- "50 usd to egp" becomes one row whose Enter copies the converted amount.
--
-- `process.run("curl", ...)` decodes in `exit_cb` because only that callback knows the body is
-- complete. `docs/roadmap.md` routes currency through an HTTP CLI rather than a capability, and the
-- engine has no HTTP to offer either way.
--
-- Rates live in `lib/store.lua`, so a restart inside the day reuses them.
--
-- No config-owned timer exists, so staleness is checked on `mantle.system`'s 1 Hz push: one
-- integer compare a second. `modules/bar/indicators/updates.lua` seeds from storage's first push;
-- this needs no seed branch, because the tick a second later does the same work.
--
-- `rates` starts empty, and a query whose target is missing claims nothing, so no row shows before
-- the first fetch lands.
local util = require("lib.util")
local store = require("lib.store")

local M = {}

local REFRESH_SECONDS = 86400
local URL = "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json"

local SYMBOLS = {
    ["$"] = "usd",
    ["€"] = "eur",
    ["£"] = "gbp",
    ["¥"] = "jpy",
    ["₹"] = "inr",
    ["₿"] = "btc",
}

-- Three countries whose code is not their first two letters, and the cryptocurrencies that have
-- a sign instead of a flag.
local FLAGS = {
    eur = "eu",
    gbp = "gb",
    usd = "us",
    btc = "₿",
    eth = "Ξ",
    ltc = "Ł",
    doge = "Ð",
    xrp = "✕",
    ada = "₳",
    sol = "₴",
    dot = "●",
    usdt = "₮",
    usdc = "₵",
}

-- `(?:to|in|->|=>|=)`. Matched against a lowercased query, so the word forms need no case class.
-- The earliest match wins.
local SEPARATORS = { "%s+to%s*", "%s+in%s*", "%s*%->%s*", "%s*=>%s*", "%s*=%s*" }

---A currency code is three to five letters, or one of the symbols.
---@param token string
---@return string|nil
local function currency(token)
    if SYMBOLS[token] then
        return SYMBOLS[token]
    end
    if token:match("^%a+$") and #token >= 3 and #token <= 5 then
        return token:lower()
    end
    return nil
end

---Earliest separator first, then each later one until the tail reads as a currency. `in` also
---matches inside `inr`, and the lazy group in the QML regex this ports backtracked for exactly
---that reason; taking the first match and stopping splits `100 inr to usd` into `100` and
---`r to usd`. An empty tail is accepted because a trailing separator names no target and falls
---through to the default.
---@return string|nil source, string|nil target
local function split(text)
    local cuts = {}
    for _, separator in ipairs(SEPARATORS) do
        local at = 1
        while true do
            local from, to = text:find(separator, at)
            if not from then
                break
            end
            cuts[#cuts + 1] = { from = from, to = to }
            at = from + 1
        end
    end
    table.sort(cuts, function(a, b)
        return a.from < b.from
    end)
    for _, cut in ipairs(cuts) do
        local target = text:sub(cut.to + 1)
        if target == "" or currency(target) then
            return text:sub(1, cut.from - 1), target
        end
    end
    return nil, nil
end

---Accepts "50 usd", "$50", "50$", a bare "$", and a bare "usd" when `allow_implicit_amount`
---says so: either a separator precedes it, or no application answered the query.
---@return number|nil amount, string|nil code
local function parse_source(text, allow_implicit_amount)
    text = util.trim(text)
    local amount, token = text:match("^(%d+%.?%d*)%s*(.+)$")
    if amount then
        local code = currency(token)
        return code and tonumber(amount) or nil, code
    end
    for symbol, code in pairs(SYMBOLS) do
        if text:sub(1, #symbol) == symbol then
            local rest = util.trim(text:sub(#symbol + 1))
            if rest == "" then
                return 1, code
            end
            return rest:match("^%d+%.?%d*$") and tonumber(rest) or nil, code
        end
    end
    if allow_implicit_amount then
        local code = currency(text)
        if code then
            return 1, code
        end
    end
    return nil, nil
end

---Unicode regional indicators start 127397 code points after ASCII letters.
local function flag(code)
    local country = FLAGS[code] or code:sub(1, 2)
    if not country:match("^%a%a$") then
        return country:upper()
    end
    local first, second = country:upper():byte(1, 2)
    return utf8.char(0x1F1E6 + first - 65, 0x1F1E6 + second - 65)
end

---Formats against `date_time.lua`'s fixed twelve-hour clock.
local function updated_text(at, now)
    if not at or at == 0 then
        return ""
    end
    local same_day = os.date("%Y%j", at) == os.date("%Y%j", now)
    return "Updated " .. os.date(same_day and "%I:%M %p" or "%b %d, %I:%M %p", at)
end

-- `_requesting`: one request in flight, and a failure leaves the stored rates alone. Both live in
-- `state`, not module locals: a local is rebuilt by every in-place reload while the `process.run`
-- child it guards is not, so an unrelated config save would clear the guard under a live request.
-- `state` has the child's own lifetime.
local requesting = state("currency_fetching", false)
-- A failure must move a deadline. Without one, `currency_updated_at` stays stale and the 1 Hz tick
-- below starts a fresh curl every second for as long as the endpoint is down.
local next_attempt = state("currency_next_attempt", 0)
local RETRY_SECONDS = 3600

local function fetch()
    if requesting:get() then
        return
    end
    requesting:set(true)
    local body = {}
    process.run("curl", { "-fsS", "--max-time", "5", URL }, function(line, stream)
        if stream == "stdout" then
            body[#body + 1] = line
        end
    end, function(code)
        requesting:set(false)
        local decoded = code == 0 and json.decode(table.concat(body)) or nil
        local rates = decoded and decoded.usd
        if type(rates) ~= "table" then
            log.warn(("currency: fetch failed (curl exited %s), retrying in %ds"):format(tostring(code), RETRY_SECONDS))
            next_attempt:set(((mantle.system:get() or {}).monotonic or 0) + RETRY_SECONDS)
            return
        end
        -- `data.usd["usd"] = 1.0`: the base is absent from its own table.
        rates.usd = 1.0
        store:set("currency_rates", rates)
        store:set("currency_updated_at", os.time())
    end)
end

-- Until storage pushes, `currency_updated_at` reads its `0` default, and fetching on that would
-- spend a request the stored rates were about to answer. A level test on the signal, not a handler
-- watching for its first push: an in-place reload installs the new handler after the capability has
-- already pushed, so an edge gate would arm on a cold start and never again.
mantle.system:on_change(function(system)
    if not system or mantle.storage:get() == nil then
        return
    end
    -- Two clocks on purpose: the retry is a duration this session owns, while freshness
    -- is measured against a stamp on disk that outlived the session and is therefore wall time.
    if system.monotonic < next_attempt:get() then
        return
    end
    if system.time - (store.currency_updated_at:get() or 0) >= REFRESH_SECONDS then
        fetch()
    end
end)

---@param query string
---@param rates table<string, number>|nil
---@param updated_at integer|nil
---@param allow_bare? boolean Whether a code with no amount and no separator may claim the row.
---@return LauncherRow|nil
function M.claims(query, rates, updated_at, allow_bare)
    local text = util.trim(query):lower()
    local source, target = split(text)
    local amount, from = parse_source(source or text, source ~= nil or allow_bare == true)
    if not (amount and from) then
        return nil
    end
    local to
    if target and target ~= "" then
        to = currency(target)
        if not to then
            return nil
        end
    else
        -- `parsed.f === "egp" ? "usd" : "egp"`.
        to = from == "egp" and "usd" or "egp"
    end
    if from == to then
        return nil
    end
    local from_rate = tonumber((rates or {})[from])
    local to_rate = tonumber((rates or {})[to])
    if not from_rate or not to_rate or from_rate <= 0 or to_rate <= 0 then
        return nil
    end
    local converted = (amount / from_rate) * to_rate
    if converted ~= converted or converted == math.huge then
        return nil
    end
    local result
    if math.abs(converted) < 0.01 and converted ~= 0 then
        result = string.format("%.6g", converted)
    else
        local decimals = converted >= 100 and 2 or (converted >= 1 and 4 or 6)
        result = util.thousands(string.format("%." .. decimals .. "f", converted))
    end
    return {
        kind = "currency",
        badge = "FX",
        hint = "Enter to copy result",
        icon = flag(from),
        icon_is_text = true,
        title = string.format("%s %s → %s %s", string.format("%.14g", amount), from:upper(), result, to:upper()),
        subtitle = updated_text(updated_at, os.time()),
        payload = result,
    }
end

return M
