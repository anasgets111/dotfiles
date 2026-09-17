-- Hover tooltip: a `popup` following one hover slot. Two bindings are enough: `visible`
-- takes the hover boolean and `anchor_rect` takes the engine-written rect.
--
-- `grab = false` is required. A grabbing popup takes the pointer off its source node and flickers;
-- hover also has no click to carry the required armed input serial.
--
-- The 4px offset opens below the anchor, keeping a pointer resting on the pill out of the tooltip
-- so their hover states do not fight. Moving down closes it when leaving the bar turns hover off.
-- A hover-open panel needs its own hover region, OR-ed with the bar's, so the pointer can enter it.
--
-- No bar tooltip opens while a panel is up; `in_panel` marks one inside the card. The panel card
-- hangs under every slot, so gate on any panel: its position collides, not its subject.
--
-- ## Sizing
-- The window is whatever its words need. Omitting `width`/`height` leaves the `popup` axis at
-- `Content`, measured from the resolved tree when it opens
-- (`layout::node::toplevel::parse_popup_extent`).
--
-- No floor: no tooltip here would approach one, so adding an unreachable number would only add
-- maintenance.
local theme = require("config.theme")
local panel_card = require("components.panel_card")
local ui_state = require("lib.ui_state")

return function(opts)
    return popup {
        id = opts.id,
        parent = "bar",
        anchor_rect = hover_rect(opts.slot),
        visible = computed({ hover(opts.slot), ui_state.panel_open }, function(is_hovered, panel_open)
            return is_hovered and (opts.in_panel or not panel_open)
        end),
        -- The surface is the card's own box. `date_time.lua` is the one caller that still declares
        -- width and height because its rows fill the card rather than sizing it.
        width = opts.width,
        height = opts.height,
        -- `grab` defaults to `true`, but hover cannot produce the required input serial.
        -- Without this, `visible = true` resolves and is refused on every re-resolve.
        grab = false,
        -- Centre under the indicator: `edges` and `gravity` are both `Bottom`.
        -- `BottomLeft`/`BottomRight` hangs it from the slot's left edge and lets it run rightwards,
        -- putting a 250px tip on a 24px icon almost entirely to one side of what it describes, and
        -- pushing the rightmost indicators' tips off the screen for `SlideX` to drag back.
        -- Content-sized tips must stay centred as their text changes, or they grow in one direction
        -- and walk away from the anchor.
        anchor = "Bottom",
        gravity = "Bottom",
        constraint_adjustment = { "FlipY", "SlideX" },
        offset = { x = 0, y = theme.panel_gap },
        child = panel_card(opts.children, {
            background = theme.GLASS,
            blur = true,
            border_width = theme.border_width,
            border_color = theme.BORDER,
            -- `padding_v` is per-tip: `xs` suits a label's inset and `md` suits a month grid's
            -- card. The surface follows the requested value.
            padding = {
                top = opts.padding_v or theme.spacing.xs,
                right = theme.spacing.sm,
                bottom = opts.padding_v or theme.spacing.xs,
                left = theme.spacing.sm,
            },
        }),
    }
end
