-- Small dim uppercase section label. Padding on top only is headroom, so the label sits tight
-- against the list it introduces.
local theme = require("config.theme")

return function(content)
    return text {
        content = { { text = content:upper(), bold = true } },
        foreground = theme.DIM,
        font_size = theme.font.xs,
        opacity = theme.opacity.muted,
        padding = { top = theme.spacing.xs, left = theme.spacing.sm },
    }
end
