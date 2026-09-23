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

local KIND = "notifications"
local SCROLL = scroll("notification_feed")

local function feed(n)
    return (n and n.feed) or {}
end

local bell_glyph = mantle.notifications:map(function(n)
    return (n and n.dnd) and icons.bell_off or icons.bell
end)

-- List non-transients, grouped by application into "urgent" / "today" / "yesterday" /
-- "earlier". `mantle.applications` supplies desktop-file names/icons; `mantle.system`
-- moves "today" at midnight.
local sections = computed({ mantle.notifications, mantle.applications, mantle.system }, function(n, applications, s)
    local groups = notifications.group_notifications(feed(n), applications, { skip_transient = true })
    return notifications.notification_sections(groups, (s and s.time) or 0)
end)

-- Transients never reach this list, so neither count includes them.
local function kept(n, urgent)
    local count = 0
    for _, notification in ipairs(feed(n)) do
        if not notification.transient and (not urgent or notification.urgency == "critical") then
            count = count + 1
        end
    end
    return count
end

-- Count, application count, and DND state.
local function summary(n)
    local count, apps, seen = 0, 0, {}
    for _, notification in ipairs(feed(n)) do
        if not notification.transient then
            count = count + 1
            local app = notification.app_name or ""
            if not seen[app] then
                seen[app] = true
                apps = apps + 1
            end
        end
    end
    local dnd = n and n.dnd
    if count == 0 then
        return dnd and "Silenced · history empty" or "History empty"
    end
    local parts = { string.format("%d in history", count) }
    if apps > 1 then
        parts[#parts + 1] = string.format("%d apps", apps)
    end
    if dnd then
        parts[#parts + 1] = "silenced"
    end
    return table.concat(parts, " · ")
end

-- "1st", "2nd", "3rd", "4th"; the teens are the exception, all "th".
local function ordinal(day)
    local tens = day % 100
    if tens >= 11 and tens <= 13 then
        return "th"
    end
    local ones = day % 10
    return ones == 1 and "st" or ones == 2 and "nd" or ones == 3 and "rd" or "th"
end

-- The panel has room to spell out the day and month; the bar's clock is abbreviated to fit a pill.
local function long_date(seconds)
    local t = os.date("*t", seconds)
    return string.format("%s %d%s of %s", os.date("%A", seconds), t.day, ordinal(t.day),
        os.date("%B %Y %I:%M %p", seconds))
end

local body = {
    -- Session identity and date header.
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
                    cell(util.bold(identity.initials), theme.ACCENT, theme.font.sm, {
                        width = "Fill",
                        align = "Center",
                        align_v = "Center",
                    }),
                },
            },
            column {
                width = "Fill",
                spacing = theme.spacing.xs,
                children = {
                    cell(util.bold(identity.full_name), theme.FG, theme.font.md, { width = "Fill" }),
                    cell(util.label(mantle.system, function(s)
                        return long_date(s.time)
                    end), theme.DIM, theme.font.xs, { width = "Fill" }),
                },
            },
        },
    },
    -- Order: weather, system info, then the notifications masthead.
    weather_widget("notifications"),
    system_info("notifications"),
    panel_header {
        title = "Notifications",
        icon = bell_glyph,
        active = mantle.notifications:map(function(n)
            return not (n and n.dnd)
        end),
        subtitle = util.label(mantle.notifications, summary),
        trailing = {
            -- Critical notifications bypass DND and never expire, so they get their own count.
            info_badge(mantle.notifications:map(function(n)
                return string.format("%d urgent", kept(n, true))
            end), theme.RED, {
                visible = util.shown_when(mantle.notifications, function(n)
                    return kept(n, true) > 0
                end),
            }),
            panel_action_icon(mantle.notifications:map(function(n)
                return (n and n.dnd) and icons.bell or icons.bell_off
            end), function()
                local n = mantle.notifications:get()
                mantle.notifications:invoke("set_dnd", not (n and n.dnd))
            end, {
                slot = "notification-dnd",
                tint = theme.PEACH,
            }),
            panel_action_icon(icons.clear_all, function()
                for _, notification in ipairs(feed(mantle.notifications:get())) do
                    mantle.notifications:invoke("dismiss", notification.id)
                end
            end, {
                slot = "notification-clear-all",
                tint = theme.RED,
                visible = util.shown_when(mantle.notifications, function(n)
                    return kept(n) > 0
                end),
            }),
        },
    },
    column {
        width = "Fill",
        -- Same hold as the popup: expiry must not reorder the list under a pointer. The regions are
        -- separate because the two surfaces never overlap.
        hover = hover("notification_history_region"),
        on_hover = function(hovered)
            mantle.notifications:invoke("hold_expiry", hovered and 300 or 0)
        end,
        children = {
            -- Card height up to the screen cap, then a scrolling viewport.
            list {
                width = "Fill",
                max_height = theme.notification_list_height,
                scroll = SCROLL,
                spacing = theme.spacing.sm,
                source = sections,
                itemfn = function(item)
                    if item.kind == "header" then
                        return section_header(item.label)
                    end
                    -- The history scope: lighter ground than the popup's, a timestamp, and no
                    -- flight in from an edge this surface does not touch.
                    return notification_card(item, ui, { scope = "history" })
                end,
                key = function(item)
                    return item.key
                end,
            },
        },
    },
    panel_empty_state(
        "No notifications",
        util.shown_when(mantle.notifications, function(n)
            return kept(n) == 0
        end),
        {
            icon = bell_glyph,
            -- An empty feed under DND means something different from an empty feed without it, and
            -- the struck-through bell alone does not say which.
            subtext = mantle.notifications:map(function(n)
                return (n and n.dnd) and "Do not disturb is on" or "You're all caught up"
            end),
        }
    ),
}

return { kind = KIND, body = body, spacing = theme.spacing.md }
