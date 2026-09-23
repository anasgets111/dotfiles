-- A modal's search bar around the caller's `textfield`, which paints only text and caret: ground,
-- ring and glyph. The ring stays accent, since `autofocus` keeps the field focused while the modal is up.
local theme = require("config.theme")
local icons = require("config.icons")
local glyph = require("components.glyph")

return function(field)
    field.width, field.height, field.autofocus = "Fill", "Fill", true
    field.font_size, field.foreground = theme.font.xl, theme.FG
    return rect {
        width = "Fill",
        height = theme.control.xl,
        radius = theme.radius.md,
        background = theme.GLASS_INPUT,
        border_width = theme.border_width,
        border_color = theme.ACCENT,
        padding = { left = theme.spacing.lg, right = theme.spacing.lg },
        children = { row {
            width = "Fill",
            height = "Fill",
            align_v = "Center",
            spacing = theme.spacing.md,
            children = { glyph(icons.search, theme.ACCENT, theme.icon.md, { align_v = "Center" }), field },
        } },
    }
end
