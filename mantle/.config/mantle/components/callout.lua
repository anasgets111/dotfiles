-- A glyph and a line of text on a tinted ground: an error, a hold, or a note standing in for content.
local theme = require("config.theme")
local cell = require("components.cell")
local glyph = require("components.glyph")

local TONES = {
    error = { theme.RED, theme.with_opacity(theme.RED, theme.opacity.subtle) },
    active = { theme.ACCENT, theme.ACCENT_SUBTLE },
    neutral = { theme.DIM, theme.GLASS_CONTENT },
}

---@param codepoint string|Bound
---@param content string|Bound
---@param opts? { tone?: "error"|"active"|"neutral", height?: integer, radius?: integer, visible?: boolean|Bound, trailing?: table }
return function(codepoint, content, opts)
    opts = opts or {}
    local ink, ground = table.unpack(TONES[opts.tone or "error"])
    return row {
        width = "Fill",
        height = opts.height,
        align_v = "Center",
        spacing = theme.spacing.sm,
        padding = { left = theme.spacing.md, right = theme.spacing.sm, top = theme.spacing.xs, bottom = theme.spacing.xs },
        radius = opts.radius or theme.radius.sm,
        background = ground,
        visible = opts.visible,
        children = {
            glyph(codepoint, ink, theme.icon.sm, { align_v = "Center" }),
            cell(content, ink, theme.font.sm, { width = "Fill", align_v = "Center", wrap = "Word", max_lines = 2 }),
            opts.trailing,
        },
    }
end
