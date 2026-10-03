-- Measured details unfold below a stable heading. Placement stays with the caller.
local theme = require("config.theme")
local util = require("lib.util")

---@param heading Node
---@param details Node
---@param expanded Signal<boolean>
---@param opts { slot: string, spacing?: integer, visible?: boolean|Bound, moving?: Signal<boolean> }
return function(heading, details, expanded, opts)
    local bounds = geometry(opts.slot .. "-details")
    details.geometry = bounds
    -- Lists pass persistent motion: a delay recreated during collapse would forget the open state.
    details.visible = opts.moving and computed({ expanded, opts.moving }, function(open, moving)
        return open or moving
    end) or util.linger(expanded, theme.animation_ms)
    return column {
        width = "fill",
        spacing = util.choose(expanded, opts.spacing or theme.spacing.xs, 0),
        visible = opts.visible,
        animate = { spacing = theme.animation_ms },
        children = { heading, rect {
            width = "fill",
            height = computed({ expanded, bounds }, function(open, measured) return open and measured.height or 0 end),
            clip = "box",
            animate = { height = { duration = theme.animation_ms, easing = "out_cubic" } },
            children = { details },
        } },
    }
end
