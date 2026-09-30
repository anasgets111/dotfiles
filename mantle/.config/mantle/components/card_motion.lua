-- A card fades and moves from its closed pose. Placement and input stay with its owner.
local util = require("lib.util")
local theme = require("config.theme")

---@class ModalMotion
---@field enter_ms? integer
---@field exit_ms? integer
---@field enter_easing? Easing
---@field exit_easing? Easing
---@field scale? number|false Closed scale; false omits scaling.
---@field y? number Closed offset.
---@field origin? Axes Scale pivot on the card, its centre by default.

---@param card table
---@param showing Signal<boolean>
---@param opts? ModalMotion
---@return table, integer
return function(card, showing, opts)
    opts = opts or {}
    local enter_ms, exit_ms = opts.enter_ms or theme.animation_ms, opts.exit_ms or theme.animation_ms
    local scale = opts.scale == nil and 0.97 or opts.scale
    local y = opts.y or -theme.spacing.md
    card.origin = opts.origin
    card.scale = scale and util.choose(showing, 1, scale) or nil
    card.translate = showing:map(function(open)
        return { y = open and 0 or y }
    end)
    card.opacity = util.choose(showing, 1, 0)
    -- A signal switches duration and easing between entry and exit as showing changes.
    card.animate = showing:map(function(open)
        local duration = open and enter_ms or exit_ms
        local easing = open and (opts.enter_easing or "OutCubic") or (opts.exit_easing or "InCubic")
        return {
            opacity = { duration = duration, easing = easing, from = 0 },
            scale = scale and { duration = duration, easing = easing, from = scale } or nil,
            translate = { duration = duration, easing = easing, from = { y = y } },
        }
    end)
    return card, exit_ms
end
