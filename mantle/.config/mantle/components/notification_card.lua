-- One application's notifications as one card, shared by the popup stack and the history panel.
-- `opts.scope` carries their different ground, timestamp and entry motion.
--
-- Structure is built, not bound. `children` takes an array, and a `list`'s `itemfn` re-runs for every
-- element on every pass, so reads here rebuild the tree. Appearance stays bound.
--
-- ponytail: the cards below a dismissed one still close its gap on one frame; the engine has no move
-- transition (`docs/roadmap.md`).
local theme = require("config.theme")
local icons = require("config.icons")
local notifications = require("lib.notifications")
local util = require("lib.util")
local cell = require("components.cell")
local icon_button = require("components.icon_button")
local action_button = require("components.action_button")

-- Card border by urgency, read from the group's newest notification.
local BORDER_BY_URGENCY = {
    low = theme.BORDER,
    normal = theme.ACCENT_MEDIUM,
    critical = theme.with_opacity(theme.RED, 0.6),
}

-- Both scopes leave the same way, travelling off the right edge as they fade. This surface is one card
-- wide, so travel clips quickly and the fade makes the exit legible.
local SLIDE_EXIT = {
    duration = theme.notification_slide_ms,
    easing = "OutCubic",
    translate = { x = theme.notification_width },
    opacity = 0,
}

-- How long a card waits behind the one above it, so four arriving at once do not read as one block.
local STAGGER_MS = 60

-- Popup entry travels in from the right edge. Paint-only `translate`, not `margin`, lays a `Fill`-width
-- card out once instead of re-wrapping it as it moves.
local function slide_in(delay)
    return {
        translate = {
            duration = theme.notification_slide_ms,
            easing = "OutCubic",
            delay = delay,
            from = { x = theme.notification_width },
        },
        -- Hold the opacity too, so a waiting card is invisible where it waits.
        opacity = { duration = theme.notification_slide_ms, delay = delay, from = 0 },
        exit = SLIDE_EXIT,
    }
end

-- The card's small controls. `rest` and `lit` are the ground; a close is only its glyph.
local function small_button(glyph, on_activate, slot, rest, lit)
    return icon_button(glyph, on_activate, {
        size = theme.control.xs,
        icon_size = theme.icon.xs,
        background = rest,
        background_hover = lit,
        border = false,
        foreground = theme.FG,
        slot = slot,
    })
end

local function ghost_close(slot, on_activate)
    return small_button(icons.close, on_activate, slot, theme.CLEAR, theme.CLEAR)
end

local function expander(is_open, on_activate, slot)
    return small_button(is_open and icons.chevron_up or icons.chevron_down, on_activate, slot,
        theme.GLASS_CONTENT, theme.GLASS_HOVER)
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
        heading[#heading + 1] = icon {
            name = notification.image_path,
            size = theme.icon.xl,
            align_v = "Center",
        }
    end
    heading[#heading + 1] = cell(summary, theme.FG, theme.font.md, {
        width = "Fill",
        -- Centre a lone card title, but left-align a grouped message.
        align = opts.standalone and "Center" or "Start",
        align_v = "Center",
        wrap = "Word",
        -- `0` means "no limit", so expansion needs no second tree.
        max_lines = expanded and 0 or 2,
    })
    -- Only when requested: history is about when; a popup is about now.
    if opts.age then
        heading[#heading + 1] = cell(opts.age, theme.DIM, theme.font.xs, { align_v = "Center" })
    end
    -- Show a chevron only when something is hidden.
    if expanded or #summary > 60 or body_length > 80 then
        heading[#heading + 1] = expander(expanded, function()
            ui.toggle_message(id)
        end, "notification-expand-" .. tostring(id))
    end
    if not opts.standalone then
        heading[#heading + 1] = ghost_close("notification-close-" .. tostring(id), function()
            mantle.notifications:invoke("dismiss", id)
        end)
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
                mantle.applications:invoke("open_url", href)
            end,
        })
    end

    -- Inline body pictures go under the text (see `notifications.notification_body`); `notify-send`
    -- cannot send one.
    local images = notifications.notification_images(notification.body)
    if #images > 0 then
        local pictures = {}
        for _, path in ipairs(images) do
            pictures[#pictures + 1] = icon { name = path, size = theme.icon.xl }
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
                textfield {
                    width = "Fill",
                    height = theme.control.md,
                    -- Use the sender's wording, such as "Reply to Alice", or ours if absent.
                    placeholder = notification.reply_placeholder or "Reply",
                    font_size = theme.font.sm,
                    foreground = theme.FG,
                    -- Each keystroke stores the text for Send and renews the 60-second hold.
                    on_change = function(text)
                        ui.set_reply_draft(id, text)
                        mantle.notifications:invoke("hold_expiry", 60)
                    end,
                    on_submit = function(text)
                        ui.set_reply_draft(id, text)
                        ui.send_reply(id)
                    end,
                    -- Escape discards the draft and releases the keyboard.
                    on_cancel = function()
                        ui.clear_reply(id)
                    end,
                },
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
    -- Push buttons to the card edges. A `row` only distributes `Start`/`Center`/`End`, so a filling
    -- spacer goes in each gap. A lone button has no gap and stays centred.
    local buttons = {}
    local function add(control)
        if #buttons > 0 then
            buttons[#buttons + 1] = rect { width = "Fill" }
        end
        buttons[#buttons + 1] = control
    end
    for index, action in ipairs(notification.actions or {}) do
        add(action_button(action.label, function()
            mantle.notifications:invoke("invoke_action", id, action.key)
        end, string.format("notification-action-%d-%d", id, index), { icon = action.icon_name }))
    end
    -- One button per distinct body link, for the ones elision cut off; the words open them too.
    for index, href in ipairs(notifications.notification_links(notification.body)) do
        add(action_button(notifications.link_label(href), function()
            mantle.applications:invoke("open_url", href)
        end, string.format("notification-link-%d-%d", id, index)))
    end
    if #buttons > 0 then
        lines[#lines + 1] = row {
            width = "Fill",
            align_h = "Center",
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

    local hovered = hover("notification-message-" .. tostring(id))
    local animate = slide_in(0)
    -- An `if`, not `a and nil or b`, which cannot produce nil and would box a lone message twice.
    local ground, ring
    if not opts.standalone then
        -- Subtle ground and hairline, accent under the pointer. Content glass is the history
        -- card's ground, so a second card ground would disappear into it.
        ground = hovered:map(function(is_hovered)
            return is_hovered and theme.ACCENT_SUBTLE or theme.BG_SUBTLE
        end)
        ring = hovered:map(function(is_hovered)
            return is_hovered and theme.ACCENT_MEDIUM or theme.BORDER_SUBTLE
        end)
        animate.background = theme.animation_ms
        animate.border_color = theme.animation_ms
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
        -- Resting pose: an exit eases from what the node holds.
        translate = { x = 0 },
        opacity = 1,
        -- A leaving node takes no room, so opacity carries the exit while the card clips travel.
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
                mantle.notifications:invoke("invoke_action", id, "default")
            else
                mantle.notifications:invoke("dismiss", id)
            end
        end,
        children = { content },
    }
end

-- `group` is one entry of `notifications.group_notifications`, and `ui` is `lib/ui_state`. A popup card
-- has heavier glass, no clock and edge travel. `opts.scope = "history"` has the lighter ground,
-- "Wed 14:32" and no travel.
return function(group, ui, opts)
    local in_history = opts ~= nil and opts.scope == "history"
    local items = group.items
    local expanded = ui.expanded_groups:get()[group.key] or false
    local is_group = #items > 1

    local title = is_group and string.format("%s (%d)", group.app_name, #items) or group.app_name
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
        cell(util.bold(title), theme.FG, theme.font.md, {
            width = "Fill",
            align = "Center",
            align_v = "Center",
        }),
    }
    if is_group then
        header[#header + 1] = expander(expanded, function()
            ui.toggle_group(group.key)
        end, "notification-group-" .. group.key)
    end
    -- Member by member, since there is neither `dismiss_all` nor `dismiss_group`.
    header[#header + 1] = ghost_close("notification-group-close-" .. group.key, function()
        for _, notification in ipairs(items) do
            mantle.notifications:invoke("dismiss", notification.id)
        end
    end)

    local children = { row {
        width = "Fill",
        align_v = "Center",
        spacing = theme.spacing.sm,
        children = header,
    } }

    -- Collapsed groups show the newest and count the rest in the header. The feed caps `#items` at 20.
    local shown = (is_group and not expanded) and { items[1] } or items
    for _, notification in ipairs(shown) do
        children[#children + 1] = message(notification, ui, {
            -- The rendered count, because a collapsed group renders one card-level message.
            standalone = #shown == 1,
            age = in_history and notifications.absolute_time(notification.timestamp) or nil,
        })
    end

    return column {
        width = "Fill",
        spacing = theme.spacing.sm,
        padding = theme.spacing.md,
        -- Resting pose. History does not move in, but its exit still slides the card from here.
        translate = { x = 0, y = 0 },
        opacity = 1,
        -- The one thing the scopes disagree on. History records what happened, so it fades without
        -- travel. Popup travel says an event came from outside, staggered by `rank`.
        animate = in_history and { opacity = { duration = theme.animation_ms, from = 0 }, exit = SLIDE_EXIT }
            or slide_in((group.rank - 1) * STAGGER_MS),
        background = in_history and theme.GLASS_CONTENT or theme.GLASS,
        -- A popup card is its own sheet. History sits on `panel_host`'s already-blurred card.
        blur = not in_history,
        radius = theme.radius.md,
        border_width = theme.border_width_medium,
        border_color = BORDER_BY_URGENCY[group.urgency] or theme.BORDER,
        children = children,
    }
end
