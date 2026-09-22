-- The bell half of the clock pill: a glyph with an inline count while notifications wait, or the
-- plain bell, with DND winning over the count. Returned as parts because `right_side.lua` builds one
-- ground and one click target over bell and clock together.
local theme = require("config.theme")
local icons = require("config.icons")
local cell = require("components.cell")
local ui_state = require("lib.ui_state")
local notification_history = require("modules.bar.panels.notification_history")

local function waiting(n)
    return #((n and n.feed) or {})
end

local bell = cell(mantle.notifications:map(function(n)
    if n and n.dnd then
        return icons.bell_off
    end
    local count = waiting(n)
    if count > 0 then
        return icons.bell_active .. " " .. tostring(count)
    end
    return icons.bell
end), mantle.notifications:map(function(n)
    if n and n.dnd then
        return theme.DIM
    end
    return waiting(n) > 0 and theme.ACCENT or theme.text_contrast(theme.GLASS_CONTROL)
end), theme.font.md, { align_v = "Center" })

return {
    kind = notification_history.kind,
    bell = bell,
    open = function(rect)
        ui_state.toggle_panel(notification_history.kind, rect)
    end,
}
