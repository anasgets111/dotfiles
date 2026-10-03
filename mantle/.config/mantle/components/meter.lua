-- A percentage bar. Signals resolve before property parsing, so a "45%" `width` makes a live fill.
-- `opts.motion` accepts a spring for repeated input or a signal for changing the fill's timing.
local theme = require("config.theme")
local util = require("lib.util")

---@param opts? { motion?: Animation|Signal<Animation> }
return function(signal, read, color, height, opts)
    height = height or theme.meter_height
    return row {
        width = "fill",
        height = height,
        align_v = "center",
        background = theme.SURFACE,
        radius = height / 2,
        children = { rect {
            width = signal:map(function(value)
                local ok, pct = pcall(read, value)
                pct = value ~= nil and ok and pct or 0
                -- Keep small increments visible on long countdowns.
                return string.format("%.3f%%", math.max(0, math.min(100, pct)))
            end),
            height = "fill",
            background = color,
            radius = height / 2,
            animate = util.lift((opts and opts.motion) or theme.animation_ms, function(motion) return { width = motion } end),
        } },
    }
end
