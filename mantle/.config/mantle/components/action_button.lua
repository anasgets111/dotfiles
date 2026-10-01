-- A labelled button, for when the word is the point: "Update", "Retry", "Close". `opts.icon` is the
-- theme icon a sender's `action-icons` key names, beside the label or alone without one.
local util = require("lib.util")
local theme = require("config.theme")
local cell = require("components.cell")
local glyph = require("components.glyph")

-- `solid` and `danger` are the only opaque grounds and pick their own ink. The other tints show panel
-- glass through the label.
local function opaque(colour, lifted)
    return { rest = colour, hover = lifted, border = colour, text = theme.text_contrast(colour) }
end

local GROUND = {
    accent = { rest = theme.ACCENT_SUBTLE, hover = theme.ACCENT_LIGHT, border = theme.ACCENT_MEDIUM },
    quiet = { rest = theme.GLASS_CONTROL, hover = theme.GLASS_CONTROL_HOVER, border = theme.GLASS_BORDER },
    subtle = { rest = theme.GLASS_CONTROL_SUBTLE, hover = theme.GLASS_CONTROL_HOVER, border = theme.BORDER_SUBTLE },
    solid = opaque(theme.ACCENT, theme.ACCENT_HOVER),
    -- The recorder's Stop, the one action that ends something already running.
    danger = opaque(theme.RED, theme.RED_HOVER),
}

---@param label string|Bound
---@param on_activate? fun() Absent on a `submit` button, whose click is the field's Enter.
---@param slot string A `hover` slot unique to this button; two buttons sharing one light up together.
---@param opts? { icon?: string, glyph?: string|Bound, tone?: "accent"|"quiet"|"subtle"|"solid"|"danger", width?: integer|"Fill", height?: integer, max_lines?: integer, visible?: boolean|Bound, disabled?: Signal, submit?: boolean }
return function(label, on_activate, slot, opts)
    opts = opts or {}
    local ground = GROUND[opts.tone or "accent"]
    local foreground = ground.text or theme.FG
    local hovered = hover(slot)
    local height = opts.height or theme.control.md
    local children = {}
    if opts.icon then
        children[#children + 1] = icon {
            name = opts.icon,
            size = theme.icon.sm,
            align_v = "Center",
            foreground = foreground,
        }
    end
    -- A Nerd Font glyph in the same slot, a `text` node, so it takes the button's ink.
    if opts.glyph then
        children[#children + 1] = glyph(opts.glyph, foreground, theme.icon.sm, { align_v = "Center" })
    end
    if label and label ~= "" then
        local label_content = type(label) == "string" and { { text = label, bold = true } } or label
        children[#children + 1] = cell(label_content, foreground, theme.font.sm, {
            width = opts.width and "Fill" or nil,
            align = "Center",
            align_v = "Center",
            wrap = opts.max_lines and "Word" or nil,
            max_lines = opts.max_lines,
        })
    end
    return row {
        submit = opts.submit,
        width = opts.width,
        height = not opts.max_lines and height or nil,
        min_height = opts.max_lines and height or nil,
        align_v = opts.max_lines and "Stretch" or "Center",
        radius = theme.radius.md,
        visible = opts.visible,
        -- Dims and ignores clicks, keeping the button's place in the row.
        opacity = opts.disabled and util.choose(opts.disabled, theme.opacity.disabled, 1),
        hover = hovered,
        background = util.choose(hovered, ground.hover, ground.rest),
        border_width = theme.border_width,
        border_color = ground.border,
        padding = {
            left = theme.spacing.md,
            right = theme.spacing.md,
            top = opts.max_lines and theme.spacing.sm or nil,
            bottom = opts.max_lines and theme.spacing.sm or nil,
        },
        animate = { background = theme.animation_ms },
        on_click = function(_, mouse_button)
            if mouse_button == "left" and on_activate and not (opts.disabled and opts.disabled:get()) then
                on_activate()
            end
        end,
        align_h = "Center",
        spacing = theme.spacing.xs,
        children = children,
    }
end
