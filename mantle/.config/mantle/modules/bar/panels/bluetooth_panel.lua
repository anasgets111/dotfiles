-- A connected audio device's codecs come from `mantle.audio`'s `bluetooth`, joined by MAC.
-- Discovery runs while the panel shows (`lib/ui_state.lua`).
local section_list = require("components.section_list")
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local glyph = require("components.glyph")
local action_button = require("components.action_button")
local toggle = require("components.toggle")
local panel_toggle_card = require("components.panel_toggle_card")
local section_header = require("components.section_header")
local panel_header = require("components.panel_header")
local panel_row = require("components.panel_row")
local panel_action_icon = require("components.panel_action_icon")
local info_badge = require("components.info_badge")
local panel_empty_state = require("components.panel_empty_state")
local spinner = require("components.spinner")
local disclosure = require("lib.disclosure")

local function device_icon(device)
    return icons.device[device.category or "generic"] or icons.device.generic
end

-- An empty string is truthy in Lua, so `name or mac` would keep it instead of falling back.
local function display_name(device)
    return (device.name or "") ~= "" and device.name or device.mac or "?"
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
    local count = #(bluetooth.connected_devices or {})
    if count > 0 then
        return string.format("%d connected", count) .. (bluetooth.discovering and " · Scanning…" or "")
    end
    return bluetooth.discovering and "Scanning…" or "No devices connected"
end

local function battery_badge(device)
    local level = device.battery
    if not (level and level >= 0) then
        return nil
    end
    return info_badge(string.format("%d%%", level),
        level <= 10 and theme.RED or level <= 20 and theme.YELLOW or theme.ACCENT,
        { opacity = theme.opacity.strong })
end

local function pair_button(device)
    return action_button("Pair", function()
        mantle.bluetooth:pair(device.mac)
    end, "bluetooth-pair-" .. tostring(device.mac), { tone = "subtle", height = theme.control.sm })
end

-- The `mantle.audio` entry for `mac`, or `nil` when PipeWire has no codec to offer for it.
local function codec_card(audio, mac)
    return util.find((audio and audio.bluetooth), function(card) return card.mac == mac and #card.codecs > 0 end)
end

local function active_codec(card)
    local option = util.find(card and card.codecs, function(option) return option.index == card.active end)
    return option and option.codec
end

-- The MAC whose codec list is open, or `""`.
local codec_for = disclosure.state("bluetooth_codec_for", "")

-- Device groups share one list, empty while the radio is off. A row keeps its key
-- across connect and disconnect, so it changes in place rather than leaving and arriving.
local rows = computed({ mantle.bluetooth, mantle.audio, codec_for }, function(bluetooth, audio, open_for)
    local out = {}
    if not enabled(bluetooth) then
        return out
    end
    -- An open codec list follows its device as rows of its own, keeping one flat source.
    local function add(devices, status)
        if #devices == 0 then
            return
        end
        out[#out + 1] = { kind = "header", label = status, key = "header-" .. status }
        for _, device in ipairs(devices) do
            local card = status == "connected" and codec_card(audio, device.mac) or nil
            out[#out + 1] = {
                kind = "device",
                device = device,
                status = status,
                card = card,
                codec_open = open_for == device.mac,
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
    add(util.sorted_devices(bluetooth.connected_devices), "connected")
    add(util.sorted_devices(bluetooth.paired_devices), "paired")
    add(util.sorted_devices(bluetooth.discovered_devices), "available")
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
        leading = rect { width = theme.icon.md, height = theme.icon.md },
        color = active and theme.ACCENT or nil,
        trailing = active and glyph(icons.check, theme.ACCENT, theme.icon.sm) or nil,
        on_activate = not active and function()
            mantle.audio:set_bluetooth_profile(item.card.device, option.index)
            codec_for:set("")
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
    local leading = rect {
        width = theme.icon.md,
        height = theme.icon.md,
        children = { glyph(device_icon(device), item.status == "connected" and theme.ACCENT or theme.FG,
            theme.icon.md, { align = "Center", align_v = "Center" }) },
    }
    if device.busy ~= nil then
        -- No click, so a second pair or connect cannot start over the first.
        return panel_row {
            slot = slot,
            leading = leading,
            title = display_name(device),
            subtitle = device.busy .. "…",
            trailing = spinner(SPINNING, theme.icon.md),
        }
    end
    local connected = item.status == "connected"
    local trailing = { connected and battery_badge(device) or nil }
    if connected then
        trailing[#trailing + 1] = panel_action_icon(icons.disconnect, function()
            mantle.bluetooth:disconnect(device.mac)
        end, { slot = "bluetooth-disconnect-" .. tostring(device.mac), tint = theme.RED })
    end
    if item.status ~= "available" then
        trailing[#trailing + 1] = panel_action_icon(icons.trash, function()
            mantle.bluetooth:forget(device.mac)
        end, { slot = "bluetooth-forget-" .. tostring(device.mac), tint = theme.RED })
    elseif not device.blocked then
        trailing[#trailing + 1] = pair_button(device)
    end
    -- A blocked row offers nothing BlueZ would refuse.
    local codec = active_codec(item.card)
    local on_activate = nil
    if item.status == "paired" and not device.blocked then
        on_activate = function()
            mantle.bluetooth:connect(device.mac)
        end
    elseif item.card ~= nil then
        trailing[#trailing + 1] = glyph(item.codec_open and icons.chevron_down or icons.chevron_right,
            theme.DIM, theme.icon.sm, { align_v = "Center" })
        on_activate = function()
            local open_for = codec_for:get()
            codec_for:set(open_for == device.mac and "" or device.mac)
        end
    end
    return panel_row {
        slot = slot,
        leading = leading,
        title = display_name(device),
        subtitle = connected and codec
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
                        mantle.bluetooth:set_enabled(new_value)
                    end, "bluetooth-power"),
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
                    mantle.bluetooth:set_discoverable(on)
                end,
            },
            panel_toggle_card {
                slot = "bluetooth-scan-tile",
                icon = icons.bt_scan,
                label = "Scan",
                spinning = mantle.bluetooth:map(function(bluetooth)
                    return bluetooth ~= nil and bluetooth.discovering
                end),
                signal = mantle.bluetooth,
                read = function(bluetooth)
                    return bluetooth.discovering
                end,
                on_change = function(on)
                    if on then
                        mantle.bluetooth:start_discovery()
                    else
                        mantle.bluetooth:stop_discovery()
                    end
                end,
            },
        },
    },
    section_list(rows, "bluetooth_devices", device_row),
    panel_empty_state(
        util.label(mantle.bluetooth, function(bluetooth)
            if not bluetooth.available then
                return "No Bluetooth adapter found"
            elseif not bluetooth.enabled then
                return "Turn on Bluetooth to see devices"
            end
            return bluetooth.discovering and "Looking for devices…" or "No devices found"
        end),
        -- `rows` is empty exactly when the radio is off or every device list is.
        computed({ mantle.bluetooth, rows }, function(bluetooth, out)
            return bluetooth ~= nil and #out == 0
        end)
    ),
}

return { kind = "bluetooth", body = body }
