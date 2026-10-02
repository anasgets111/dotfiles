-- Cava's spectrum on one `shader` quad; at rest `lib/cava` holds zeros and it draws a flat row.
local theme = require("config.theme")
local cava = require("lib.cava")

return rect {
    width = theme.center_zone_width,
    height = "Fill",
    padding = theme.spacing.xs,
    children = { shader {
        width = "Fill",
        height = "Fill",
        source = mantle.config_dir .. "/shaders/cava_bars.frag",
        params = computed({ cava.levels, cava.playing }, function(levels, on)
            return {
                levels = levels,
                count = cava.BARS,
                gap = theme.border_width,
                min_height = theme.border_width_medium,
                color = theme.rgba(on and theme.ACCENT_MEDIUM or theme.ACCENT_SUBTLE),
            }
        end),
    } },
}
