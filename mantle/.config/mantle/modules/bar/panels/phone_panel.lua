-- KDE Connect devices through `mantle.android_connect`. Each linked device carries its own action row,
-- so two phones never share one ambiguous set of controls. Opening the panel broadcasts
-- (`lib/ui_state.lua`), so a phone that dropped off answers again.
local section_list = require("components.section_list")
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local glyph = require("components.glyph")
local action_button = require("components.action_button")
local section_header = require("components.section_header")
local panel_header = require("components.panel_header")
local panel_row = require("components.panel_row")
local panel_action_icon = require("components.panel_action_icon")
local info_badge = require("components.info_badge")
local panel_empty_state = require("components.panel_empty_state")
local spinner = require("components.spinner")
local panel_toggle_card = require("components.panel_toggle_card")
local segmented = require("components.segmented")
local disclosure = require("lib.disclosure")
local input = require("components.input")

local android = mantle.android_connect
-- A binary older than `android_connect`: `panel_host` still lists the kind and reads `typing`.
if not android then
    return { kind = "phone", typing = state("phone_command_adding", false) }
end
-- The pressed action's key (`"<id>:ring"`, `"search"`) while its feedback shows, one at a time.
local flash = state("phone_flash", "")
local flash_timer
local function flash_for(key, ms)
    if flash_timer then
        flash_timer:cancel()
    end
    flash:set(key)
    flash_timer = timer(ms, function()
        flash_timer = nil
        flash:set("")
    end)
end

local DEVICE_ICONS = {
    phone = icons.device.phone,
    tablet = icons.device.tablet,
    laptop = icons.device.computer,
    desktop = icons.display,
    tv = icons.television,
}

-- A linked device's expanded plugin tiles, three to a row. A tile flips `disabled_plugins`, which
-- drops the connection so the device learns it. Clipboard is one radio over two settings above them:
-- "Off" is the plugin, and "Manual" or "Auto" is the daemon's own `autoShare`, which needs no reconnect.
local PLUGINS = {
    { label = "Alerts",  plugin = "notification", icon = icons.bell },
    { label = "Media",   plugin = "mpris",        icon = icons.media },
    { label = "Calls",   plugin = "telephony",    icon = icons.phone },
    { label = "Find",    plugin = "findmyphone",  icon = icons.ring },
    { label = "Browse",  plugin = "sftp",         icon = icons.folder_open },
    { label = "Receive", plugin = "share",        icon = icons.updates },
}
local PLUGIN_ROWS = util.chunk(PLUGINS, 3)
local CLIPBOARD_MODES = { "Off", "Manual", "Auto" }

local function enabled(device, plugin)
    for _, off in ipairs(device.disabled_plugins) do
        if off == plugin then
            return false
        end
    end
    return true
end

-- The device whose settings are open, or `""`.
local settings_for = disclosure.state("phone_settings_for", "")

-- The add-command form and its two drafts. `panel_host` hands the bar the keyboard while it is open.
local adding = disclosure.state("phone_command_adding", false)
local command_name = disclosure.state("phone_command_name", "")
local command_line = disclosure.state("phone_command_line", "")

local function close_form()
    adding:set(false)
    command_name:set("")
    command_line:set("")
end

local function submit_command()
    local name, line = util.trim(command_name:get()), util.trim(command_line:get())
    if name ~= "" and line ~= "" then
        android:add_command(name, line)
        close_form()
    end
end

local GROUPS = {
    { key = "request",   label = "Pairing requests" },
    { key = "linked",    label = "Linked" },
    { key = "paired",    label = "Paired" },
    { key = "available", label = "Available" },
}

-- An unpaired device that went out of reach has nothing to offer, so it has no group.
local function group_of(device)
    if device.pairing_requested then
        return "request"
    elseif device.paired then
        return (device.reachable or device.reconnecting) and "linked" or "paired"
    end
    return device.reachable and "available" or nil
end

local function by_name(left, right)
    local a, b = left.name:lower(), right.name:lower()
    return a ~= b and a < b or left.id < right.id
end

-- Paired and reachable devices, sorted, for the bar glyph and the header line.
local function linked(state)
    local out = {}
    for _, device in ipairs(state and state.devices or {}) do
        if group_of(device) == "linked" then
            out[#out + 1] = device
        end
    end
    table.sort(out, by_name)
    return out
end

local function state_line(state)
    if not state.available then
        return "KDE Connect is not running"
    end
    if state.transfer_progress then
        return string.format("Sending file · %d%%", state.transfer_progress)
    end
    local devices = linked(state)
    local first = devices[1]
    if first == nil then
        return "No device linked"
    end
    local battery = first.battery and string.format(" · %d%%%s", first.battery, first.charging and " charging" or "")
        or ""
    return #devices > 1 and string.format("%s +%d", first.name, #devices - 1) or first.name .. battery
end

local rows = computed({ android, flash, settings_for, adding }, function(state, flashed, open_for, form_open)
    local grouped = {}
    for _, device in ipairs(state.devices) do
        local key = group_of(device)
        if key then
            grouped[key] = grouped[key] or {}
            table.insert(grouped[key], device)
        end
    end
    local out = {}
    for _, group in ipairs(GROUPS) do
        local devices = grouped[group.key]
        if devices then
            table.sort(devices, by_name)
            out[#out + 1] = { kind = "header", label = group.label, key = "header-" .. group.key }
            for _, device in ipairs(devices) do
                local id, open = device.id, open_for == device.id
                out[#out + 1] = { kind = group.key, device = device, open = open, key = "device-" .. id }
                if group.key == "linked" and not device.reconnecting then
                    out[#out + 1] = { kind = "actions", device = device, flashed = flashed, key = "actions-" .. id }
                end
                if group.key == "linked" and open then
                    out[#out + 1] = { kind = "header", label = "Sync · a change reconnects", key = "sync-" .. id }
                    out[#out + 1] = { kind = "clipboard", device = device, key = "clipboard-" .. id }
                    for index, plugins in ipairs(PLUGIN_ROWS) do
                        out[#out + 1] = {
                            kind = "plugins",
                            device = device,
                            plugins = plugins,
                            height = theme.panel_toggle_height,
                            key = "plugins-" .. id .. "-" .. index,
                        }
                    end
                    out[#out + 1] = { kind = "unpair", device = device, key = "unpair-" .. id }
                end
            end
        end
    end
    -- One list for every paired device, so it follows the devices rather than living under one.
    if state.available then
        out[#out + 1] = { kind = "header", label = "Phone commands", key = "header-commands" }
        local commands = table.move(state.commands, 1, #state.commands, 1, {})
        table.sort(commands, by_name)
        for _, command in ipairs(commands) do
            out[#out + 1] = { kind = "command", command = command, key = "command-" .. command.id }
        end
        out[#out + 1] = { kind = "add_command", open = form_open, key = "add-command" }
        if form_open then
            out[#out + 1] = {
                kind = "command_form",
                height = 3 * theme.control.md + 2 * theme.spacing.xs,
                key = "command-form",
            }
        end
    end
    return out
end, {})

local function battery_badge(device)
    local level = device.battery
    if not level then
        return nil
    end
    local ground = device.charging and theme.GREEN
        or level <= util.battery_thresholds.critical and theme.RED
        or level <= util.battery_thresholds.low and theme.YELLOW or theme.ACCENT
    return info_badge(string.format("%d%%", level), ground, { opacity = theme.opacity.strong })
end

local function unpair_icon(device)
    return panel_action_icon(icons.trash, function()
        android:unpair(device.id)
    end, { slot = "phone-unpair-" .. device.id, tint = theme.RED })
end

-- Neither ring nor clipboard reports back, so a press shows for a moment. A mount takes seconds and
-- shows until `mounted` or `browse_error` arrives, or 15 s for a daemon that answers neither.
local function actions_row(item)
    local device, id = item.device, item.device.id
    local function is(verb)
        return item.flashed == id .. ":" .. verb
    end
    local function button(verb, label, glyph_name, on_activate, spinning)
        return action_button(label, on_activate, "phone-" .. verb .. "-" .. id,
            { glyph = glyph_name, spinning = spinning, width = "fill", height = theme.control.md })
    end
    local files
    if device.mounted then
        files = button("unmount", "Unmount", icons.eject, function() android:unmount(id) end)
    elseif is("browse") then
        files = button("browse", "Opening", nil, nil, true)
    else
        files = button("browse", "Files", icons.folder_open, function()
            flash_for(id .. ":browse", 15000)
            android:browse(id)
        end)
    end
    -- A switched-off plugin takes its button with it, since the daemon refuses the action.
    local children = {}
    if enabled(device, "findmyphone") then
        children[#children + 1] = button("ring", is("ring") and "Ringing" or "Ring", icons.ring, function()
            flash_for(id .. ":ring", 3000)
            android:ring(id)
        end)
    end
    if enabled(device, "clipboard") then
        children[#children + 1] = button("clipboard", is("clipboard") and "Sent" or "Clipboard",
            is("clipboard") and icons.check or icons.clipboard_send, function()
                flash_for(id .. ":clipboard", 2000)
                android:share_clipboard(id)
            end)
    end
    if enabled(device, "sftp") then
        children[#children + 1] = files
    end
    return row {
        width = "fill",
        height = theme.control.lg,
        align_v = "center",
        spacing = theme.spacing.xs,
        visible = #children > 0,
        children = children,
    }
end

local function command_rows(item)
    if item.kind == "command" then
        local command = item.command
        return panel_row {
            icon = icons.command,
            title = command.name,
            subtitle = command.command,
            trailing = panel_action_icon(icons.trash, function()
                android:remove_command(command.id)
            end, { slot = "phone-command-remove-" .. command.id, tint = theme.RED }),
        }
    end
    if item.kind == "add_command" then
        return panel_row {
            slot = "phone-command-add-row",
            icon = icons.plus,
            title = "Add command",
            subtitle = "A button on the phone that runs it here",
            trailing = glyph(item.open and icons.chevron_down or icons.chevron_right, theme.DIM, theme.icon.sm),
            on_activate = function()
                if item.open then
                    close_form()
                else
                    adding:set(true)
                end
            end,
        }
    end
    return column {
        width = "fill",
        spacing = theme.spacing.xs,
        children = {
            input { field = textfield {
                autofocus = true,
                placeholder = "Name on the phone",
                on_change = function(typed) command_name:set(typed or "") end,
                on_cancel = close_form,
            } },
            input { field = textfield {
                placeholder = "Command, run with sh -c",
                on_change = function(typed) command_line:set(typed or "") end,
                on_submit = submit_command,
                on_cancel = close_form,
            } },
            row {
                width = "fill",
                spacing = theme.spacing.xs,
                children = {
                    action_button("Cancel", close_form, "phone-command-cancel", { tone = "quiet", width = "fill" }),
                    action_button("Add", submit_command, "phone-command-submit", {
                        width = "fill",
                        disabled = computed({ command_name, command_line }, function(name, line)
                            return util.trim(name) == "" or util.trim(line) == ""
                        end),
                    }),
                },
            },
        },
    }
end

local function device_row(item)
    if item.kind == "header" then
        return section_header(item.label)
    end
    if item.device == nil then
        return command_rows(item)
    end
    local device = item.device
    if item.kind == "actions" then
        return actions_row(item)
    end
    -- Closes the expanded settings, away from the row's chevron where a stray click would land.
    if item.kind == "unpair" then
        return row {
            width = "fill",
            height = theme.control.lg,
            align_v = "center",
            children = { action_button("Unpair", function()
                settings_for:set("")
                android:unpair(device.id)
            end, "phone-unpair-" .. device.id, { tone = "quiet", glyph = icons.trash, width = "fill" }) },
        }
    end
    local id = device.id
    local function current(state)
        return util.find(state.devices, function(candidate) return candidate.id == id end)
    end
    if item.kind == "plugins" then
        local tiles = {}
        for _, entry in ipairs(item.plugins) do
            tiles[#tiles + 1] = panel_toggle_card {
                slot = "phone-plugin-" .. id .. "-" .. entry.plugin,
                icon = entry.icon,
                label = entry.label,
                signal = android,
                read = function(state)
                    local now = current(state)
                    return now ~= nil and enabled(now, entry.plugin)
                end,
                on_change = function(on)
                    android:set_plugin_enabled(id, entry.plugin, on)
                end,
                disabled = android:map(function(state)
                    local now = current(state)
                    return now ~= nil and now.reconnecting
                end),
            }
        end
        return row { width = "fill", spacing = theme.spacing.xs, children = tiles }
    end
    if item.kind == "clipboard" then
        return panel_row {
            title = "Clipboard",
            leading = glyph(icons.clipboard_send, theme.FG, theme.icon.md, { align_v = "center" }),
            trailing = segmented {
                slot = "phone-clipboard-" .. id,
                options = CLIPBOARD_MODES,
                value = android:map(function(state)
                    local now = current(state)
                    return not (now and enabled(now, "clipboard")) and "Off"
                        or now.clipboard_auto_share and "Auto" or "Manual"
                end),
                on_select = function(mode)
                    local now = current(android:get())
                    if now and enabled(now, "clipboard") ~= (mode ~= "Off") then
                        android:set_plugin_enabled(id, "clipboard", mode ~= "Off")
                    end
                    if mode ~= "Off" then
                        android:set_clipboard_auto_share(id, mode == "Auto")
                    end
                end,
            },
        }
    end
    local live = item.kind == "linked"
    local leading = rect {
        width = theme.icon.md,
        height = theme.icon.md,
        children = { glyph(DEVICE_ICONS[device.device_type] or icons.device.phone, live and theme.ACCENT or theme.FG,
            theme.icon.md, { align = "center", align_v = "center" }) },
    }
    local trailing, subtitle = {}, nil
    if live then
        if device.signal_strength then
            trailing[#trailing + 1] = glyph(icons.cellular[math.min(device.signal_strength, 4)], theme.DIM,
                theme.icon.sm, { align_v = "center" })
        end
        trailing[#trailing + 1] = battery_badge(device)
        trailing[#trailing + 1] = glyph(item.open and icons.chevron_down or icons.chevron_right,
            theme.DIM, theme.icon.sm, { align_v = "center" })
        if device.reconnecting then
            table.insert(trailing, 1, spinner(true, theme.icon.sm))
        end
        subtitle = device.reconnecting and "Reconnecting to apply the change"
            or device.browse_error and "Files: " .. device.browse_error
            or device.mounted and "Storage mounted" or nil
    elseif item.kind == "request" then
        subtitle = "Wants to pair"
        trailing[#trailing + 1] = action_button("Accept", function()
            android:accept_pairing(device.id)
        end, "phone-accept-" .. device.id, { height = theme.control.sm })
        trailing[#trailing + 1] = panel_action_icon(icons.close, function()
            android:reject_pairing(device.id)
        end, { slot = "phone-reject-" .. device.id, tint = theme.RED })
    elseif item.kind == "paired" then
        subtitle = "Out of reach"
        trailing[#trailing + 1] = unpair_icon(device)
    elseif device.pairing_sent then
        -- `unpair` withdraws the request; the daemon reports no rejection, so the engine lapses it at 30 s.
        subtitle = "Accept on the device"
        trailing[#trailing + 1] = spinner(true, theme.icon.md)
        trailing[#trailing + 1] = panel_action_icon(icons.close, function()
            android:unpair(device.id)
        end, { slot = "phone-cancel-" .. device.id, tint = theme.RED })
    else
        trailing[#trailing + 1] = action_button("Pair", function()
            android:pair(device.id)
        end, "phone-pair-" .. device.id, { tone = "subtle", height = theme.control.sm })
    end
    return panel_row {
        slot = "phone-device-" .. device.id,
        leading = leading,
        title = device.name,
        subtitle = subtitle,
        selected = live,
        opacity = item.kind == "paired" and theme.opacity.muted or nil,
        on_activate = live and function()
            settings_for:set(item.open and "" or device.id)
        end or nil,
        trailing = row { spacing = theme.spacing.xs, align_v = "center", children = trailing },
    }
end

local body = {
    panel_header {
        title = "Phone",
        icon = android:map(function(state)
            return #linked(state) > 0 and icons.phone_link or icons.phone_link_off
        end, icons.phone_link_off),
        active = android:map(function(state)
            return #linked(state) > 0
        end, false),
        subtitle = util.label(android, state_line),
    },
    section_list(rows, "phone_devices", device_row, nil, theme.phone_list_height),
    panel_empty_state(
        util.label(android, function(state)
            return state.available and "No devices nearby" or "Start kdeconnect-service to link a phone"
        end),
        rows:map(function(out)
            return util.find(out, function(item) return item.device ~= nil end) == nil
        end),
        { icon = icons.phone_link_off }
    ),
    -- A broadcast asks every phone in range to answer; no answer looks the same as no phone.
    action_button(flash:map(function(key)
        return key == "search" and "Searching" or "Search again"
    end), function()
        flash_for("search", 3000)
        android:broadcast()
    end, "phone-search", {
        width = "fill",
        spinning = flash:map(function(key)
            return key == "search"
        end),
        visible = computed({ android, rows }, function(state, out)
            return state.available and util.find(out, function(item) return item.device ~= nil end) == nil
        end),
    }),
}

-- A downward crossing while draining, as `modules/global/power_events.lua` warns for the laptop.
local function crossed(device, was, percent)
    return was ~= nil and was.battery ~= nil and device.battery ~= nil and not device.charging
        and device.battery <= percent and (was.battery > percent or was.charging == true)
end

-- The daemon posts nothing for an incoming request, which lapses in 30 s, so the shell does. `-p`
-- prints the popup's id before the chosen action, so an answer given elsewhere withdraws it.
local popups = {}
android:on_change(function(state, previous)
    local before = {}
    for _, device in ipairs(previous and previous.devices or {}) do
        before[device.id] = device
    end
    local requested = {}
    for _, device in ipairs(state.devices) do
        local was = before[device.id]
        local critical = crossed(device, was, util.battery_thresholds.critical)
        if critical or crossed(device, was, util.battery_thresholds.low) then
            process.detach("notify-send", {
                "-a", "KDE Connect", "-i", "phone", "-u", critical and "critical" or "normal", "-t", "5000", "-e",
                device.name .. (critical and " battery critical" or " battery low"),
                string.format("%d%% left", device.battery),
            })
        end
        if (device.mounted or device.browse_error) and flash:get() == device.id .. ":browse" then
            flash:set("")
        end
        if device.pairing_requested then
            requested[device.id] = true
            if popups[device.id] == nil then
                local id = device.id
                popups[id] = true
                process.run("notify-send", {
                    "-a", "KDE Connect", "-i", "phone", "-e", "-t", "30000", "-p",
                    "-A", "accept=Accept", "-A", "reject=Reject",
                    device.name .. " wants to pair", "Accept only a device you are pairing right now",
                }, function(line)
                    if tonumber(line) then
                        popups[id] = tonumber(line)
                    elseif line == "accept" then
                        android:accept_pairing(id)
                    elseif line == "reject" then
                        android:reject_pairing(id)
                    end
                end, function() end)
            end
        end
    end
    for id, popup in pairs(popups) do
        if not requested[id] then
            popups[id] = nil
            if popup ~= true then
                mantle.notifications:dismiss(popup)
            end
        end
    end
end)

return { kind = "phone", body = body, linked = linked, typing = adding }
