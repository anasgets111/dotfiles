local theme = require("config.theme")
local util = require("lib.util")

local GROUND = {
    standard = theme.GLASS_CONTENT,
    active = theme.ACCENT_SUBTLE,
    warning = theme.with_opacity(theme.PEACH, theme.opacity.subtle),
    error = theme.with_opacity(theme.RED, theme.opacity.subtle),
    dialog = theme.GLASS,
}

-- Dialogs use shader lighting; `glass = true` enables it without dialog padding or compositor blur.
return function(children, opts)
    local tone = opts.tone or "standard"
    local dialog = tone == "dialog" or nil
    local glass = opts.glass or dialog
    local padding = opts.padding or (dialog and theme.spacing.lg or theme.spacing.md)
    local spacing = opts.spacing or (dialog and theme.spacing.md or theme.spacing.xs)
    local ground = opts.background or util.lift(tone, function(name) return GROUND[name] or GROUND.standard end)
    local card = {
        width = opts.width,
        height = opts.height,
        align_h = opts.align_h,
        align_v = opts.align_v,
        visible = opts.visible,
        opacity = opts.opacity,
        animate = opts.animate,
        -- Nested cards leave the compositor blur to their dialog.
        behind_blur = opts.behind_blur or dialog,
        backdrop_blur = opts.backdrop_blur,
        radius = opts.radius or theme.radius.lg,
        children = children,
    }
    if glass then
        local border = opts.border_color or theme.GLASS_BORDER
        card.children = {
            shader {
                width = "Fill",
                height = "Fill",
                source = mantle.config_dir .. "/shaders/launcher_sheen.frag",
                params = util.lift(type(border) == "userdata" and border or ground, function(color)
                    return {
                        fill = theme.rgba(type(ground) == "userdata" and ground:get() or ground),
                        sheen = theme.rgba(type(border) == "userdata" and color or border),
                        shade = theme.rgba(theme.LAUNCHER_SHADOW),
                        edge_width = opts.border_width or theme.border_width,
                        corner_radius = card.radius,
                    }
                end),
            },
            column {
                width = "Fill",
                height = opts.height and "Fill" or nil,
                padding = padding,
                spacing = spacing,
                children = children,
            },
        }
        return rect(card)
    end
    local animate = { background = theme.animation_ms, border_color = theme.animation_ms }
    for key, value in pairs(opts.animate or {}) do animate[key] = value end
    card.padding, card.spacing, card.background = padding, spacing, ground
    card.border_width = opts.border_width or opts.outlined and theme.border_width or nil
    card.border_color = opts.border_color or opts.outlined and theme.GLASS_BORDER or nil
    card.animate = animate
    return column(card)
end
