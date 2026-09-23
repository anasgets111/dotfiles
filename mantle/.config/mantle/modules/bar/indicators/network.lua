-- Signal glyph opens the network panel. The SSID belongs in the tooltip and panel; the bar has
-- room for strength, not a network name.
local theme = require("config.theme")
local util = require("lib.util")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")
local ui_state = require("lib.ui_state")
local network_panel = require("modules.bar.panels.network_panel")

local SLOT = "network"
local network_colour = mantle.network:map(function(n)
    if n == nil or not n.connected then
        return theme.TEXT_OFF
    end
    local _, colour = util.band_of(util.active_access_point(n))
    return colour
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
    -- Lit for a link carrying the default route, not a bare association: `connected` answers the
    -- question the bar asks. A wifi link then takes its band's colour: the band is the one fact
    -- about a connection worth a glance, and ethernet carries none.
    foreground = network_colour,
    badge = mantle.network:map(function(n)
        return (util.band_of(util.active_access_point(n))) or ""
    end),
    badge_foreground = network_colour,
    badge_font = "Roboto Condensed",
    badge_size = theme.font.xs,
    visible = mantle.network:map(function(n)
        return n ~= nil
    end),
})

local network_text = mantle.network:map(function(n)
    if n == nil then
        return { title = "Network: initializing…", detail = "", secondary = "" }
    end
    local ap = util.active_access_point(n)
    if n.ssid == "Ethernet" then
        return {
            title = "Ethernet",
            detail = string.format("IP: %s", n.ethernet_ip or "--"),
            secondary = ap and string.format("Wi-Fi: %s (%d%%) · IP: %s", ap.ssid, ap.strength or 0, n.wifi_ip or "--") or
                "",
        }
    end
    if n.ssid ~= nil and n.ssid ~= "" then
        local strength = (n.strength or 0) > 0 and string.format("%d%%", n.strength) or "--"
        local band = ap and ap.band or ""
        return {
            title = string.format("%s (%s)%s", n.ssid, strength, band ~= "" and " • " .. band or ""),
            detail = string.format("IP: %s", n.wifi_ip or "--"),
            secondary = n.ethernet_ip and string.format("Ethernet: IP: %s", n.ethernet_ip) or "",
        }
    end
    return {
        title = n.wifi_enabled and "Disconnected" or "Wi-Fi radio: off",
        detail = "No network connection",
        secondary = "",
    }
end)

local network_tooltip = tooltip({
    id = "network_tooltip",
    slot = SLOT,
    text = network_text:map(function(t) return t.title end),
    detail = network_text:map(function(t) return t.detail end),
    secondary = network_text:map(function(t) return t.secondary end),
})

return { indicator = network_module, tooltip = network_tooltip }
