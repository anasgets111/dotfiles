local theme = require("config.theme")

return function(glyph, on_activate, opts)
    opts = opts or {}
    local side = opts.size or theme.item_height
    local radius = opts.radius or (opts.shape == "rounded" and theme.item_radius or side / 2)
    ---@type Color|Signal
    local base = opts.background or theme.GLASS_CONTROL
    ---@type Color|Signal
    local base_hover = opts.background_hover or theme.GLASS_CONTROL_HOVER

    local hovered = opts.slot and hover(opts.slot) or nil

    local function is_signal(value)
        return type(value) == "userdata"
    end

    ---@type Color|Signal
    local ground
    if not hovered then
        ground = base
    elseif is_signal(base) and is_signal(base_hover) then
        ---@cast base Signal
        ---@cast base_hover Signal
        ground = computed({ hovered, base, base_hover }, function(is_hovered, plain, lit)
            return is_hovered and lit or plain
        end)
    elseif is_signal(base) then
        ---@cast base Signal
        ground = computed({ hovered, base }, function(is_hovered, plain)
            return is_hovered and base_hover or plain
        end)
    elseif is_signal(base_hover) then
        ---@cast base_hover Signal
        ground = computed({ hovered, base_hover }, function(is_hovered, lit)
            return is_hovered and lit or base
        end)
    else
        ground = hovered:map(function(is_hovered)
            return is_hovered and base_hover or base
        end)
    end

    ---@type Color|Signal
    local foreground = opts.foreground
    if foreground == nil then
        if is_signal(ground) then
            ---@cast ground Signal
            foreground = ground:map(theme.text_contrast)
        else
            ---@cast ground Color
            foreground = theme.text_contrast(ground)
        end
    end

    ---@type Color|Signal
    local border_color = theme.GLASS_BORDER
    if hovered then
        border_color = hovered:map(function(is_hovered)
            return is_hovered and theme.GLASS_BORDER_HOVER or theme.GLASS_BORDER
        end)
    end

    if opts.selected ~= nil then
        border_color = opts.selected:map(function(is_selected)
            return is_selected and theme.ACCENT or theme.GLASS_BORDER
        end)
    end

    local function glyph_node()
        return text {
            content = glyph,
            foreground = foreground,
            font_size = opts.icon_size or theme.icon.md,
            font = opts.icon_font,
            animate = { foreground = theme.animation_ms },
            align_h = "Center",
            align_v = "Center",
        }
    end

    -- `opts.art` is a themed name or path drawn in place of the glyph, the split
    -- `components/panel_row.lua` makes: `PaintStyle::Icon` takes no tint, so artwork and a tintable
    -- glyph are two nodes, not one property. An empty name falls back to the glyph, which is what
    -- lets a workspace draw its window's icon and its number from one button.
    local function face(art)
        if art == nil or art == "" then
            return glyph_node()
        end
        return icon {
            name = art,
            size = opts.art_size or opts.icon_size or theme.icon.md,
            align_h = "Center",
            align_v = "Center",
        }
    end

    local badge_node
    if opts.badge then
        local badge = opts.badge
        if is_signal(badge) then
            ---@cast badge Signal
            badge = badge:map(function(label)
                return { { text = label or "", bold = true } }
            end)
        else
            badge = { { text = badge, bold = true } }
        end
        badge_node = text {
            content = badge,
            foreground = opts.badge_foreground or foreground,
            font = opts.badge_font,
            font_size = opts.badge_size or theme.font.xs,
            align_h = "End",
            align_v = "End",
            translate = { x = -theme.spacing.xs, y = -theme.spacing.xs },
            animate = { foreground = theme.animation_ms },
        }
    end

    local function content(art)
        if not badge_node then
            return face(art)
        end
        return rect { width = side, height = side, children = { face(art), badge_node } }
    end

    ---@type Node[]|Bound
    local children
    if is_signal(opts.art) then
        -- Through `children`, not two `visible` siblings: a hidden subtree stays resolved
        -- (`lua-meta/nodes.lua`).
        children = opts.art:map(function(art)
            return { content(art) }
        end)
    else
        children = { content(opts.art) }
    end

    local node = {
        width = opts.width or side,
        height = side,
        align_h = "Center",
        align_v = "Center",
        hover = hovered,
        on_hover = opts.on_hover,
        radius = radius,
        background = ground,
        opacity = opts.opacity,
        visible = opts.visible,
        -- Cleared below when `opts.border == false`: `x and nil or y` is always `y`.
        border_width = theme.border_width,
        border_color = border_color,
        -- The ground and ring ease under the pointer and on selection; a constant `opacity` never
        -- moves, so easing it costs a button that does not dim nothing.
        animate = {
            background = theme.animation_ms,
            border_color = theme.animation_ms,
            opacity = theme.animation_ms,
        },
        children = children,
    }

    if opts.border == false then
        node.border_width = nil
        node.border_color = nil
    end

    if on_activate == nil and opts.on_button == nil then
        return row(node)
    end

    node.on_click = function(rect, mouse_button)
        if opts.on_button then
            opts.on_button(rect, mouse_button)
            return
        end
        if mouse_button ~= "left" then
            return
        end
        on_activate(rect, mouse_button)
    end
    return button(node)
end
