-- Hidden while the KDE Connect daemon is absent. The badge is the first linked device's battery below 100%.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")
local ui_state = require("lib.ui_state")

-- A binary older than `android_connect` has no phone to show; the bar skips a nil indicator.
if not mantle.android_connect then
    return { tooltips = {} }
end
local phone_panel = require("modules.bar.panels.phone_panel")

local SLOT = "phone"
local android = mantle.android_connect

local function requested(state)
    return util.find(state.devices, function(device) return device.pairing_requested end) ~= nil
end

local function open(rect)
    ui_state.toggle_panel(phone_panel.kind, rect)
end

local phone_module = icon_button(android:map(function(state)
    return #phone_panel.linked(state) > 0 and icons.phone_link or icons.phone_link_off
end, icons.phone_link_off), nil, {
    slot = SLOT,
    on_buttons = { left = open, right = open, middle = open },
    selected = ui_state.panel_showing(phone_panel.kind),
    -- A waiting pairing request outranks everything, since it times out on the phone.
    foreground = android:map(function(state)
        return requested(state) and theme.YELLOW or #phone_panel.linked(state) > 0 and theme.ACCENT or theme.TEXT_OFF
    end, theme.TEXT_OFF),
    -- A full battery is the unremarkable case, so it leaves the glyph bare.
    badge = android:map(function(state)
        local first = phone_panel.linked(state)[1]
        return first and first.battery and first.battery < 100 and tostring(first.battery) or ""
    end, ""),
    badge_size = theme.battery_badge_font_size,
    visible = android:map(function(state)
        return state.available
    end, false),
})

local function phone_text_of(state)
    if state == nil then
        return { text = "Phone: initializing…", detail = "", secondary = "" }
    end
    local devices = phone_panel.linked(state)
    local first = devices[1]
    if first == nil then
        return {
            text = "Phone: none linked",
            detail = requested(state) and "Pairing request waiting" or "",
            secondary = "",
        }
    end
    local parts = {}
    if first.battery then
        parts[#parts + 1] = string.format("Battery: %d%%%s", first.battery, first.charging and " (charging)" or "")
    end
    if first.signal_strength then
        parts[#parts + 1] = string.format("Signal: %d/4", first.signal_strength)
    end
    return {
        text = first.name,
        detail = table.concat(parts, " · "),
        secondary = #devices > 1 and string.format("Others: %d more", #devices - 1) or "",
    }
end

local phone_tooltip = tooltip({
    slot = SLOT,
    lines = android:map(phone_text_of, phone_text_of()),
})

return { indicator = phone_module, tooltips = { phone_tooltip } }
