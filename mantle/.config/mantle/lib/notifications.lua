-- Notification feed helpers with no nodes or signals: body runs and links, popup identity, grouping
-- and history sections.
local util = require("lib.util")

local notifications = {}

-- Bare web and file addresses in unlinked text become links; `<a href>` targets are kept. Trailing
-- sentence punctuation is stripped.
local URL_PATTERNS = { "%f[%S]https?://[^%s<>'\"]+", "%f[%S]file://[^%s<>'\"]+" }

local function with_text(span, text, href)
    return util.with(util.with(span, "text", text), "href", href or span.href)
end

local function linkified(spans)
    local out = {}
    for _, span in ipairs(spans or {}) do
        local text = span.kind == "text" and (span.href == nil or span.href == "") and span.text or nil
        if not text then
            out[#out + 1] = span
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
                    out[#out + 1] = with_text(span, text:sub(at, first - 1))
                end
                out[#out + 1] = with_text(span, href, href)
                at = last + 1
            end
            if at == 1 then
                out[#out + 1] = span
            elseif at <= #text then
                out[#out + 1] = with_text(span, text:sub(at))
            end
        end
    end
    return out
end

-- Parsed markup spans to `text.content` runs. Links carry `href` for the card's `on_link`; image
-- spans go through `notification_images`, since `text` refuses runs without text.
function notifications.notification_body(spans, link_color)
    local runs = {}
    for _, span in ipairs(linkified(spans)) do
        if span.kind == "text" and span.text and span.text ~= "" then
            local is_link = span.href ~= nil and span.href ~= ""
            runs[#runs + 1] = {
                text = span.text,
                bold = span.bold or false,
                italic = span.italic or false,
                underline = span.underline or is_link,
                color = is_link and link_color or nil,
                href = is_link and span.href or nil,
            }
        end
    end
    return runs
end

-- Run character count for `components/notification_card.lua`'s pre-measurement expander guess.
function notifications.runs_length(runs)
    local total = 0
    for _, run in ipairs(runs or {}) do
        total = total + utf8.len(run.text or "")
    end
    return total
end

-- Distinct body link targets in first-seen order; repeated pages get one button.
function notifications.notification_links(spans)
    local links, seen = {}, {}
    for _, span in ipairs(linkified(spans)) do
        local href = span.kind == "text" and span.href or nil
        if href and href ~= "" and not seen[href] then
            seen[href] = true
            links[#links + 1] = href
        end
    end
    return links
end

-- Inline body pictures (`<img src>`), trusted-root validated by the Supervisor; draw under text, as
-- `notifications.notification_body` does.
function notifications.notification_images(spans)
    local paths = {}
    for _, span in ipairs(spans or {}) do
        if span.kind == "image" and span.image_path then
            paths[#paths + 1] = span.image_path
        end
    end
    return paths
end

-- Link label: web host, `mailto:` address, or the full URL otherwise. Full URLs do not fit a card
-- button.
function notifications.link_label(href)
    local rest = href:match("^[%a][%w+.-]*://(.*)$")
    if rest then
        return (rest:match("^[^/?#]+") or rest):gsub("^www%.", "")
    end
    return href:match("^mailto:(.+)$") or href
end

-- Content identity for popup bookkeeping. Include `timestamp`, not only id: `replaces_id` reuses an
-- id for new content, while timestamp changes on every `Notify` and otherwise stays put.
function notifications.notification_key(notification)
    return string.format("%d:%d", notification.id or 0, notification.timestamp or 0)
end

-- One card per sending app, keyed by `desktop_entry` (stable, and looks up the installed name and
-- icon), else `app_name`. Critical first, then newest; the key breaks equal-second ties.
-- `opts.skip_transient` drops `transient` notifications (history does, popups do not).
function notifications.group_notifications(feed, applications, opts)
    opts = opts or {}
    local groups, by_key = {}, {}
    for _, notification in ipairs(feed or {}) do
        if not (opts.skip_transient and notification.transient) then
            local entry_id = notification.desktop_entry
            local key = entry_id and string.lower(entry_id) or (notification.app_name or "?")
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
        local index = 4
        if group.urgency == "critical" then
            index = 1
        elseif group.latest >= today_start then
            index = 2
        elseif group.latest >= today_start - 86400 then
            index = 3
        end
        local items = buckets[index].items
        items[#items + 1] = group
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

-- History arrival as "Wed 14:32"; `%a` is enough because sections already name the day.
function notifications.absolute_time(timestamp)
    return os.date("%a %H:%M", timestamp or 0)
end

return notifications
