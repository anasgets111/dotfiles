-- The newest cards stacked in one corner, on one surface rather than one per card.
-- `components/notification_card.lua` draws them; this file owns placement, keyboard mode and the
-- expiry hold.
local theme = require("config.theme")
local notifications = require("lib.notifications")
local notification_state = require("lib.notification_state")
local navigation = require("lib.ui_state")
local util = require("lib.util")
local notification_card = require("components.notification_card")

-- The Supervisor is silent until a tier is set.
local SOUNDS = "/usr/share/sounds/freedesktop/stereo/"
mantle.notifications:set_sound("low", SOUNDS .. "message.oga")
mantle.notifications:set_sound("normal", SOUNDS .. "message.oga")
mantle.notifications:set_sound("critical", SOUNDS .. "bell.oga")
-- Discord plays its own message sound; ours on top doubles it.
mantle.notifications:set_app_muted("vesktop", true)

-- The feed carries twenty, too many for a screen; the rest belong one click away in history. The
-- count is the only bound: a height cap would clip the last card mid-way.
local MAX_CARDS = 4

-- The engine never expires a critical card. After this long unread it retires to history's urgent
-- section, red ring and count intact, instead of holding the corner.
local CRITICAL_POPUP_SECONDS = 60

local HOVER = hover("notification_stack_region")

-- The newest unseen cards. One signal, so `visible` and the list cannot disagree.
local visible_groups = computed(
    { mantle.notifications, notification_state.popup_seen, navigation.panel_open, mantle.lock, mantle.applications,
        notification_state.sharing },
    function(service, seen, panel_open, lock, applications, is_sharing)
        -- A panel shares this corner, and a popup over the lock screen is readable without a
        -- password. Neither marks the card seen, so it returns unless its countdown expires first.
        if panel_open or (lock and lock.active) then
            return {}
        end
        -- Expiry, history's seen set and DND each drop a card; only expiry leaves it in history.
        -- A screen capture is DND for its length.
        local dnd = (service and service.dnd) or is_sharing
        local unseen = {}
        for _, notification in ipairs((service and service.feed) or {}) do
            local quiet = dnd and notification.urgency ~= "critical"
            if not notification.expired and not quiet
                and not seen[notifications.notification_key(notification)] then
                unseen[#unseen + 1] = notification
            end
        end
        local all = notifications.group_notifications(unseen, applications)
        for index = 1, math.min(#all, MAX_CARDS) do
            -- Entry delay follows rank; `all` is fresh, not capability data.
            all[index].rank = index
        end
        return all
    end
)

-- Once a second. A hovered stack is being read, so it waits like the expiry hold does.
mantle.system:on_change(function(system)
    if HOVER:get() then
        return
    end
    local seen = notification_state.popup_seen:get()
    for _, notification in ipairs((mantle.notifications:get() or {}).feed or {}) do
        if notification.urgency == "critical" and not seen[notifications.notification_key(notification)]
            and system.time - notification.timestamp >= CRITICAL_POPUP_SECONDS then
            notification_state.hide_popup(notification)
        end
    end
end)

return panel {
    id = "notification_area",
    -- One instance, on the output the compositor picks at each show.
    monitor = "Active",
    layer = "Overlay",
    anchor = { top = true, bottom = true, right = true },
    margin = { top = theme.bar_height + theme.spacing.md, right = theme.spacing.md, bottom = theme.spacing.md },
    width = theme.notification_width,
    -- As with the bar panels, keep the surface stable: Hyprland stretches buffers during layer resizes.
    height = "Fill",
    -- Held past the last card, since hiding the surface would skip its exit.
    visible = util.linger(visible_groups:map(function(shown)
        return #shown > 0
    end), theme.notification_slide_ms),
    -- Bound, not constant: niri focuses an `on_demand` surface on map, which would steal the
    -- keyboard on every notification. `OnDemand` because a small surface has no outside click to
    -- release `Exclusive`; niri focuses it on the click, so hover arms the binding first, and a
    -- pending draft holds it after the pointer leaves.
    keyboard_interactivity = computed({ HOVER, notification_state.reply_pending }, function(hovered, pending)
        return (hovered or pending) and "OnDemand" or "None"
    end),
    child = column {
        width = "Fill",
        -- The stack sizes to content inside the fixed surface; empty space takes no input.
        -- One region for the stack: per-card regions would order enter/leave against each other and
        -- release a hold just acquired.
        hover = HOVER,
        on_hover = function(hovered)
            mantle.notifications:hold_expiry(hovered and 300 or 0)
        end,
        children = {
            list {
                width = "Fill",
                spacing = theme.spacing.sm,
                source = visible_groups,
                limit = MAX_CARDS,
                itemfn = function(group)
                    return notification_card(group, notification_state)
                end,
                key = function(group)
                    return group.key
                end,
            },
        },
    },
}
