-- One modal card and its motion, for `modules/global/modal_host.lua` to stack under one scrim: it
-- fades, scales from 0.97 and rises by `spacing.md`, OutCubic in and InCubic out.
local theme = require("config.theme")
local ui_state = require("lib.ui_state")

local CLOSED_SCALE = 0.97

---@class ModalOpts
---@field kind string The `modal` state value that shows this one, e.g. `"launcher"`.
---@field card table The card node, positioned by its own `margin` or aligns within the screen.

---@class Modal
---@field kind string
---@field node table The screen-sized wrapper carrying the card and its motion.

-- `modal_host`'s outside catcher is every card's ancestor, so a press on the card's own ground --
-- padding, a gap between rows, an empty list -- used to walk up to it and close the modal. A handled
-- button the size of the card ends that walk. It takes the card's placement rather than sitting
-- under it, since content-sized it would reach back to the origin and eat the scrim's clicks.
local function swallow_presses(card)
    local box = button {
        on_click = function() end,
        cursor = "default",
        width = card.width,
        height = card.height,
        margin = card.margin,
        align_h = card.align_h,
        align_v = card.align_v,
        children = { card },
    }
    card.margin, card.align_h, card.align_v = nil, nil, nil
    return box
end

---@param opts ModalOpts
---@return Modal
return function(opts)
    local showing = ui_state.modal_showing(opts.kind)
    -- The easing follows the direction, so the table is a signal; `from` is the entry.
    local animate = showing:map(function(open)
        local easing = open and "OutCubic" or "InCubic"
        return {
            opacity = { duration = theme.animation_ms, easing = easing, from = 0 },
            scale = { duration = theme.animation_ms, easing = easing, from = CLOSED_SCALE },
            translate = { duration = theme.animation_ms, easing = easing, from = { y = -theme.spacing.md } },
        }
    end)
    return {
        kind = opts.kind,
        -- Screen-sized, so the card keeps its own placement and scale pivots on the screen's centre.
        -- Stacking, not a column, which would control child placement and hang every card from the top.
        node = rect {
            width = "Fill",
            height = "Fill",
            scale = showing:map(function(open)
                return open and 1 or CLOSED_SCALE
            end),
            translate = showing:map(function(open)
                return { y = open and 0 or -theme.spacing.md }
            end),
            opacity = showing:map(function(open)
                return open and 1 or 0
            end),
            animate = animate,
            children = { swallow_presses(opts.card) },
        },
    }
end
