-- One modal card and its motion, for `modules/global/modal_host.lua` to stack under one scrim. By
-- default it fades, scales from 0.97 and rises by `spacing.md`, OutCubic in and InCubic out.
local theme = require("config.theme")
local ui_state = require("lib.ui_state")

---@class ModalMotion
---@field enter_ms integer
---@field exit_ms integer
---@field enter_easing Easing
---@field exit_easing Easing
---@field scale number Closed scale.
---@field y number Closed offset.
---@field origin? Axes Scale pivot on the card, its centre by default.

---@type ModalMotion
local DEFAULT_MOTION = {
    enter_ms = theme.animation_ms,
    exit_ms = theme.animation_ms,
    enter_easing = "OutCubic",
    exit_easing = "InCubic",
    scale = 0.97,
    y = -theme.spacing.md,
}

---@class ModalOpts
---@field kind string The `modal` state value that shows this one, e.g. `"launcher"`.
---@field card table The card node, placed by its own aligns in the screen below the bar.
---@field showing? Signal<boolean> What shows it, for a card on its own surface; `modal_showing(kind)` by default.
---@field motion? ModalMotion

---@class Modal
---@field kind string
---@field node table The screen-sized wrapper carrying the card and its motion.
---@field exit_ms integer How long `modal_host` keeps the card after it closes.

-- `modal_host`'s outside catcher is every card's ancestor, so a press on the card's own ground, such as
-- padding, a gap between rows or an empty list, walks up to it and closes the modal. A handled button
-- the size of the card ends that walk. It takes the card's placement rather than sitting under it,
-- because a content-sized one reaches back to the origin and eats the scrim's clicks.
local function swallow_presses(card)
    local box = button {
        on_click = function() end,
        cursor = "default",
        width = card.width,
        height = card.height,
        margin = card.margin,
        align_h = card.align_h,
        align_v = card.align_v,
        clip = card.clip,
        children = { card },
    }
    card.margin, card.align_h, card.align_v = nil, nil, nil
    return box
end

---@param opts ModalOpts
---@return Modal
return function(opts)
    local showing = opts.showing or ui_state.modal_showing(opts.kind)
    local motion = opts.motion or DEFAULT_MOTION
    local card = swallow_presses(opts.card)
    card.origin = motion.origin
    card.scale = showing:map(function(open)
        return open and 1 or motion.scale
    end)
    card.translate = showing:map(function(open)
        return { y = open and 0 or motion.y }
    end)
    card.opacity = showing:map(function(open)
        return open and 1 or 0
    end)
    -- The easing follows the direction, so the table is a signal; `from` is the entry.
    card.animate = showing:map(function(open)
        local duration = open and motion.enter_ms or motion.exit_ms
        local easing = open and motion.enter_easing or motion.exit_easing
        return {
            opacity = { duration = duration, easing = easing, from = 0 },
            scale = { duration = duration, easing = easing, from = motion.scale },
            translate = { duration = duration, easing = easing, from = { y = motion.y } },
        }
    end)
    return {
        kind = opts.kind,
        -- Screen-sized, so the card keeps its own placement. Stacking, not a column, which would
        -- control child placement and hang every card from the top.
        node = rect {
            -- Keyed, since siblings otherwise match by position: opening a modal listed earlier
            -- would hand a closing card's slot to it and replay the entry.
            id = opts.kind,
            width = "Fill",
            height = "Fill",
            -- Every card centres in the space the bar leaves, so modals share one resting place.
            padding = { top = theme.bar_height },
            children = { card },
        },
        exit_ms = motion.exit_ms,
    }
end
