-- The feed's list half: the popup shows the newest few, this shows the whole feed, scrolling. Rows
-- are `components/notification_card.lua`, so actions, replies and expanded bodies work here; this
-- file owns the header, DND toggle and sectioned list.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local notifications = require("lib.notifications")
local ui = require("lib.ui_state")
local cell = require("components.cell")
local section_header = require("components.section_header")
local panel_header = require("components.panel_header")
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

-- `mantle.applications` supplies desktop-file names and icons. `mantle.system` moves "today" at midnight.
local sections = computed({ mantle.notifications, mantle.applications, mantle.system },
    function(payload, applications, system)
        local groups = notifications.group_notifications(feed(payload), applications, { skip_transient = true })
        return notifications.notification_sections(groups, (system and system.time) or 0)
    end)

-- Transients never reach this list, so neither count includes them.
local function kept(payload, urgent)
    local count = 0
    for _, notification in ipairs(feed(payload)) do
        if not notification.transient and (not urgent or notification.urgency == "critical") then
            count = count + 1
        end
    end
    return count
end

local function summary(payload)
    local count, apps, seen = kept(payload), 0, {}
    for _, notification in ipairs(feed(payload)) do
        local app = notification.app_name or ""
        if not notification.transient and not seen[app] then
            seen[app] = true
            apps = apps + 1
        end
    end
    local dnd = payload and payload.dnd
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
    row {
        width = "Fill",
        spacing = theme.spacing.md,
        align_v = "Center",
        children = {
            rect {
                width = theme.control.md,
                height = theme.control.md,
                radius = math.floor(theme.control.md / 2),
                background = theme.ACCENT_LIGHT,
                border_width = theme.border_width,
                border_color = theme.with_opacity(theme.ACCENT, 0.45),
                children = {
                    cell(util.bold(identity.initials), theme.ACCENT, theme.font.sm,
                        { width = "Fill", align = "Center", align_v = "Center" }),
                },
            },
            column {
                width = "Fill",
                spacing = theme.spacing.xs,
                children = {
                    cell(util.bold(identity.full_name), theme.FG, theme.font.md, { width = "Fill" }),
                    cell(util.label(mantle.system, function(system)
                        return long_date(system.time)
                    end), theme.DIM, theme.font.xs, { width = "Fill" }),
                },
            },
        },
    },
    weather_widget("notifications"),
    system_info("notifications"),
    panel_header {
        title = "Notifications",
        icon = bell_glyph,
        active = mantle.notifications:map(function(payload)
            return not (payload and payload.dnd)
        end),
        subtitle = util.label(mantle.notifications, summary),
        trailing = {
            -- Critical notifications bypass DND and never expire, so they get their own count.
            info_badge(mantle.notifications:map(function(payload)
                return string.format("%d urgent", kept(payload, true))
            end), theme.RED, {
                visible = util.shown_when(mantle.notifications, function(payload)
                    return kept(payload, true) > 0
                end),
            }),
            panel_action_icon(mantle.notifications:map(function(payload)
                return (payload and payload.dnd) and icons.bell or icons.bell_off
            end), function()
                local payload = mantle.notifications:get()
                mantle.notifications:invoke("set_dnd", not (payload and payload.dnd))
            end, { slot = "notification-dnd", tint = theme.PEACH }),
            panel_action_icon(icons.clear_all, function()
                for _, notification in ipairs(feed(mantle.notifications:get())) do
                    mantle.notifications:invoke("dismiss", notification.id)
                end
            end, {
                slot = "notification-clear-all",
                tint = theme.RED,
                visible = util.shown_when(mantle.notifications, function(payload)
                    return kept(payload) > 0
                end),
            }),
        },
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
            mantle.notifications:invoke("hold_expiry", hovered and 300 or 0)
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
        util.shown_when(mantle.notifications, function(payload)
            return kept(payload) == 0
        end),
        -- The header already says whether do not disturb is on.
        { icon = bell_glyph }
    ),
}

return { kind = "notifications", body = body, spacing = theme.spacing.md }
