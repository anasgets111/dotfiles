local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")
local ui_state = require("lib.ui_state")
local bluetooth_panel = require("modules.bar.panels.bluetooth_panel")

local SLOT = "bluetooth"

local function by_state(off, connected, on)
    return mantle.bluetooth:map(function(bluetooth)
        if bluetooth == nil or not bluetooth.enabled then
            return off
        end
        return #(bluetooth.connected_devices or {}) > 0 and connected or on
    end)
end

local bluetooth_module = icon_button(by_state(icons.bt_off, icons.bt_conn, icons.bt_on), nil, {
    slot = SLOT,
    on_button = function(rect, _)
        ui_state.toggle_panel(bluetooth_panel.kind, rect)
    end,
    selected = ui_state.panel_showing(bluetooth_panel.kind),
    foreground = by_state(theme.TEXT_OFF, theme.ACCENT, theme.FG),
})

local bluetooth_text = mantle.bluetooth:map(function(bluetooth)
    if bluetooth == nil or not bluetooth.available then
        return { text = "Bluetooth: unavailable", detail = "", secondary = "" }
    end
    if not bluetooth.enabled then
        return { text = "Bluetooth: off", detail = "", secondary = "" }
    end
    local devices = util.sorted_devices(bluetooth.connected_devices)
    local first = devices[1]
    local detail
    if first ~= nil then
        local battery = first.battery and first.battery >= 0 and string.format(" · Battery: %d%%", first.battery) or ""
        local name = first.name ~= nil and first.name ~= "" and first.name or first.mac or "?"
        detail = string.format("Top: %s%s", name, battery)
    elseif bluetooth.discovering then
        detail = "Discovering devices…"
    else
        local paired = #(bluetooth.paired_devices or {})
        detail = paired > 0 and string.format("Paired: %d", paired) or "No devices connected"
    end
    local secondary = ""
    if #devices > 1 then
        secondary = string.format("Others: %d more", #devices - 1)
    elseif #devices == 0 and bluetooth.discovering then
        secondary = "Scanning is active"
    end
    return {
        text = #devices > 0 and string.format("Bluetooth: connected (%d)", #devices) or "Bluetooth: on",
        detail = detail,
        secondary = secondary,
    }
end)

local bluetooth_tooltip = tooltip({
    id = "bluetooth_tooltip",
    slot = SLOT,
    lines = bluetooth_text,
})

return { indicator = bluetooth_module, tooltip = bluetooth_tooltip }
