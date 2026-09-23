-- A connected audio device's codecs come from `mantle.audio`'s `bluetooth`, joined by MAC.
-- Discovery runs while the panel shows (`lib/ui_state.lua`).
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local toggle = require("components.toggle")
local panel_toggle_card = require("components.panel_toggle_card")
local section_header = require("components.section_header")
local panel_header = require("components.panel_header")
local panel_row = require("components.panel_row")
local panel_action_icon = require("components.panel_action_icon")
local info_badge = require("components.info_badge")
local panel_empty_state = require("components.panel_empty_state")
local spinner = require("components.spinner")
local ui = require("lib.ui_state")

local function device_icon(device)
    return icons.device[device.category or "generic"] or icons.device.generic
end

-- An empty string is truthy in Lua, so `name or mac` would keep it instead of falling back.
local function display_name(device)
    return (device.name or "") ~= "" and device.name or device.mac or "?"
end

local function battery_text(device)
    return device.battery ~= nil and device.battery >= 0 and string.format("%d%%", device.battery) or nil
end

local function enabled(bluetooth)
    return bluetooth ~= nil and bluetooth.enabled
end

local function state_line(bluetooth)
    if not bluetooth.available then
        return "Unavailable"
    end
    if not bluetooth.enabled then
        return "Off"
    end
    local joined = util.sorted_devices(bluetooth.connected_devices)
    local first = joined[1]
    if first then
        local battery = battery_text(first)
        return string.format("%d connected · %s", #joined, display_name(first)) .. (battery and " · " .. battery or "")
    end
    return bluetooth.discovering and "Scanning…" or "No devices connected"
end

local function battery_badge(device)
    local text = battery_text(device)
    if not text then
        return nil
    end
    local level = device.battery
    return info_badge(text, level <= 10 and theme.RED or level <= 20 and theme.YELLOW or theme.ACCENT,
        { opacity = theme.opacity.strong })
end

local function pair_button(device)
    local slot = "bluetooth-pair-" .. tostring(device.mac)
    local hovered = hover(slot)
    return button {
        height = theme.control.sm,
        align_v = "Center",
        radius = theme.radius.sm,
        hover = hovered,
        padding = { left = theme.spacing.sm, right = theme.spacing.sm },
        background = hovered:map(function(is_hovered)
            return is_hovered and theme.ACCENT_SUBTLE or nil
        end),
        on_click = function(_, mouse_button)
            if mouse_button == "left" then
                mantle.bluetooth:invoke("pair", device.mac)
            end
        end,
        children = { cell("Pair", theme.ACCENT, theme.font.xs, { align = "Center", align_v = "Center" }) },
    }
end

-- The `mantle.audio` entry for `mac`, or `nil` when PipeWire has no codec to offer for it.
local function codec_card(audio, mac)
    for _, card in ipairs((audio and audio.bluetooth) or {}) do
        if card.mac == mac and #card.codecs > 0 then
            return card
        end
    end
end

local function active_codec(card)
    for _, option in ipairs((card and card.codecs) or {}) do
        if option.index == card.active then
            return option.codec
        end
    end
end

-- Paired and available rows share one list, empty while the radio is off. A row keeps its key
-- across connect and disconnect, so it changes in place rather than leaving and arriving.
local rows = computed({ mantle.bluetooth, mantle.audio, ui.bluetooth_codec_for }, function(bluetooth, audio, open_for)
    local out = {}
    if not enabled(bluetooth) then
        return out
    end
    -- An open codec list follows its device as rows of its own, keeping one flat source.
    local function add(devices, status)
        for _, device in ipairs(devices) do
            local card = status == "connected" and codec_card(audio, device.mac) or nil
            out[#out + 1] = {
                kind = "device",
                device = device,
                status = status,
                card = card,
                key = "device-" .. tostring(device.mac)
            }
            if card and open_for == device.mac then
                for _, option in ipairs(card.codecs) do
                    out[#out + 1] = {
                        kind = "codec",
                        device = device,
                        card = card,
                        option = option,
                        key = "codec-" .. tostring(device.mac) .. "-" .. option.index
                    }
                end
            end
        end
    end
    local joined = util.sorted_devices(bluetooth.connected_devices)
    local known = util.sorted_devices(bluetooth.paired_devices)
    local found = util.sorted_devices(bluetooth.discovered_devices)
    if #joined + #known > 0 then
        out[#out + 1] = { kind = "header", label = "paired", key = "header-paired" }
        add(joined, "connected")
        add(known, "paired")
    end
    if #found > 0 then
        out[#out + 1] = { kind = "header", label = "available", key = "header-available" }
        add(found, "available")
    end
    return out
end)

-- One always-on signal for every busy spinner; one minted per row in `itemfn` would leak.
local SPINNING = mantle.bluetooth:map(function()
    return true
end)

-- One codec under its device; picking another switches to it and closes the list.
local function codec_row(item)
    local option = item.option
    local active = option.index == item.card.active
    return panel_row {
        slot = "bluetooth-codec-" .. tostring(item.device.mac) .. "-" .. option.index,
        title = option.codec,
        subtitle = option.description,
        selected = active,
        on_activate = not active and function()
            mantle.audio:invoke("set_bluetooth_profile", item.card.device, option.index)
            ui.bluetooth_codec_for:set("")
        end or nil,
    }
end

local function device_row(item)
    if item.kind == "header" then
        return section_header(item.label)
    end
    if item.kind == "codec" then
        return codec_row(item)
    end
    local device = item.device
    local slot = "bluetooth-device-" .. tostring(device.mac)
    if device.busy ~= nil then
        -- No click, so a second pair or connect cannot start over the first.
        return panel_row {
            slot = slot,
            icon = device_icon(device),
            title = display_name(device),
            subtitle = device.busy .. "…",
            trailing = spinner(SPINNING, theme.icon.md),
        }
    end
    local connected = item.status == "connected"
    local trailing = { connected and battery_badge(device) or nil }
    if connected then
        trailing[#trailing + 1] = panel_action_icon(icons.disconnect, function()
            mantle.bluetooth:invoke("disconnect", device.mac)
        end, { slot = "bluetooth-disconnect-" .. tostring(device.mac), tint = theme.RED })
    end
    if item.status ~= "available" then
        trailing[#trailing + 1] = panel_action_icon(icons.trash, function()
            mantle.bluetooth:invoke("forget", device.mac)
        end, { slot = "bluetooth-forget-" .. tostring(device.mac), tint = theme.RED })
    elseif not device.blocked then
        trailing[#trailing + 1] = pair_button(device)
    end
    -- A blocked row offers nothing BlueZ would refuse.
    local codec = active_codec(item.card)
    local on_activate = nil
    if item.status == "paired" and not device.blocked then
        on_activate = function()
            mantle.bluetooth:invoke("connect", device.mac)
        end
    elseif item.card ~= nil then
        on_activate = function()
            local open_for = ui.bluetooth_codec_for:get()
            ui.bluetooth_codec_for:set(open_for == device.mac and "" or device.mac)
        end
    end
    return panel_row {
        slot = slot,
        icon = device_icon(device),
        title = display_name(device),
        subtitle = connected and (codec and "Connected · " .. codec or "Connected")
            or device.blocked and "Blocked" or nil,
        selected = connected,
        trailing = row { spacing = theme.spacing.xs, align_v = "Center", children = trailing },
        on_activate = on_activate,
    }
end

local body = {
    panel_header {
        title = "Bluetooth",
        icon = mantle.bluetooth:map(function(bluetooth)
            return enabled(bluetooth) and icons.bt_on or icons.bt_off
        end),
        active = mantle.bluetooth:map(enabled),
        subtitle = util.label(mantle.bluetooth, state_line),
        trailing = {
            -- No adapter means no switch to flip. Hidden rather than greyed, because `toggle` has
            -- no disabled look.
            rect {
                visible = util.shown_when(mantle.bluetooth, function(bluetooth)
                    return bluetooth.available
                end),
                children = {
                    toggle(mantle.bluetooth, function(bluetooth)
                        return bluetooth.enabled
                    end, function(new_value)
                        mantle.bluetooth:invoke("set_enabled", new_value)
                    end),
                },
            },
        },
    },
    -- "visible" lets devices find this one, and the agent asks before any pairs. "scan" is discovery.
    row {
        width = "Fill",
        spacing = theme.spacing.xs,
        visible = util.shown_when(mantle.bluetooth, enabled),
        children = {
            panel_toggle_card {
                slot = "bluetooth-visible-tile",
                icon = icons.bt_visible,
                label = "Visible",
                signal = mantle.bluetooth,
                read = function(bluetooth)
                    return bluetooth.discoverable
                end,
                on_change = function(on)
                    mantle.bluetooth:invoke("set_discoverable", on)
                end,
            },
            panel_toggle_card {
                slot = "bluetooth-scan-tile",
                icon = icons.bt_scan,
                label = "Scan",
                signal = mantle.bluetooth,
                read = function(bluetooth)
                    return bluetooth.discovering
                end,
                on_change = function(on)
                    mantle.bluetooth:invoke(on and "start_discovery" or "stop_discovery")
                end,
            },
        },
    },
    list {
        width = "Fill",
        max_height = theme.panel_list_height,
        scroll = scroll("bluetooth_devices"),
        spacing = theme.spacing.xs,
        source = rows,
        itemfn = device_row,
        key = function(item)
            return item.key
        end,
    },
    panel_empty_state(
        util.label(mantle.bluetooth, function(bluetooth)
            if not bluetooth.available then
                return "Bluetooth unavailable"
            elseif not bluetooth.enabled then
                return "Bluetooth off"
            end
            return bluetooth.discovering and "Scanning…" or "No devices found"
        end),
        -- `rows` is empty exactly when the radio is off or every device list is.
        computed({ mantle.bluetooth, rows }, function(bluetooth, out)
            return bluetooth ~= nil and #out == 0
        end),
        { icon = icons.bt_off }
    ),
}

return { kind = "bluetooth", body = body }
