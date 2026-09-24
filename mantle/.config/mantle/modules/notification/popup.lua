-- The newest cards stacked in one corner, on one scrolling surface rather than one per card.
-- `components/notification_card.lua` draws them; this file owns placement, keyboard mode and the
-- expiry hold.
local theme = require("config.theme")
local notifications = require("lib.notifications")
local ui = require("lib.ui_state")
local notification_card = require("components.notification_card")

-- The Supervisor is silent until a tier is set.
local SOUNDS = "/usr/share/sounds/freedesktop/stereo/"
mantle.notifications:invoke("set_sound", "low", SOUNDS .. "message.oga")
mantle.notifications:invoke("set_sound", "normal", SOUNDS .. "message.oga")
mantle.notifications:invoke("set_sound", "critical", SOUNDS .. "bell.oga")
-- Discord plays its own message sound; ours on top doubles it.
mantle.notifications:invoke("set_app_muted", "vesktop", true)

-- The feed carries twenty, too many for a screen; the rest belong one click away in history. The
-- count is the only bound: a height cap would clip the last card mid-way.
local MAX_CARDS = 4

local HOVER = hover("notification_stack_region")

-- The newest unseen cards. One signal, so `visible` and the list cannot disagree.
local visible_groups = computed(
    { mantle.notifications, ui.popup_seen, ui.panel_open, mantle.lock, mantle.applications },
    function(service, seen, panel_open, lock, applications)
        -- A panel shares this corner, and a popup over the lock screen is readable without a
        -- password. Neither marks the card seen, so it returns unless its countdown expires first.
        if panel_open or (lock and lock.active) then
            return {}
        end
        -- Expiry, history's seen set and DND each drop a card; only expiry leaves it in history.
        local dnd = service and service.dnd
        local unseen = {}
        for _, notification in ipairs((service and service.feed) or {}) do
            local quiet = dnd and notification.urgency ~= "critical"
            if not notification.expired and not quiet
                and not seen[notifications.notification_key(notification)] then
                unseen[#unseen + 1] = notification
            end
        end
        local all = notifications.group_notifications(unseen, applications)
        local shown = {}
        for index = 1, math.min(#all, MAX_CARDS) do
            -- The card staggers entry by rank. `all` is fresh, so this is not the capability's data.
            all[index].rank = index
            shown[index] = all[index]
        end
        return shown
    end
)

return panel {
    id = "notification_area",
    layer = "Overlay",
    anchor = { top = true, right = true },
    margin = { top = theme.bar_height + theme.spacing.md, right = theme.spacing.md },
    width = theme.notification_width,
    visible = visible_groups:map(function(shown)
        return #shown > 0
    end),
    -- Bound, not constant: niri focuses an `on_demand` surface on map, which would steal the
    -- keyboard on every notification. `OnDemand` because a small surface has no outside click to
    -- release `Exclusive`; niri focuses it on the click, so hover arms the binding first, and a
    -- pending draft holds it after the pointer leaves.
    keyboard_interactivity = computed({ HOVER, ui.reply_pending }, function(hovered, pending)
        return (hovered or pending) and "OnDemand" or "None"
    end),
    child = column {
        width = "Fill",
        -- No `height` anywhere: content sizes the surface with no sizing loop.
        -- One region for the stack: per-card regions would order enter/leave against each other and
        -- release a hold just acquired.
        hover = HOVER,
        on_hover = function(hovered)
            mantle.notifications:invoke("hold_expiry", hovered and 300 or 0)
        end,
        children = {
            list {
                width = "Fill",
                spacing = theme.spacing.sm,
                source = visible_groups,
                itemfn = function(group)
                    return notification_card(group, ui)
                end,
                key = function(group)
                    return group.key
                end,
            },
        },
    },
}
