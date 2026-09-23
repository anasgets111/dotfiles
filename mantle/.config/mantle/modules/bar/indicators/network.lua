-- The bar has room for signal strength, not a network name, so the SSID lives in the tooltip and
-- panel.
local theme = require("config.theme")
local util = require("lib.util")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")
local ui_state = require("lib.ui_state")
local network_panel = require("modules.bar.panels.network_panel")

local SLOT = "network"
local network_colour = mantle.network:map(function(network)
    if network == nil or not network.connected then
        return theme.TEXT_OFF
    end
    return select(2, util.band_of(util.active_access_point(network)))
end)

local network_module = icon_button(mantle.network:map(util.network_glyph), nil, {
    slot = SLOT,
    on_button = function(rect, mouse_button)
        if mouse_button == "left" or mouse_button == "right" then
            ui_state.toggle_panel(network_panel.kind, rect)
            network_panel.scan_while_open()
        end
    end,
    selected = ui_state.panel_showing(network_panel.kind),
    -- Lit for a link carrying the default route, which `connected` means, not a bare association.
    -- A wifi link takes its band's colour, the one fact about it worth a glance. Ethernet has none.
    foreground = network_colour,
    badge = mantle.network:map(function(network)
        return (util.band_of(util.active_access_point(network))) or ""
    end),
    badge_font = "Roboto Condensed",
    visible = mantle.network:map(function(network)
        return network ~= nil
    end),
})

local network_text = mantle.network:map(function(network)
    if network == nil then
        return { text = "Network: initializing…", detail = "", secondary = "" }
    end
    local ap = util.active_access_point(network)
    if network.ssid == "Ethernet" then
        return {
            text = "Ethernet",
            detail = string.format("IP: %s", network.ethernet_ip or "--"),
            secondary = ap and
                string.format("Wi-Fi: %s (%d%%) · IP: %s", ap.ssid, ap.strength or 0, network.wifi_ip or "--") or
                "",
        }
    end
    if network.ssid ~= nil and network.ssid ~= "" then
        local strength = (network.strength or 0) > 0 and string.format("%d%%", network.strength) or "--"
        local band = ap and ap.band or ""
        return {
            text = string.format("%s (%s)%s", network.ssid, strength, band ~= "" and " • " .. band or ""),
            detail = string.format("IP: %s", network.wifi_ip or "--"),
            secondary = network.ethernet_ip and string.format("Ethernet: IP: %s", network.ethernet_ip) or "",
        }
    end
    return {
        text = network.wifi_enabled and "Disconnected" or "Wi-Fi radio: off",
        detail = "No network connection",
        secondary = "",
    }
end)

local network_tooltip = tooltip({
    id = "network_tooltip",
    slot = SLOT,
    lines = network_text,
})

return { indicator = network_module, tooltip = network_tooltip }
