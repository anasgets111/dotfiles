local theme = require("config.theme")

local tones = {
    standard = { background = theme.GLASS_CONTENT, border = theme.GLASS_BORDER },
    active = { background = theme.ACCENT_SUBTLE, border = theme.ACCENT_MEDIUM },
    warning = {
        background = theme.with_opacity(theme.PEACH, theme.opacity.subtle),
        border = theme.with_opacity(theme.PEACH, theme.opacity.medium),
    },
    error = {
        background = theme.with_opacity(theme.RED, theme.opacity.subtle),
        border = theme.with_opacity(theme.RED, theme.opacity.medium),
    },
}

local function tone_style(tone)
    return tones[tone] or tones.standard
end

return function(children, opts)
    opts = opts or {}
    ---@type string|Signal
    local tone = opts.tone or "standard"
    ---@type Color|Signal
    local background
    ---@type Color|Signal
    local border_color
    if type(tone) == "userdata" then
        ---@cast tone Signal
        background = tone:map(function(name)
            return tone_style(name).background
        end)
        border_color = tone:map(function(name)
            return tone_style(name).border
        end)
    else
        local style = tone_style(tone)
        background = style.background
        border_color = style.border
    end
    local animate = opts.animate
    if animate == nil then
        animate = { background = theme.animation_ms, border_color = theme.animation_ms }
    elseif type(animate) == "table" then
        local with_tone = {}
        for key, value in pairs(animate) do
            with_tone[key] = value
        end
        with_tone.background = with_tone.background or theme.animation_ms
        with_tone.border_color = with_tone.border_color or theme.animation_ms
        animate = with_tone
    end
    return column {
        width = opts.width,
        height = opts.height,
        padding = opts.padding or theme.card_padding,
        margin = opts.margin,
        align_h = opts.align_h,
        align_v = opts.align_v,
        visible = opts.visible,
        opacity = opts.opacity,
        animate = animate,
        spacing = opts.spacing or theme.spacing.xs,
        background = opts.background or background,
        -- Passed through rather than defaulted: a card on an already-blurred sheet asking again
        -- would union into a region that covers it, which is work for no pixels.
        blur = opts.blur,
        radius = opts.radius or theme.radius.lg,
        border_width = opts.border_width,
        border_color = opts.border_color,
        children = children,
    }
end
