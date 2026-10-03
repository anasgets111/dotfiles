-- Cava's spectrum on one `shader` quad: glowing waves or bars, as the media panel chose. At rest
-- `lib/cava` holds zeros and both draw a flat line.
local theme = require("config.theme")
local cava = require("lib.cava")
local store = require("lib.store")

local SPECTRUM = {}
for index, color in ipairs(theme.SPECTRUM) do
    for channel, value in ipairs(theme.rgba(color)) do
        SPECTRUM[(index - 1) * 4 + channel] = value
    end
end

return rect {
    width = theme.center_zone_width,
    height = "fill",
    padding = theme.spacing.xs,
    children = { shader {
        width = "fill",
        height = "fill",
        source = store.media_visualizer:map(function(kind)
            return mantle.config_dir .. (kind == "bars" and "/shaders/cava_bars.frag" or "/shaders/cava_wave.frag")
        end),
        params = computed({ cava.levels, cava.playing }, function(levels, on)
            return {
                levels = levels,
                -- Bars.
                count = cava.BARS,
                gap = theme.border_width,
                min_height = theme.border_width_medium,
                color = theme.rgba(on and theme.ACCENT_MEDIUM or theme.ACCENT_SUBTLE),
                -- Waves.
                phase = levels.frame or 0,
                -- A backdrop to the title, never brighter than it.
                strength = on and theme.opacity.medium or theme.opacity.subtle,
                stops = SPECTRUM,
            }
        end),
    } },
}
