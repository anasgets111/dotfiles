local theme = require("config.theme")
local util = require("lib.util")

local GROUND = {
    standard = theme.GLASS_CONTENT,
    active = theme.ACCENT_SUBTLE,
    warning = theme.with_opacity(theme.PEACH, theme.opacity.subtle),
    error = theme.with_opacity(theme.RED, theme.opacity.subtle),
    -- A modal's own card, blurred and ringed too. The scrim under it already dims the rest.
    dialog = theme.GLASS,
}

return function(children, opts)
    local tone = opts.tone or "standard"
    local dialog = tone == "dialog" or nil
    -- The ground and ring ease unless the caller times them itself.
    local animate = { background = theme.animation_ms, border_color = theme.animation_ms }
    for key, value in pairs(opts.animate or {}) do
        animate[key] = value
    end
    return column {
        width = opts.width,
        height = opts.height,
        padding = opts.padding or theme.spacing.md,
        align_h = opts.align_h,
        align_v = opts.align_v,
        visible = opts.visible,
        opacity = opts.opacity,
        animate = animate,
        spacing = opts.spacing or theme.spacing.xs,
        background = opts.background or util.lift(tone, function(name)
            return GROUND[name] or GROUND.standard
        end),
        -- Only a dialog's. A card on an already-blurred sheet would union into a covering region.
        blur = opts.blur or dialog,
        backdrop_blur = opts.backdrop_blur,
        radius = opts.radius or theme.radius.lg,
        -- `outlined` rings a card that sits on another card, where ground alone would not separate it.
        border_width = opts.border_width or (dialog or opts.outlined) and theme.border_width or nil,
        border_color = opts.border_color or dialog and theme.BORDER or opts.outlined and theme.GLASS_BORDER or nil,
        children = children,
    }
end
