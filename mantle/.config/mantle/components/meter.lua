-- A percentage bar. Signals resolve before property parsing, so a "45%" `width` makes a live fill.
-- `opts.motion` replaces the ease for a fill retargeted mid-flight, like a volume key on repeat, where
-- an eased tween restarts from a standstill each time. Those sites pass `theme.spring_tracking`.
local theme = require("config.theme")

---@param opts? { motion?: Animation }
return function(signal, read, color, height, opts)
    return row {
        width = "Fill",
        height = height or theme.meter_height,
        align_v = "Center",
        background = theme.SURFACE,
        radius = theme.meter_height / 2,
        children = { rect {
            width = signal:map(function(value)
                local ok, pct = pcall(read, value)
                pct = value ~= nil and ok and pct or 0
                -- `math.floor`, because `%d` raises on 45.00027, and a raise here freezes the whole bar
                -- on its last good frame, not just this meter.
                return string.format("%d%%", math.floor(math.max(0, math.min(100, pct)) + 0.5))
            end),
            height = "Fill",
            background = color,
            radius = theme.meter_height / 2,
            animate = { width = (opts and opts.motion) or theme.animation_ms },
        } },
    }
end
