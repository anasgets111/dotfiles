-- An arithmetic query becomes one row whose Enter copies the result, with JavaScript's arithmetic.
--
-- `load` is guarded twice: the allowlist admits no identifier, and the empty `_ENV` leaves nothing
-- to reach. `--` and `//` pass the allowlist but Lua reads them as a comment and floor division, so
-- they are refused. Rewrites: `**` to `^`, a leading unary `+` dropped, `N%` to `(N/100)`, and
-- integers gain `.0` because Lua integers wrap (`4294967296*4294967296` would answer 0).
local icons = require("config.icons")
local util = require("lib.util")

local M = {}

-- `/^[\d\s+\-*/().,%^]+$/`, in the order that pattern lists them.
local ALLOWED = "^[%d%s%+%-%*/%(%)%.,%%%^]+$"

---@param input string Already trimmed by the launcher.
---@return LauncherRow|nil
function M.claims(input)
    if not input:match(ALLOWED) or not input:match("%d") or not input:match("[%+%-%*/%^%%]") then
        return nil
    end
    -- `!/^\d+\.?\d*$/`: a bare number is not a calculation.
    if input:match("^%d+%.?%d*$") or input:find("--", 1, true) or input:find("//", 1, true) then
        return nil
    end
    local expression = input
        :gsub(",", "")
        :gsub("%*%*", "^")
        :gsub("^%s*%+", "")
        :gsub("(%d+%.?%d*)%%", "(%1/100)")
        :gsub("%d+%.?%d*", function(number)
            return number:find(".", 1, true) and number or (number .. ".0")
        end)
    local chunk = load("return " .. expression, "=calc", "t", {})
    if not chunk then
        return nil
    end
    local ok, value = pcall(chunk)
    -- NaN or infinite.
    if not ok or type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
        return nil
    end
    -- Twelve significant digits; `%g` drops trailing zeros.
    local result = value == math.floor(value) and util.thousands(string.format("%.0f", value))
        or string.format("%.12g", value)
    return {
        kind = "calc",
        badge = "CALC",
        hint = "Enter to copy",
        icon = icons.calc,
        title = input .. " = " .. result,
        subtitle = "Calculator",
        payload = result,
    }
end

return M
