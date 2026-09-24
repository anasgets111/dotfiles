-- "50 usd to egp" becomes one row whose Enter copies the converted amount.
--
-- The engine has no HTTP, so rates come from `curl` and decode in `exit_cb`, the only callback that
-- knows the body is complete. They are stored in `lib/store.lua`, so a restart inside the day
-- reuses them, and staleness is checked on `mantle.system`'s 1 Hz push for want of a config timer.
-- A query whose target has no rate claims nothing, so nothing shows before the first fetch.
local util = require("lib.util")
local store = require("lib.store")

local M = {}

local REFRESH_SECONDS = 86400
local URL = "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json"

local SYMBOLS = { ["$"] = "usd", ["€"] = "eur", ["£"] = "gbp", ["¥"] = "jpy", ["₹"] = "inr", ["₿"] = "btc" }

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

-- A currency code is three to five letters, or one of the symbols.
local function currency(token)
    return SYMBOLS[token] or (token:match("^%a%a%a%a?%a?$") and token:lower())
end

-- Every separator position, earliest first, until the tail reads as a currency. `in` also matches
-- inside `inr`, and the lazy group in the QML regex this ports backtracked for exactly that reason.
-- Stopping at the first match would split `100 inr to usd` into `100` and `r to usd`. An empty tail
-- passes because a trailing separator names no target and falls through to the default.
---@return string|nil source, string|nil target
local function split(text)
    for at = 1, #text do
        for _, separator in ipairs(SEPARATORS) do
            local from, to = text:find("^" .. separator, at)
            local target = from and text:sub(to + 1)
            if target and (target == "" or currency(target)) then
                return text:sub(1, from - 1), target
            end
        end
    end
end

-- Accepts "50 usd", "$50", "50$", a bare "$", and a bare "usd" when `allow_implicit_amount` says
-- so. That needs a separator before it, or no application answering the query.
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

-- Unicode regional indicators start 127397 code points after ASCII letters.
local function flag(code)
    local country = FLAGS[code] or code:sub(1, 2)
    if not country:match("^%a%a$") then
        return country:upper()
    end
    local first, second = country:upper():byte(1, 2)
    return utf8.char(0x1F1E6 + first - 65, 0x1F1E6 + second - 65)
end

-- Matches `date_time.lua`'s fixed twelve-hour clock.
local function updated_text(at, now)
    if not at or at == 0 then
        return ""
    end
    local same_day = os.date("%Y%j", at) == os.date("%Y%j", now)
    return "Updated " .. os.date(same_day and "%I:%M %p" or "%b %d, %I:%M %p", at)
end

-- One request in flight. A reload kills a live one, and its `exit_cb(nil)` clears this guard.
local requesting = state("currency_fetching", false)
-- A failure leaves `currency_updated_at` stale, so without a deadline the tick would curl every
-- second for as long as the endpoint is down. `nil` is a reload's kill or a failed spawn: retry soon.
local next_attempt = state("currency_next_attempt", 0)
local RETRY_SECONDS = 3600
local KILLED_RETRY_SECONDS = 5

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
            local wait = code and RETRY_SECONDS or KILLED_RETRY_SECONDS
            log.warn(("currency: fetch failed (curl exited %s), retrying in %ds"):format(tostring(code), wait))
            next_attempt:set(((mantle.system:get() or {}).monotonic or 0) + wait)
            return
        end
        -- `data.usd["usd"] = 1.0`: the base is absent from its own table.
        rates.usd = 1.0
        store:set("currency_rates", rates)
        store:set("currency_updated_at", os.time())
    end)
end

-- Wait for storage: `currency_updated_at` reads its `0` default first, and fetching on that spends
-- a request the stored rates were about to answer. A level test, not a first-push edge, which a
-- reload would install too late to ever see.
mantle.system:on_change(function(system)
    if not system or mantle.storage:get() == nil then
        return
    end
    -- Two clocks: the retry is this session's duration, freshness a wall-clock stamp on disk.
    if system.monotonic < next_attempt:get() then
        return
    end
    if system.time - (store.currency_updated_at:get() or 0) >= REFRESH_SECONDS then
        fetch()
    end
end)

-- `allow_bare` lets a code with no amount and no separator claim the row.
---@return LauncherRow|nil
function M.claims(query, rates, updated_at, allow_bare)
    local text = util.trim(query):lower()
    local source, target = split(text)
    local amount, from = parse_source(source or text, source ~= nil or allow_bare)
    if not (amount and from) then
        return nil
    end
    -- No target is `parsed.f === "egp" ? "usd" : "egp"`.
    local to = (target or "") == "" and (from == "egp" and "usd" or "egp") or currency(target or "")
    if not to or from == to then
        return nil
    end
    rates = rates or {}
    local from_rate, to_rate = tonumber(rates[from]), tonumber(rates[to])
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
