-- One application's notifications as one card, shared by the popup stack and the history panel.
-- `opts.scope` carries their different ground, edge, timestamp and motion.
--
-- Structure is built, not bound: `children` takes an array, so a read here rebuilds the item. Appearance
-- stays bound.
--
-- ponytail: the cards below a dismissed one still close its gap on one frame; the engine has no move
-- transition (`docs/roadmap.md`).
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

-- Only critical rings red; low and normal share the glass hairline, so accent keeps meaning "active".
-- Read from the group's newest notification.
local function border_for(urgency)
    return urgency == "critical" and theme.RED or theme.GLASS_BORDER
end

-- A popup leaves the way it came, off the right edge, accelerating as a departure does. History
-- records what happened, so its cards only fade; a slide there would end under the panel's padding.
local SLIDE_EXIT = {
    duration = theme.notification_slide_ms,
    easing = "InCubic",
    translate = { x = theme.notification_width },
    opacity = 0,
}
local FADE_EXIT = { duration = theme.animation_ms, opacity = 0 }

-- How long a card waits behind the one above it, so four arriving at once do not read as one block.
local STAGGER_MS = 60

-- Members an unfolded popup group shows.
local POPUP_MEMBERS = 3

-- Popup entry travels in from the right edge, fast off the mark and long to settle. Paint-only
-- `translate`, not `margin`, lays a `Fill`-width card out once instead of re-wrapping it as it moves.
local function slide_in(delay)
    return {
        translate = {
            duration = theme.notification_slide_ms,
            easing = "OutQuint",
            delay = delay,
            from = { x = theme.notification_width },
        },
        -- Hold the opacity too, so a waiting card is invisible where it waits. Shorter than the
        -- travel: the card is solid for the settle, not translucent while it is mostly in view.
        opacity = { duration = theme.animation_ms, easing = "OutQuad", delay = delay, from = 0 },
        exit = SLIDE_EXIT,
    }
end

local function expander(is_open, on_activate, slot)
    return panel_action_icon(is_open and icons.chevron_up or icons.chevron_down, on_activate, { slot = slot })
end

-- An attached picture on a rounded tile. `image_path` is always a file, never a theme name.
local function picture(path)
    return rect {
        width = theme.notification_image,
        height = theme.notification_image,
        radius = theme.radius.sm,
        clip = "Rounded",
        align_v = "Center",
        children = { image { source = path, fit = "cover", width = theme.notification_image, height = theme.notification_image } },
    }
end

-- One notification inside its group card.
-- `standalone` is a group of one: omit its dismiss button because the card header closes it, and
-- its ground because there is nothing to distinguish.
local function message(notification, ui, opts)
    local id = notification.id
    local expanded = ui.expanded_messages:get()[tostring(id)] or false
    local body = notifications.notification_body(notification.body, theme.ACCENT)
    local body_length = notifications.runs_length(body)
    local summary = notification.summary or ""

    local heading = {}
    -- `image_path`, not `app_icon`, is the message attachment. The application mark is in the header.
    if notification.image_path then
        heading[#heading + 1] = picture(notification.image_path)
    end
    -- The summary is the card's line; the application name above it is only an eyebrow.
    heading[#heading + 1] = cell(util.bold(summary), theme.FG, theme.font.md, {
        width = "Fill",
        align_v = "Center",
        wrap = "Word",
        -- `0` means "no limit", so expansion needs no second tree.
        max_lines = expanded and 0 or 2,
    })
    -- History says when it arrived. A popup says nothing until a held card is a minute old.
    heading[#heading + 1] = cell(opts.age, theme.DIM, theme.font.xs, { align_v = "Center", visible = opts.age_shown })
    -- Show a chevron only when something is hidden. A count, not a measurement: about two lines
    -- of each face at the card's width. ponytail: an "elided" signal from `text` would be exact.
    if expanded or utf8.len(summary) > 80 or body_length > 110 then
        heading[#heading + 1] = expander(expanded, function()
            ui.toggle_message(id)
        end, "notification-expand-" .. tostring(id))
    end
    if not opts.standalone then
        heading[#heading + 1] = panel_action_icon(icons.close, function()
            mantle.notifications:dismiss(id)
        end, { slot = "notification-close-" .. tostring(id) })
    end

    local lines = { row {
        width = "Fill",
        align_v = "Center",
        spacing = theme.spacing.sm,
        children = heading,
    } }

    if body_length > 0 then
        lines[#lines + 1] = cell(body, theme.DIM, theme.font.sm, {
            width = "Fill",
            wrap = "Word",
            max_lines = expanded and 0 or 2,
            -- An underlined run opens without firing the message click; plain words
            -- still do. Buttons below cover links elided before their words were drawn.
            on_link = function(href)
                mantle.applications:open_url(href)
            end,
        })
    end

    -- Inline body pictures go under the text (see `notifications.notification_body`); `notify-send`
    -- cannot send one.
    local images = notifications.notification_images(notification.body)
    if #images > 0 then
        local pictures = {}
        for _, path in ipairs(images) do
            pictures[#pictures + 1] = picture(path)
        end
        lines[#lines + 1] = row { width = "Fill", spacing = theme.spacing.sm, children = pictures }
    end

    -- Always shown when supported, with no Reply button: clicking the field focuses it and gives
    -- niri's `OnDemand` layer the keyboard.
    if notification.has_reply then
        lines[#lines + 1] = row {
            -- `lines` is conditional and id-less siblings zip in order, so an arriving body would
            -- hand this row the images row's node, and with it the focused `NodeId`.
            id = "notification-reply-" .. tostring(id),
            width = "Fill",
            align_v = "Center",
            spacing = theme.spacing.sm,
            children = {
                -- The shell's input well: a bare field draws only text and caret.
                input { field = textfield {
                    width = "Fill",
                    height = "Fill",
                    -- Use the sender's wording, such as "Reply to Alice", or ours if absent.
                    placeholder = notification.reply_placeholder or "Reply",
                    font_size = theme.font.sm,
                    foreground = theme.FG,
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
                    background = theme.ACCENT_MEDIUM,
                    slot = "notification-send-" .. tostring(id),
                }),
            },
        }
    end

    -- `"inline-reply"` is lifted into `has_reply` by the Supervisor and drawn as the field above.
    -- Right-aligned, as dialogs place theirs.
    local buttons = {}
    for index, action in ipairs(notification.actions or {}) do
        buttons[#buttons + 1] = action_button(action.label, function()
            if not updates.notification_action(notification, action.key) then
                mantle.notifications:invoke_action(id, action.key)
            end
        end, string.format("notification-action-%d-%d", id, index), { icon = action.icon_name })
    end
    -- One button per distinct body link, for the ones elision cut off; the words open them too.
    for index, href in ipairs(notifications.notification_links(notification.body)) do
        buttons[#buttons + 1] = action_button(notifications.link_label(href), function()
            mantle.applications:open_url(href)
        end, string.format("notification-link-%d-%d", id, index))
    end
    if #buttons > 0 then
        lines[#lines + 1] = row {
            width = "Fill",
            align_h = "End",
            spacing = theme.spacing.sm,
            children = buttons,
        }
    end

    local content = column {
        width = "Fill",
        spacing = theme.spacing.sm,
        padding = not opts.standalone and theme.spacing.sm or nil,
        children = lines,
    }

    -- A message fades in, never slides: a second slide inside a sliding card doubled the travel. The
    -- fade is what shows a message joining a card already on screen, where the card itself is not
    -- new and the newest message swaps in under the count. A group member also fades out when
    -- dismissed, since a slide would cross the card's edge, and its subtle ground and hairline take
    -- accent under the pointer. History's lone message has nothing to announce.
    local hovered, ground, ring
    local animate = (opts.fade or not opts.standalone) and { opacity = { duration = theme.animation_ms, from = 0 } }
        or nil
    if not opts.standalone then
        hovered = hover("notification-message-" .. tostring(id))
        ground = hovered:map(function(is_hovered)
            return is_hovered and theme.ACCENT_SUBTLE or theme.BG_SUBTLE
        end)
        ring = hovered:map(function(is_hovered)
            return is_hovered and theme.ACCENT_MEDIUM or theme.BORDER_SUBTLE
        end)
        animate.background = theme.animation_ms
        animate.border_color = theme.animation_ms
        animate.exit = FADE_EXIT
    end
    return button {
        -- Named for its notification: a collapsed group reuses the newest message's slot, and
        -- without the id the reply field's `NodeId` and draft move under another summary.
        id = "notification-message-" .. tostring(id),
        width = "Fill",
        hover = hovered,
        radius = theme.radius.sm,
        background = ground,
        border_width = ring and theme.border_width or nil,
        border_color = ring,
        opacity = 1,
        animate = animate,
        on_click = function(_, mouse_button)
            if mouse_button ~= "left" then
                return
            end
            -- Inert while this message has a draft; the X still works.
            if ui.reply_draft_id:get() == id and ui.reply_draft:get() ~= "" then
                return
            end
            if notification.has_default_action then
                mantle.notifications:invoke_action(id, "default")
            else
                mantle.notifications:dismiss(id)
            end
        end,
        children = { content },
    }
end

-- `group` is one entry of `notifications.group_notifications`, and `ui` is `lib/ui_state`. A popup card
-- has heavier glass, a live age once held and edge travel. `opts.scope = "history"` has the lighter
-- ground, "Wed 02:32 PM" and no travel.
return function(group, ui, opts)
    local in_history = opts ~= nil and opts.scope == "history"
    local items = group.items
    local expanded = ui.expanded_groups:get()[group.key] or false
    local is_group = #items > 1

    local header = {
        -- Artwork, not a glyph. The plate keeps arbitrary-colour icons off the glass.
        rect {
            width = theme.notification_app_icon,
            height = theme.notification_app_icon,
            radius = theme.radius.sm,
            background = theme.BG_SUBTLE,
            border_width = theme.border_width,
            border_color = theme.BORDER_SUBTLE,
            align_v = "Center",
            children = { icon {
                name = group.app_icon or "dialog-information",
                size = theme.item_height,
                align_h = "Center",
                align_v = "Center",
            } },
        },
        -- An eyebrow, the summary below being the line: dim and small, as a panel row's subtitle.
        cell(group.app_name, theme.DIM, theme.font.sm, {
            width = "Fill",
            align_v = "Center",
        }),
    }
    if is_group then
        header[#header + 1] = info_badge(tostring(#items))
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
        width = "Fill",
        align_v = "Center",
        spacing = theme.spacing.sm,
        children = header,
    } }

    -- Collapsed groups show the newest and count the rest in the header. Unfolded, a popup shows the
    -- newest few and leaves the whole group to the panel, so a busy chat cannot fill the screen.
    local limit = (is_group and not expanded) and 1 or in_history and #items or POPUP_MEMBERS
    local shown = {}
    for index = 1, math.min(#items, limit) do
        shown[index] = items[index]
    end
    for _, notification in ipairs(shown) do
        local age = in_history and notifications.absolute_time(notification.timestamp)
            or util.label(mantle.system, function(system)
                return notifications.age(system.time, notification.timestamp)
            end)
        children[#children + 1] = message(notification, ui, {
            -- The rendered count, because a collapsed group renders one card-level message.
            standalone = #shown == 1,
            fade = not in_history,
            age = age,
            age_shown = not in_history and util.shown_when(mantle.system, function(system)
                return notifications.age(system.time, notification.timestamp) ~= ""
            end) or nil,
        })
    end

    return column {
        width = "Fill",
        spacing = theme.spacing.sm,
        padding = theme.spacing.md,
        -- Resting pose: an exit eases from what the node holds.
        translate = { x = 0 },
        opacity = 1,
        -- The one thing the scopes disagree on: popup travel says an event came from outside,
        -- staggered by `rank`; history only fades.
        animate = in_history and { opacity = { duration = theme.animation_ms, from = 0 }, exit = FADE_EXIT }
            or slide_in((group.rank - 1) * STAGGER_MS),
        background = in_history and theme.GLASS_CONTENT or theme.GLASS,
        -- A popup card is its own sheet floating over wallpaper, so it takes the heavier edge.
        -- History sits on `panel_host`'s already-blurred card, on a hairline like its other rows.
        blur = not in_history,
        radius = theme.radius.md,
        border_width = in_history and theme.border_width or theme.border_width_medium,
        border_color = border_for(group.urgency),
        children = children,
    }
end
