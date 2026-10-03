-- A card fades and moves from its closed pose. Placement and input stay with its owner.
local util = require("lib.util")
local theme = require("config.theme")

---@param card table
---@param showing Signal<boolean>
---@param opts? { scale?: number|false, y?: number }
---@return table
return function(card, showing, opts)
    opts = opts or {}
    local scale = opts.scale == nil and 0.97 or opts.scale
    local y = opts.y or -theme.spacing.md
    card.scale = scale and util.choose(showing, 1, scale) or nil
    card.translate = y ~= 0 and showing:map(function(open)
        return { y = open and 0 or y }
    end) or nil
    card.opacity = util.choose(showing, 1, 0)
    -- Entry and exit share timing; only their easing differs.
    card.animate = showing:map(function(open)
        local easing = open and "out_cubic" or "in_cubic"
        return {
            opacity = { duration = theme.animation_ms, easing = easing, from = 0 },
            scale = scale and { duration = theme.animation_ms, easing = easing, from = scale } or nil,
            translate = y ~= 0 and { duration = theme.animation_ms, easing = easing, from = { y = y } } or nil,
        }
    end)
    return card
end
