local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")
local ui_state = require("lib.ui_state")
local bluetooth_panel = require("modules.bar.panels.bluetooth_panel")

local SLOT = "bluetooth"

local function connected(b)
    return util.sorted_devices((b or {}).connected_devices)
end

local function device_name(device)
    return device.name ~= nil and device.name ~= "" and device.name or device.mac or "?"
end

local bluetooth_module = icon_button(mantle.bluetooth:map(function(b)
    if b == nil or not b.enabled then
        return icons.bt_off
    end
    return #connected(b) > 0 and icons.bt_conn or icons.bt_on
end), function(rect)
    ui_state.toggle_panel(bluetooth_panel.kind, rect)
end, {
    slot = SLOT,
    selected = ui_state.panel_showing(bluetooth_panel.kind),
    foreground = mantle.bluetooth:map(function(b)
        if b == nil or not b.enabled then
            return theme.TEXT_OFF
        end
        return #connected(b) > 0 and theme.ACCENT or theme.FG
    end),
})

local bluetooth_text = mantle.bluetooth:map(function(b)
    if b == nil or not b.available then
        return { title = "Bluetooth: unavailable", detail = "", secondary = "" }
    end
    if not b.enabled then
        return { title = "Bluetooth: off", detail = "", secondary = "" }
    end
    local devices = connected(b)
    local first = devices[1]
    local detail
    if first ~= nil then
        local battery = first.battery and first.battery >= 0 and string.format(" · Battery: %d%%", first.battery) or ""
        detail = string.format("Top: %s%s", device_name(first), battery)
    elseif b.discovering then
        detail = "Discovering devices…"
    else
        local paired = #(b.paired_devices or {})
        detail = paired > 0 and string.format("Paired: %d", paired) or "No devices connected"
    end
    local secondary
    if #devices > 1 then
        secondary = string.format("Others: %d more", #devices - 1)
    elseif #devices == 0 and b.discovering then
        secondary = "Scanning is active"
    else
        secondary = ""
    end
    return {
        title = #devices > 0 and string.format("Bluetooth: connected (%d)", #devices) or "Bluetooth: on",
        detail = detail,
        secondary = secondary,
    }
end)
local bluetooth_title = bluetooth_text:map(function(t) return t.title end)
local bluetooth_detail_one = bluetooth_text:map(function(t) return t.detail end)
local bluetooth_detail_two = bluetooth_text:map(function(t) return t.secondary end)

local bluetooth_tooltip = tooltip({
    id = "bluetooth_tooltip",
    slot = SLOT,
    text = bluetooth_title,
    detail = bluetooth_detail_one,
    detail_options = { visible = bluetooth_detail_one:map(function(text) return text ~= "" end) },
    secondary = bluetooth_detail_two,
    secondary_options = { visible = bluetooth_detail_two:map(function(text) return text ~= "" end) },
})

return { indicator = bluetooth_module, tooltip = bluetooth_tooltip }
