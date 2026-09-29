-- Hostname-shaped input opens as a link; any other query searches the web.
local icons = require("config.icons")

local M = {}

M.ENGINE = "DuckDuckGo"
local SEARCH_URL = "https://duckduckgo.com/?q="

---@param text string Already trimmed by the launcher.
---@return LauncherRow
function M.claims(text)
    local is_url = text:match("^https?://[^%s]+$") ~= nil or text:match("^[%w%-]+%.[%w%-%.]+[%w]/?[^%s]*$") ~= nil
    local target = is_url and (text:match("^https?://") and text or "https://" .. text)
        or SEARCH_URL .. text:gsub("[^%w%-_%.~]", function(char)
            return string.format("%%%02X", char:byte())
        end)
    return {
        kind = "web",
        hint = "Enter to open",
        icon = icons.web,
        title = is_url and target or text,
        subtitle = is_url and "Open link" or "Web search",
        payload = target,
    }
end

return M
