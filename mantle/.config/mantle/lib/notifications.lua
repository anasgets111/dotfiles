-- Notification feed helpers with no nodes or signals: body runs and links, popup identity, grouping
-- and history sections.
local util = require("lib.util")

local notifications = {}

-- Bare web and file addresses in unlinked text become links; `<a href>` targets are kept. Trailing
-- sentence punctuation is stripped.
local URL_PATTERNS = { "%f[%S]https?://[^%s<>'\"]+", "%f[%S]file://[^%s<>'\"]+" }

-- Text runs, their character count, link presence and inline picture paths, in one pass.
-- Split bare URLs directly into runs; already-linked spans keep the sender's target.
function notifications.notification_body(spans, link_color)
    local runs, length, has_links, images = {}, 0, false, {}
    local function append(span, text, href)
        local is_link = href ~= nil and href ~= ""
        if is_link and href then
            has_links = true
        end
        if text and text ~= "" then
            length = length + utf8.len(text)
            runs[#runs + 1] = {
                text = text,
                bold = span.bold or false,
                italic = span.italic or false,
                underline = span.underline or is_link,
                color = is_link and link_color or nil,
                href = is_link and href or nil,
            }
        end
    end
    for _, span in ipairs(spans or {}) do
        local text = span.kind == "text" and (span.href == nil or span.href == "") and span.text or nil
        if not text then
            if span.kind == "text" then
                append(span, span.text, span.href)
            elseif span.kind == "image" and span.image_path then
                images[#images + 1] = span.image_path
            end
        else
            local at = 1
            while at <= #text do
                local first, last
                for _, pattern in ipairs(URL_PATTERNS) do
                    local from, to = text:find(pattern, at)
                    if from and (not first or from < first) then
                        first, last = from, to
                    end
                end
                if not first then
                    break
                end
                local href = text:sub(first, last):gsub("[.,;:!?]+$", "")
                last = first + #href - 1
                if first > at then
                    append(span, text:sub(at, first - 1), span.href)
                end
                append(span, href, href)
                at = last + 1
            end
            if at == 1 or at <= #text then
                append(span, text:sub(at), span.href)
            end
        end
    end
    return runs, length, has_links, images
end

-- Content identity for popup bookkeeping. Include `timestamp`, not only id: `replaces_id` reuses an
-- id for new content, while timestamp changes on every `Notify` and otherwise stays put.
function notifications.notification_key(notification)
    return string.format("%d:%d", notification.id or 0, notification.timestamp or 0)
end

-- Whether history keeps a notification once its popup is over. `transient` asks to be popup-only,
-- and low urgency is chatter ("now playing", "download started") nobody returns to.
function notifications.kept_in_history(notification)
    return not notification.transient and notification.urgency ~= "low"
end

-- Whether history should still hold it at `now`: critical until acted on, the rest for a day.
local HISTORY_SECONDS = 86400
function notifications.stale(notification, now)
    return notification.urgency ~= "critical" and (notification.timestamp or 0) < now - HISTORY_SECONDS
end

-- A held popup's age: nothing under a minute, then minutes, hours or days.
function notifications.age(now, timestamp)
    local seconds = now - (timestamp or now)
    if seconds < 60 then
        return ""
    elseif seconds < 3600 then
        return string.format("%d min", seconds // 60)
    elseif seconds < 86400 then
        return string.format("%d h", seconds // 3600)
    end
    return string.format("%d d", seconds // 86400)
end

-- The card a notification joins: `desktop_entry` (stable, and looks up the installed name and icon),
-- else `app_name`.
function notifications.group_key(notification)
    local entry_id = notification.desktop_entry
    return entry_id and string.lower(entry_id) or (notification.app_name or "?")
end

-- One card per sending app. Critical first, then newest; the key breaks equal-second ties.
-- `opts.history` keeps only what `kept_in_history` allows; popups take everything.
function notifications.group_notifications(feed, applications, opts)
    local groups, by_key = {}, {}
    for _, notification in ipairs(feed or {}) do
        if not (opts and opts.history) or notifications.kept_in_history(notification) then
            local entry_id = notification.desktop_entry
            local key = notifications.group_key(notification)
            local group = by_key[key]
            if group == nil then
                local entry = util.app_entry(applications, entry_id)
                group = {
                    key = key,
                    app_name = (entry and entry.name) or notification.app_name or "?",
                    app_icon = (entry and entry.icon) or notification.app_icon,
                    urgency = notification.urgency or "normal",
                    latest = notification.timestamp or 0,
                    items = {},
                }
                by_key[key] = group
                groups[#groups + 1] = group
            end
            group.items[#group.items + 1] = notification
        end
    end
    table.sort(groups, function(left, right)
        local left_critical, right_critical = left.urgency == "critical", right.urgency == "critical"
        if left_critical ~= right_critical then
            return left_critical
        end
        if left.latest ~= right.latest then
            return left.latest > right.latest
        end
        return left.key < right.key
    end)
    return groups
end

-- History sections flattened for `list`, with `kind = "header"` rows. Colon keys cannot collide with
-- desktop ids.
function notifications.notification_sections(groups, now)
    local today = os.date("*t", now)
    local today_start = os.time({ year = today.year, month = today.month, day = today.day, hour = 0 })
    local buckets = {
        { label = "urgent",    items = {} },
        { label = "today",     items = {} },
        { label = "yesterday", items = {} },
        { label = "earlier",   items = {} },
    }
    for _, group in ipairs(groups or {}) do
        local index = group.urgency == "critical" and 1 or group.latest >= today_start and 2
            or group.latest >= today_start - 86400 and 3 or 4
        table.insert(buckets[index].items, group)
    end
    local sections = {}
    for _, bucket in ipairs(buckets) do
        if #bucket.items > 0 then
            sections[#sections + 1] = { kind = "header", key = "header:" .. bucket.label, label = bucket.label }
            for _, group in ipairs(bucket.items) do
                sections[#sections + 1] = group
            end
        end
    end
    return sections
end

-- History arrival as "Wed 02:32 PM"; `%a` is enough because sections already name the day.
function notifications.absolute_time(timestamp)
    return os.date("%a %I:%M %p", timestamp or 0)
end

return notifications
