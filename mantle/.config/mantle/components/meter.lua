-- A percentage bar. Signals resolve before property parsing, so a "45%" `width` makes a live fill.
-- `opts.motion` accepts a spring for repeated input or a signal for changing the fill's timing.
-- `opts.indeterminate` swaps the fill for a short segment sweeping the track, for work with no total yet.
local theme = require("config.theme")
local util = require("lib.util")

local SWEEP = { width = { duration = 900, easing = "in_out_cubic", keyframes = { "0%", "70%", "0%" }, loops = "infinite" } }

---@param opts? { motion?: Animation|Signal<Animation>, indeterminate?: Signal<boolean> }
return function(signal, read, color, height, opts)
    height = height or theme.meter_height
    local indeterminate = opts and opts.indeterminate
    local width = signal:map(function(value)
        local ok, pct = pcall(read, value)
        pct = value ~= nil and ok and pct or 0
        -- Keep small increments visible on long countdowns.
        return string.format("%.3f%%", math.max(0, math.min(100, pct)))
    end)
    local children = {}
    if indeterminate then
        width = computed({ indeterminate, width }, function(on, fill) return on and "30%" or fill end)
        -- The gap before the segment; `animate` follows `indeterminate`, as in `spinner`.
        children[1] = rect {
            width = "0%",
            visible = indeterminate,
            animate = indeterminate:map(function(on) return on and SWEEP or {} end),
        }
    end
    children[#children + 1] = rect {
        width = width,
        height = "fill",
        background = color,
        radius = height / 2,
        animate = util.lift((opts and opts.motion) or theme.animation_ms, function(motion) return { width = motion } end),
    }
    return row {
        width = "fill",
        height = height,
        align_v = "center",
        background = theme.SURFACE,
        radius = height / 2,
        children = children,
    }
end
