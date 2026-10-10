-- The square leading an OSD card: `child` centred on `color` at `light` with a `medium` edge.
local theme = require("config.theme")
local util = require("lib.util")

---@param color Color|Bound
---@param child table
return function(color, child)
    return rect {
        width = theme.osd_tile,
        height = theme.osd_tile,
        align_v = "center",
        background = util.lift(color, function(value)
            return theme.with_opacity(value, theme.opacity.light)
        end),
        border_width = theme.border_width,
        border_color = util.lift(color, function(value)
            return theme.with_opacity(value, theme.opacity.medium)
        end),
        radius = theme.radius.md,
        children = { child },
    }
end
