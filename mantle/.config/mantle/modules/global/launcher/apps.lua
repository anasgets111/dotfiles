-- Desktop entries ranked for a query, field by field as the Quickshell reference does. Joining
-- fields lets a query borrow letters from a long comment and return unrelated apps.
local util = require("lib.util")

local M = {}

local function field_score(value, needle, weight)
    local text = (value or ""):lower()
    if text == "" then
        return -1
    end
    if text == needle then
        return 5000 + weight
    end
    if text:sub(1, #needle) == needle then
        return 4000 + weight - math.min(99, #text - #needle)
    end
    local start = text:find(needle, 1, true)
    if start then
        if text:sub(start - 1, start - 1):match("[%s%-%_%.%/]") then
            return 3000 + weight
        end
        return 2000 + weight - math.min(99, start - 1)
    end
    return fuzzy(text, needle) and 1000 + weight - math.min(99, #text - #needle) or -1
end

-- Launch count plus a stepped recency bonus: a log keeps a hundred launches from burying last
-- hour's, and the steps need no decay job.
local function usage_of(usage, now, id)
    local entry = usage[id]
    if not entry then
        return 0
    end
    local age = now - entry.last
    local recency = age < 3600 and 8 or age < 86400 and 6 or age < 604800 and 4 or age < 2592000 and 2 or 0
    return math.log(entry.count + 1, 2) + recency
end

-- Every match, best first; an empty query matches everything. Usage breaks score ties, but never
-- outranks a better field match. `best` lets a bare currency code yield to a strong app match.
---@return { apps: AppSummary[], best: integer }
function M.rank(applications, text, usage)
    local needle = util.trim(text):lower()
    usage = usage or {}
    -- ponytail: recency can lag while the launcher sits idle. Feed an hourly clock if it matters.
    local now = os.time()
    local scored = {}
    local best = 0
    for _, app in ipairs(applications and applications.entries or {}) do
        local value = needle == "" and 0 or math.max(
            field_score(app.name, needle, 80),
            field_score(app.generic_name, needle, 60),
            field_score(table.concat(app.keywords or {}, " "), needle, 40),
            field_score(app.id, needle, 20)
        )
        if not app.no_display and value >= 0 then
            scored[#scored + 1] = { app = app, score = value, usage = usage_of(usage, now, app.id) }
            best = math.max(best, value)
        end
    end
    table.sort(scored, function(left, right)
        if left.score ~= right.score then
            return left.score > right.score
        end
        if left.usage ~= right.usage then
            return left.usage > right.usage
        end
        return left.app.name < right.app.name
    end)
    local apps = {}
    for i, entry in ipairs(scored) do
        apps[i] = entry.app
    end
    return { apps = apps, best = best }
end

return M
