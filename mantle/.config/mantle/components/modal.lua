-- One modal card and its motion, for `modules/global/modal_host.lua` to stack under one scrim.
-- Fades, scales from 0.97 and drops in by `spacing.md`, OutCubic in and InCubic out.
local theme = require("config.theme")
local ui_state = require("lib.ui_state")
local card_motion = require("components.card_motion")

---@class ModalOpts
---@field kind string The `modal` state value that shows this one, e.g. `"launcher"`.
---@field card table The card node, placed by its own aligns in the screen below the bar.
---@field showing? Signal<boolean> What shows it, for a card on its own surface; `modal_showing(kind)` by default.
---@field reset_on_close? ScrollSignal[] Scrolls `modal_host` returns to the top once it closes.

---@class Modal
---@field kind string
---@field node table The screen-sized wrapper carrying the card and its motion.
---@field reset_on_close ScrollSignal[]

-- `modal_host`'s outside catcher is every card's ancestor, so a press on the card's own ground, such as
-- padding, a gap between rows or an empty list, walks up to it and closes the modal. A handled button
-- the size of the card ends that walk. It takes the card's placement rather than sitting under it,
-- because a content-sized one reaches back to the origin and eats the scrim's clicks.
local function swallow_presses(card)
    local box = rect {
        on_click = function() end,
        cursor = "default",
        width = card.width,
        height = card.height,
        margin = card.margin,
        align_h = card.align_h or "center",
        align_v = card.align_v or "center",
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
    local card = card_motion(swallow_presses(opts.card), showing)
    return {
        kind = opts.kind,
        -- Screen-sized, so the card keeps its own placement. Stacking, not a column, which would
        -- control child placement and hang every card from the top.
        node = rect {
            -- Keyed, since siblings otherwise match by position: opening a modal listed earlier
            -- would hand a closing card's slot to it and replay the entry.
            id = opts.kind,
            width = "fill",
            height = "fill",
            -- Every card centres in the space the bar leaves, so modals share one resting place.
            padding = { top = theme.bar_height },
            children = { card },
        },
        reset_on_close = opts.reset_on_close or {},
    }
end
