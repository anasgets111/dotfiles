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
    local base_hover = opts.background_hover or theme.GLASS_CONTROL_HOVER
    local hovered = opts.slot and hover(opts.slot) or nil

    ---@type Color|Signal
    local ground = base
    if hovered then
        -- `computed` takes only signals, so a plain colour rides on `hovered` and is read directly.
        local base_live, hover_live = type(base) == "userdata", type(base_hover) == "userdata"
        ---@diagnostic disable-next-line: assign-type-mismatch
        ground = computed({ hovered, base_live and base or hovered, hover_live and base_hover or hovered },
            function(is_hovered, plain, lit)
                if is_hovered then
                    return hover_live and lit or base_hover
                end
                return base_live and plain or base
            end)
    end

    local foreground = opts.foreground or util.lift(ground, theme.text_contrast)

    local border_color = opts.selected and opts.selected:map(function(is_selected)
        return is_selected and theme.ACCENT or theme.GLASS_BORDER
    end) or hovered and hovered:map(function(is_hovered)
        return is_hovered and theme.GLASS_BORDER_HOVER or theme.GLASS_BORDER
    end) or theme.GLASS_BORDER

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
                align_h = "Center",
                align_v = "Center",
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
            align_h = "Center",
            align_v = "Center",
        }
    end

    local badge_node = opts.badge and text {
        content = util.bold(opts.badge),
        foreground = foreground,
        font = opts.badge_font,
        font_size = theme.font.xs,
        align_h = "End",
        align_v = "End",
        translate = { x = -theme.spacing.xs, y = -theme.spacing.xs },
        animate = { foreground = theme.animation_ms },
    }

    local node = {
        width = opts.width or side,
        height = side,
        align_h = "Center",
        align_v = "Center",
        hover = hovered,
        on_hover = opts.on_hover,
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
        children = util.lift(opts.art, function(art)
            return { badge_node and rect { width = side, height = side, children = { face(art), badge_node } } or
            face(art) }
        end),
    }

    if on_activate == nil and opts.on_button == nil then
        return row(node)
    end
    node.on_click = opts.on_button or function(rect, mouse_button)
        if mouse_button == "left" and not (opts.spinning and opts.spinning:get()) then
            on_activate(rect, mouse_button)
        end
    end
    return button(node)
end
