local theme = require("config.theme")
local util = require("lib.util")
local spinner = require("components.spinner")

return function(glyph, on_activate, opts)
    local side = opts.size or theme.item_height
    local icon_size = opts.icon_size or theme.icon.md
    local idle_visible = opts.spinning and opts.spinning:map(function(on)
        return not on
    end)
    local base = opts.background or theme.GLASS_CONTROL
    -- A custom ground lifts on hover by default, so a coloured state survives the pointer.
    local base_hover = opts.background_hover or util.lift(base, theme.hover)
    local hovered = hover(opts.slot)

    -- `computed` takes only signals, so a plain colour rides on `hovered` and is read directly.
    local base_live, hover_live = type(base) == "userdata", type(base_hover) == "userdata"
    ---@diagnostic disable-next-line: assign-type-mismatch
    local ground = computed({ hovered, base_live and base or hovered, hover_live and base_hover or hovered },
        function(is_hovered, plain, lit)
            if is_hovered then
                return hover_live and lit or base_hover
            end
            return base_live and plain or base
        end)

    local foreground = opts.foreground or util.lift(ground, theme.text_contrast)

    -- Selection wins the ring; otherwise it follows the pointer.
    local border_color = opts.border_color
    if opts.border ~= false and border_color == nil then
        border_color = computed({ opts.selected or hovered, hovered }, function(is_selected, is_hovered)
            if opts.selected and is_selected then
                return theme.ACCENT
            end
            return is_hovered and theme.GLASS_BORDER_HOVER or theme.GLASS_BORDER
        end)
    end

    -- `opts.art` is a themed name or path drawn in place of the glyph. `PaintStyle::Icon` takes no
    -- tint, so artwork and a tintable glyph are two nodes, not one property. An empty name falls back to the glyph, so a workspace draws its
    -- window's icon or its number from one button.
    local function face(art)
        if art == nil or art == "" then
            local idle_glyph = text {
                content = glyph,
                foreground = foreground,
                font_size = icon_size,
                visible = idle_visible,
                animate = { foreground = theme.animation_ms },
                align_h = "center",
                align_v = "center",
            }
            if opts.spinning == nil then
                return idle_glyph
            end
            return rect {
                width = side,
                height = side,
                children = { idle_glyph, spinner(opts.spinning, icon_size, foreground) },
            }
        end
        return icon {
            name = art,
            size = theme.icon.md,
            align_h = "center",
            align_v = "center",
        }
    end

    local badge_node = opts.badge and text {
        content = opts.badge,
        font_weight = theme.band_font_weight,
        foreground = foreground,
        font = theme.condensed_font,
        font_size = theme.band_font_size,
        align_h = "end",
        align_v = "end",
        translate = opts.badge_translate or { x = -theme.spacing.xs, y = -theme.spacing.xs },
        animate = { foreground = theme.animation_ms },
    }

    local node = {
        -- `content` is a caller's node in place of the glyph, sized by what it holds.
        width = opts.content == nil and side or nil,
        height = side,
        align_h = "center",
        align_v = "center",
        geometry = opts.geometry,
        cursor = opts.cursor,
        hover = hovered,
        on_hover = opts.on_hover,
        on_drag = opts.on_drag,
        radius = opts.radius or side / 2,
        background = ground,
        opacity = opts.opacity,
        visible = opts.visible,
        border_width = opts.border ~= false and theme.border_width or nil,
        border_color = opts.border ~= false and border_color or nil,
        -- The ground and ring ease under the pointer and on selection. A constant `opacity` never
        -- moves, so easing it costs a button that never dims nothing.
        animate = {
            background = theme.animation_ms,
            border_color = theme.animation_ms,
            opacity = theme.animation_ms,
        },
        -- Through `children`, not two `visible` siblings: a hidden subtree stays resolved
        -- (`lua-meta/nodes.lua`).
        children = opts.content and { opts.content } or util.lift(opts.art, function(art)
            return { badge_node and rect { width = side, height = side, children = { face(art), badge_node } } or
            face(art) }
        end),
    }

    if on_activate or opts.on_buttons then
        node.on_click = function(rect, mouse_button)
            if opts.on_buttons then
                local handler = opts.on_buttons[mouse_button]
                if handler then handler(rect) end
                return
            end
            if mouse_button == "left" and not (opts.spinning and opts.spinning:get()) then
                on_activate(rect, mouse_button)
            end
        end
    end

    return row(node)
end
