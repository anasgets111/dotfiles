-- A labelled button, for when the word is the point: "Update", "Retry", "Close". `opts.icon` is the
-- theme icon a sender's `action-icons` key names, beside the label or alone without one.
local theme = require("config.theme")
local cell = require("components.cell")

-- `solid` is the only opaque ground -- other tints show panel glass through the label -- and picks
-- its own foreground.
local function opaque(colour, lifted)
    return { rest = colour, hover = lifted, border = colour, text = theme.text_contrast(colour) }
end

local GROUND = {
    accent = { rest = theme.ACCENT_SUBTLE, hover = theme.ACCENT_LIGHT, border = theme.ACCENT_MEDIUM },
    quiet = { rest = theme.GLASS_CONTROL, hover = theme.GLASS_CONTROL_HOVER, border = theme.GLASS_BORDER },
    solid = opaque(theme.ACCENT, theme.ACCENT_HOVER),
    -- Solid's shape in alert colour, for the one action that ends something already running.
    danger = opaque(theme.RED, theme.RED_HOVER),
}

---@param label string|Bound
---@param on_activate? fun() Absent on a `submit` button, whose click is the field's Enter.
---@param slot string A `hover` slot unique to this button; two buttons sharing one light up together.
---@param opts? { icon?: string, glyph?: string|Bound, tone?: "accent"|"quiet"|"solid"|"danger", width?: integer|"Fill", height?: integer, visible?: boolean|Bound, disabled?: Signal, submit?: boolean, on_button?: fun(rect: Rect, button: string) }
return function(label, on_activate, slot, opts)
    opts = opts or {}
    local ground = GROUND[opts.tone or "accent"]
    local hovered = hover(slot)
    -- A `row` starts its children, so a filling button needs the row and label to fill too.
    local fill = opts.width == "Fill" and "Fill" or nil
    local children = {}
    if opts.icon then
        children[#children + 1] = icon {
            name = opts.icon,
            size = theme.icon.sm,
            align_v = "Center",
            foreground = ground.text,
        }
    end
    -- The Nerd Font half of the same slot: a `text` node, so it takes the button's ink.
    if opts.glyph then
        children[#children + 1] = text {
            content = opts.glyph,
            foreground = ground.text or theme.FG,
            font_size = theme.icon.sm,
            font = theme.icon_font,
            align_v = "Center",
        }
    end
    if label and label ~= "" then
        local label_content = type(label) == "string" and { { text = label, bold = true } } or label
        children[#children + 1] = cell(label_content, ground.text or theme.FG, theme.font.sm, {
            align = "Center",
            align_v = "Center",
            width = fill,
        })
    end
    return button {
        submit = opts.submit,
        width = opts.width,
        height = opts.height or theme.control.md,
        align_v = "Center",
        radius = theme.radius.md,
        visible = opts.visible,
        -- Dims and ignores clicks, keeping the button's place in the row.
        opacity = opts.disabled and opts.disabled:map(function(off)
            return off and theme.opacity.disabled or 1
        end),
        hover = hovered,
        background = hovered:map(function(is_hovered)
            return is_hovered and ground.hover or ground.rest
        end),
        border_width = theme.border_width,
        border_color = ground.border,
        padding = { left = theme.spacing.md, right = theme.spacing.md },
        animate = { background = theme.animation_ms },
        on_click = function(_, mouse_button)
            if mouse_button == "left" and on_activate and not (opts.disabled and opts.disabled:get()) then
                on_activate()
            end
        end,
        children = { row { width = fill, height = "Fill", align_v = "Center", spacing = theme.spacing.xs, children = children } },
    }
end
