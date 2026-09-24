-- Small dim uppercase section label. Padding on top only is headroom, so the label sits tight
-- against the list it introduces.
local theme = require("config.theme")
local util = require("lib.util")

---@param content string|Bound
return function(content)
    return text {
        content = util.lift(content, function(label)
            return { { text = label:upper(), bold = true } }
        end),
        foreground = theme.TEXT_MUTED,
        font_size = theme.font.xs,
        height = theme.section_header_height,
        padding = { top = theme.spacing.xs, left = theme.spacing.sm },
    }
end
