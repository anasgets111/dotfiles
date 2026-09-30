-- The feed's list half: the popup shows the newest few, this shows the whole feed, scrolling. Rows
-- are `components/notification_card.lua`, so actions, replies and expanded bodies work here; this
-- file owns the masthead (who, when, the DND switch), the weather and system rows and the sectioned list.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local notifications = require("lib.notifications")
local ui = require("lib.notification_state")
local store = require("lib.store")
local toggle = require("components.toggle")
local section_header = require("components.section_header")
local panel_header = require("components.panel_header")
local panel_row = require("components.panel_row")
local panel_empty_state = require("components.panel_empty_state")
local panel_action_icon = require("components.panel_action_icon")
local notification_card = require("components.notification_card")
local info_badge = require("components.info_badge")
local identity = require("lib.identity")
local system_info = require("modules.bar.indicators.system_info")
local weather_widget = require("modules.bar.indicators.weather")

local function feed(payload)
    return (payload and payload.feed) or {}
end

local bell_glyph = mantle.notifications:map(function(payload)
    return (payload and payload.dnd) and icons.bell_off or icons.bell
end)

-- `mantle.applications` supplies desktop-file names and icons. `util.today` moves "today" at midnight.
local sections = computed({ mantle.notifications, mantle.applications, util.today },
    function(payload, applications, today)
        local groups = notifications.group_notifications(feed(payload), applications, { history = true })
        return notifications.notification_sections(groups, today)
    end)

-- One feed scan for the masthead's counts, summary, empty state and clear action.
local history_counts = mantle.notifications:map(function(payload)
    if payload == nil then
        return nil
    end
    local count, urgent, apps, seen = 0, 0, 0, {}
    for _, notification in ipairs(feed(payload)) do
        if notifications.kept_in_history(notification) then
            count = count + 1
            urgent = urgent + (notification.urgency == "critical" and 1 or 0)
            local app = notification.app_name or ""
            if not seen[app] then
                seen[app] = true
                apps = apps + 1
            end
        end
    end
    return { count = count, urgent = urgent, apps = apps, dnd = payload.dnd }
end)

local empty = util.shown_when(history_counts, function(counts)
    return counts.count == 0
end)

local function summary(counts)
    local count, apps, dnd = counts.count, counts.apps, counts.dnd
    if count == 0 then
        return dnd and "Do not disturb" or "All caught up"
    end
    return string.format("%d in history", count) .. (apps > 1 and string.format(" · %d apps", apps) or "")
        .. (dnd and " · Do not disturb" or "")
end

-- "1st", "2nd", "3rd", "4th", with the teens all "th". `day` is a day of the month.
local function ordinal(day)
    if day >= 11 and day <= 13 then
        return "th"
    end
    local ones = day % 10
    return ones == 1 and "st" or ones == 2 and "nd" or ones == 3 and "rd" or "th"
end

-- The panel has room to spell out the day and month; the bar's clock is abbreviated to fit a pill.
local function long_date(seconds)
    local day = os.date("*t", seconds).day
    return string.format("%s %d%s of %s", os.date("%A", seconds), day, ordinal(day),
        os.date("%B %Y %I:%M %p", seconds))
end

local body = {
    -- The masthead is the person, not the feed: initials on the plate, the date as the state line.
    panel_header {
        title = identity.full_name,
        icon = identity.initials,
        subtitle = util.label(mantle.system, function(system)
            return long_date(system.time)
        end),
    },
    weather_widget,
    system_info,
    -- The feed's section row, shaped like the two above it but with nothing to unfold: its controls
    -- sit beside its name. The switch is named, since "Notifications · On" would read as the panel.
    panel_row {
        icon = bell_glyph,
        title = "Notifications",
        subtitle = util.label(history_counts, summary),
        trailing = row {
            spacing = theme.spacing.sm,
            align_v = "Center",
            children = {
                -- Critical notifications bypass DND and never expire, so they get their own count.
                info_badge(history_counts:map(function(counts)
                    return string.format("%d urgent", counts and counts.urgent or 0)
                end), theme.RED, {
                    visible = util.shown_when(history_counts, function(counts)
                        return counts.urgent > 0
                    end),
                }),
                panel_action_icon(icons.clear_all, function()
                    for _, notification in ipairs(feed(mantle.notifications:get())) do
                        mantle.notifications:dismiss(notification.id)
                    end
                end, {
                    slot = "notification-clear-all",
                    tint = theme.RED,
                    visible = util.shown_when(history_counts, function(counts)
                        return counts.count > 0
                    end),
                }),
                toggle(mantle.notifications, function(payload)
                    return payload.dnd
                end, function(on)
                    mantle.notifications:set_dnd(on)
                end, "notifications-dnd", "Do not disturb"),
            },
        },
    },
    panel_row {
        icon = icons.screenshare,
        title = "Do not disturb while sharing",
        subtitle = "Popups and sounds pause while an app captures the screen",
        trailing = toggle(store.notifications_dnd_while_sharing, function(on)
            return on ~= false
        end, ui.set_dnd_while_sharing, "notifications-dnd-sharing"),
    },
    list {
        width = "Fill",
        max_height = theme.notification_list_height,
        scroll = scroll("notification_feed"),
        spacing = theme.spacing.sm,
        -- Same hold as the popup: expiry must not reorder the list under a pointer. The regions are
        -- separate because the two surfaces never overlap.
        hover = hover("notification_history_region"),
        on_hover = function(hovered)
            mantle.notifications:hold_expiry(hovered and 300 or 0)
        end,
        source = sections,
        itemfn = function(item)
            if item.kind == "header" then
                return section_header(item.label)
            end
            -- The history scope: lighter ground than the popup's, a timestamp, and no flight in from
            -- an edge this surface does not touch.
            return notification_card(item, ui, { scope = "history" })
        end,
        key = function(item)
            return item.key
        end,
    },
    panel_empty_state(
        "No notifications",
        -- Only once the last card's fade has played: a leaving card keeps its room, so the state
        -- arriving beside it grew the card down before it shrank. `delay` reads non-boolean before its
        -- first change, which counts as settled.
        computed({ empty, delay(empty, theme.animation_ms) }, function(now, was)
            return now == true and was ~= false
        end),
        -- The section row already says whether do not disturb is on.
        { icon = bell_glyph }
    ),
}

return { kind = "notifications", body = body, spacing = theme.spacing.md }
