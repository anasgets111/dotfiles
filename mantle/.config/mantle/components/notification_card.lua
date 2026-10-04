-- One application's notifications as one card, shared by the popup stack and the history panel.
-- `opts.scope` carries their different ground, edge, timestamp and motion.
--
-- Structural state reads rebuild list items; bound properties update in place.
local theme = require("config.theme")
local icons = require("config.icons")
local notifications = require("lib.notifications")
local updates = require("lib.updates")
local util = require("lib.util")
local cell = require("components.cell")
local icon_button = require("components.icon_button")
local action_button = require("components.action_button")
local panel_action_icon = require("components.panel_action_icon")
local info_badge = require("components.info_badge")
local input = require("components.input")
local reveal = require("components.reveal")

-- A popup leaves the way it came, off the right edge, accelerating as a departure does. History
-- records what happened, so its cards only fade; a slide there would end under the panel's padding.
local SLIDE_EXIT = {
    duration = theme.notification_slide_ms,
    easing = "in_cubic",
    translate = { x = theme.notification_width },
    opacity = 0,
}
-- Spans the exit, so the card below rises as the leaving one clears instead of landing under it.
local MOVE = { duration = theme.notification_slide_ms, easing = "in_out_cubic" }
local FADE_EXIT = { duration = theme.animation_ms, opacity = 0 }

-- How long a card waits behind the one above it, so four arriving at once do not read as one block.
local STAGGER_MS = 60

-- Members an unfolded popup group shows.
local POPUP_MEMBERS = 3

-- Popup entry travels in from the right edge, fast off the mark and long to settle. Paint-only
-- `translate`, not `margin`, lays a `fill`-width card out once instead of re-wrapping it as it moves.
local function slide_in(delay)
    return {
        translate = {
            duration = theme.notification_slide_ms,
            easing = "out_quint",
            delay = delay,
            from = { x = theme.notification_width },
        },
        -- Hold the opacity too, so a waiting card is invisible where it waits. Shorter than the
        -- travel: the card is solid for the settle, not translucent while it is mostly in view.
        opacity = { duration = theme.animation_ms, easing = "out_quad", delay = delay, from = 0 },
        exit = SLIDE_EXIT,
        move = MOVE,
    }
end

local function expander(is_open, on_activate, slot, visible)
    return panel_action_icon(is_open and icons.chevron_up or icons.chevron_down, on_activate,
        { slot = slot, visible = visible })
end

-- An attached picture on a rounded tile. `image_path` is always a file, never a theme name.
local function picture(path)
    return rect {
        width = theme.notification_image,
        height = theme.notification_image,
        radius = theme.radius.sm,
        clip = "rounded",
        align_v = "center",
        children = { image { source = path, fit = "cover", width = theme.notification_image, height = theme.notification_image } },
    }
end

-- One notification inside its group card.
-- A single displayed message uses the card's dismiss button and ground. A collapsed group keeps
-- the per-message dismiss slot so expanding it does not move the title or timestamp.
local function message(notification, ui, opts)
    local id = notification.id
    local expanded = ui.expanded_messages:get()[tostring(id)] or false
    local body, images = notifications.notification_body(notification.body, theme.ACCENT)
    local summary = notification.summary or ""
    local clipped = elided("notification-text-" .. opts.scope .. "-" .. tostring(id))

    local heading = {}
    -- The summary is the card's line; the application name above it is only an eyebrow.
    heading[#heading + 1] = cell(util.bold(summary), theme.FG, theme.font.md, {
        width = "fill",
        align_v = "center",
        wrap = "word",
        -- `0` means "no limit", so expansion needs no second tree.
        max_lines = expanded and 0 or 2,
        elided = clipped,
    })
    -- History says when it arrived. A popup says nothing until a held card is a minute old.
    heading[#heading + 1] = cell(opts.age, theme.DIM, theme.font.xs, { align_v = "center", visible = opts.age_shown })
    -- Title and body share the clipping result; keep the collapse button after restoring all lines.
    -- Reserve the slot so revealing the button cannot change the clipping result.
    heading[#heading + 1] = rect {
        width = theme.control.sm,
        height = theme.control.sm,
        align_v = "center",
        children = { expander(expanded, function()
            ui.toggle_message(id)
        end, "notification-expand-" .. tostring(id), expanded or clipped) },
    }
    if not opts.standalone then
        heading[#heading + 1] = panel_action_icon(icons.close, function()
            mantle.notifications:dismiss(id)
        end, { slot = "notification-close-" .. tostring(id) })
    elseif opts.grouped then
        heading[#heading + 1] = rect { width = theme.control.sm, height = theme.control.sm, align_v = "center" }
    end

    local lines = { row {
        width = "fill",
        align_v = "center",
        spacing = theme.spacing.sm,
        children = heading,
    } }

    if #body > 0 then
        lines[#lines + 1] = cell(body, theme.DIM, theme.font.sm, {
            width = "fill",
            wrap = "word",
            max_lines = expanded and 0 or 2,
            elided = clipped,
            -- Link clicks do not fire the message action. Expand to reach clipped links.
            on_link = function(href)
                mantle.applications:open_url(href)
            end,
        })
    end

    -- All message images sit below the text, leaving the title its full width.
    if notification.image_path then
        table.insert(images, 1, notification.image_path)
    end
    if #images > 0 then
        local pictures = {}
        for _, path in ipairs(images) do
            pictures[#pictures + 1] = picture(path)
        end
        lines[#lines + 1] = row { width = "fill", spacing = theme.spacing.sm, children = pictures }
    end

    -- Always shown when supported, with no Reply button: clicking the field focuses it and gives
    -- niri's `on_demand` layer the keyboard.
    if notification.has_reply then
        local reply_hover = hover("notification-reply-field-" .. tostring(id))
        local reply_ready = ui.reply_ready_id:map(function(ready_id) return ready_id == id end)
        local reply_active = computed({ reply_hover, ui.reply_active_id }, function(hovered, active_id)
            return hovered or active_id == id
        end)
        lines[#lines + 1] = row {
            -- Keep the focused field with its message when optional body/image rows change.
            id = "notification-reply-" .. tostring(id),
            width = "fill",
            align_v = "center",
            spacing = theme.spacing.sm,
            children = {
                -- The shell's input well: a bare field draws only text and caret.
                input { active = reply_active, field = textfield {
                    hover = reply_hover,
                    -- Use the sender's wording, such as "Reply to Alice", or ours if absent.
                    placeholder = notification.reply_placeholder or "Reply",
                    -- Each keystroke stores the text for Send and renews the 60-second hold.
                    on_change = function(text)
                        ui.set_reply_draft(id, text)
                        mantle.notifications:hold_expiry(60)
                    end,
                    on_submit = function(text)
                        ui.set_reply_draft(id, text)
                        ui.send_reply(id)
                    end,
                    -- Escape discards the draft and releases the keyboard.
                    on_cancel = function()
                        ui.clear_reply(id)
                    end,
                } },
                icon_button(icons.send, function()
                    ui.send_reply(id)
                end, {
                    size = theme.control.md,
                    icon_size = theme.icon.sm,
                    background = util.choose(reply_ready, theme.ACCENT_SUBTLE, theme.GLASS_CONTROL_SUBTLE),
                    background_hover = util.choose(reply_ready, theme.ACCENT_LIGHT, theme.GLASS_CONTROL_SUBTLE),
                    border_color = util.choose(reply_ready, theme.ACCENT_MEDIUM, theme.BORDER_SUBTLE),
                    foreground = theme.FG,
                    opacity = util.choose(reply_ready, 1, theme.opacity.disabled),
                    slot = "notification-send-" .. tostring(id),
                }),
            },
        }
    end

    -- `"inline-reply"` is lifted into `has_reply` by the Supervisor and drawn as the field above.
    -- Share the row evenly; labels wrap to two lines and buttons grow together.
    local buttons = {}
    for index, action in ipairs(notification.actions or {}) do
        buttons[#buttons + 1] = action_button(action.label, function()
            if not updates.notification_action(notification, action.key) then
                mantle.notifications:invoke_action(id, action.key)
            end
        end, string.format("notification-action-%d-%d", id, index), {
            icon = action.icon_name,
            width = "fill",
            tone = "subtle",
            max_lines = 2,
        })
    end
    if #buttons > 0 then
        lines[#lines + 1] = row {
            width = "fill",
            spacing = theme.spacing.sm,
            children = buttons,
        }
    end

    -- Inner slides would double popup travel. Messages fade; history's lone message needs no entry.
    local hovered, ground
    local animate = (opts.scope ~= "history" or not opts.standalone) and
        { opacity = { duration = theme.animation_ms, from = 0 } }
        or nil
    if not opts.standalone then
        hovered = hover("notification-message-" .. tostring(id))
        ground = util.choose(hovered, theme.GLASS_HOVER, theme.CLEAR)
        animate.background = theme.animation_ms
        animate.exit = FADE_EXIT
    end
    return column {
        -- Keep the newest message and its draft when the group unfolds.
        id = "notification-message-" .. tostring(id),
        width = "fill",
        spacing = theme.spacing.sm,
        hover = hovered,
        radius = theme.radius.sm,
        background = ground,
        opacity = 1,
        animate = animate,
        on_click = function(_, mouse_button)
            if mouse_button ~= "left" then
                return
            end
            -- Inert while this message has a draft; the X still works.
            if ui.reply_active_id:get() == id then
                return
            end
            if notification.has_default_action then
                mantle.notifications:invoke_action(id, "default")
            else
                mantle.notifications:dismiss(id)
            end
        end,
        children = lines,
    }
end

-- group comes from notifications.group_notifications; ui is lib.notification_state.
return function(group, ui, opts)
    local scope = opts and opts.scope or "popup"
    local in_history = scope == "history"
    local items = group.items
    local expanded = ui.expanded_groups:get()[group.key] or false
    local is_group = #items > 1

    local header = {
        -- Keep the artwork centred in its header slot.
        rect {
            width = theme.notification_app_icon,
            height = theme.notification_app_icon,
            align_v = "center",
            children = { icon {
                name = group.app_icon or "dialog-information",
                size = theme.item_height,
                align_h = "center",
                align_v = "center",
            } },
        },
        -- An eyebrow, the summary below being the line: dim and small, as a panel row's subtitle.
        cell(group.app_name, theme.DIM, theme.font.sm, {
            width = "fill",
            align_v = "center",
        }),
    }
    if is_group then
        local count = tostring(#items)
        header[#header + 1] = info_badge(count, nil, { diameter = math.max(theme.control.xs, #count * theme.font.xs) })
        header[#header + 1] = expander(expanded, function()
            ui.toggle_group(group.key)
        end, "notification-group-" .. group.key)
    end
    -- Member by member, since there is neither `dismiss_all` nor `dismiss_group`.
    header[#header + 1] = panel_action_icon(icons.close, function()
        for _, notification in ipairs(items) do
            mantle.notifications:dismiss(notification.id)
        end
    end, { slot = "notification-group-close-" .. group.key })

    local children = { row {
        width = "fill",
        align_v = "center",
        spacing = theme.spacing.sm,
        children = header,
    } }

    -- Collapsed groups show the newest and count the rest in the header. Unfolded, a popup shows the
    -- newest few and leaves the whole group to the panel, so a busy chat cannot fill the screen.
    local limit = math.min(#items, in_history and #items or POPUP_MEMBERS)
    local members = {}
    for index = 1, limit do
        local notification = items[index]
        local age = in_history and notifications.absolute_time(notification.timestamp)
            or mantle.system:map(function(system)
                return system and notifications.age(system.time, notification.timestamp) or ""
            end)
        members[#members + 1] = message(notification, ui, {
            scope = scope,
            standalone = not is_group or (index == 1 and not expanded),
            grouped = is_group,
            age = age,
            age_shown = not in_history and age:map(function(label) return label ~= "" end) or nil,
        })
    end
    local stack
    if is_group then
        local open = ui.expanded_groups:map(function(groups) return groups[group.key] == true end)
        stack = reveal(members[1], column {
            width = "fill",
            spacing = theme.spacing.sm * 2,
            padding = { top = theme.spacing.sm },
            children = { table.unpack(members, 2) },
        }, open, {
            slot = "notification-members-" .. scope .. "-" .. group.key,
            spacing = theme.spacing.sm,
            moving = ui.groups_animating,
        })
    else
        stack = column {
            width = "fill",
            spacing = 0,
            animate = { spacing = theme.animation_ms },
            children = members,
        }
    end
    children[#children + 1] = stack

    return column {
        width = "fill",
        spacing = theme.spacing.sm,
        padding = theme.spacing.md,
        -- Resting pose: an exit eases from what the node holds.
        translate = { x = 0 },
        opacity = 1,
        -- Popup cards slide in by rank; history cards fade.
        animate = in_history and { opacity = { duration = theme.animation_ms, from = 0 }, exit = FADE_EXIT, move = MOVE }
            or slide_in((group.rank - 1) * STAGGER_MS),
        background = in_history and theme.GLASS_CONTENT or theme.GLASS,
        behind_blur = not in_history,
        radius = theme.radius.md,
        border_width = in_history and theme.border_width or theme.border_width_medium,
        border_color = group.urgency == "critical" and theme.RED or theme.GLASS_BORDER,
        children = children,
    }
end
