-- Checkbox indicator. Its row or button owns state and handles clicks.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local glyph = require("components.glyph")

---@param checked boolean|Signal<boolean?>
return function(checked)
    local on = util.lift(checked, function(value) return value == true end)
    return rect {
        width = theme.icon.md,
        height = theme.icon.md,
        radius = theme.radius.sm / 2,
        background = util.choose(on, theme.GLASS_CONTROL_SUBTLE, theme.CLEAR),
        border_width = theme.border_width,
        border_color = theme.GLASS_BORDER,
        children = { glyph(icons.check, theme.FG, theme.icon.sm, {
            width = "Fill", align = "Center", align_v = "Center", visible = on,
        }) },
    }
end
