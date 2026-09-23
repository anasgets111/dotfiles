-- A percentage bar: signals resolve before property parsing, so a "45%" `width` makes a live fill.
-- `opts.motion` replaces the ease for a fill retargeted mid-flight, like a volume key on repeat,
-- where an eased tween restarts from a standstill each time; those sites pass `theme.spring_tracking`.
local theme = require("config.theme")

---@param opts? { motion?: Animation }
return function(signal, read, color, width, height, opts)
    return row {
        width = width or theme.s(40, 30),
        height = height or theme.s(6, 4),
        align_v = "Center",
        background = theme.SURFACE,
        radius = theme.s(3, 2),
        children = { rect {
            width = signal:map(function(value)
                if value == nil then
                    return "0%"
                end
                local ok, pct = pcall(read, value)
                if not ok or pct == nil then
                    return "0%"
                end
                -- `math.floor`: `%d` raises on 45.00027, and a raise here freezes the whole bar on its
                -- last good frame, not just this meter.
                return string.format("%d%%", math.floor(math.max(0, math.min(100, pct)) + 0.5))
            end),
            height = "Fill",
            background = color,
            radius = theme.s(3, 2),
            animate = { width = (opts and opts.motion) or theme.animation_ms },
        } },
    }
end
