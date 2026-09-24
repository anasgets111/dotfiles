-- `layout::secure_submit` counts only reachable fields, so an `autofocus` name field arms
-- normally; `modules/shell/panel_host.lua` asks for the keyboard for both.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local glyph = require("components.glyph")
local toggle = require("components.toggle")
local icon_button = require("components.icon_button")
local panel_header = require("components.panel_header")
local panel_toggle_card = require("components.panel_toggle_card")
local panel_row = require("components.panel_row")
local section_header = require("components.section_header")
local panel_action_icon = require("components.panel_action_icon")
local panel_empty_state = require("components.panel_empty_state")
local spinner = require("components.spinner")
local action_button = require("components.action_button")
local input = require("components.input")
local callout = require("components.callout")
local ui = require("lib.ui_state")

local KIND = "network"

-- Payload order is connected, saved, then descending raw signal. The list re-sorts by tier.
local function access_points(network)
    return (network and network.available_networks) or {}
end

local function detail_line(first, second)
    return first and second and (first .. " · " .. second) or first or second or ""
end

-- NetworkManager reports Mb/s, with `0` for unknown.
local function speed_text(mbps)
    return mbps >= 1000 and string.format("%g Gb/s", mbps / 1000) or mbps > 0 and string.format("%d Mb/s", mbps) or nil
end

-- A radio's toggle tile: `radio` prefixes its `_present`/`_enabled` fields and `set_*_enabled` action.
local function radio_tile(radio, name, tile_icon, detail)
    return panel_toggle_card {
        slot = "network-" .. radio .. "-tile",
        icon = tile_icon,
        label = util.label(mantle.network, function(network)
            return network[radio .. "_present"] and name or "No " .. name
        end),
        disabled = util.shown_when(mantle.network, function(network)
            return not network[radio .. "_present"]
        end),
        detail = util.label(mantle.network, detail),
        signal = mantle.network,
        read = function(network)
            return network[radio .. "_enabled"]
        end,
        on_change = function(new_value)
            mantle.network:invoke("set_" .. radio .. "_enabled", new_value)
        end,
    }
end

local function radio_on(network)
    return network ~= nil and network.networking_enabled and network.wifi_present and network.wifi_enabled
end

-- Header subtitle, in priority order: an off stack speaks before its radios. No payload means
-- NetworkManager never answered.
local function state_line(network)
    if network == nil then
        return "Unavailable"
    end
    if not network.networking_enabled then
        return "Off"
    end
    if network.connecting_ssid then
        return "Connecting to " .. network.connecting_ssid
    end
    if network.ssid == "Ethernet" then
        return "Ethernet connected"
    end
    if network.ssid then
        return network.ssid
    end
    if not network.wifi_enabled then
        return "Wi-Fi off"
    end
    return network.scanning and "Scanning…" or "Not connected"
end

local function header_glyph(network)
    if network == nil or not network.networking_enabled then
        return icons.wifi_off
    end
    if network.ssid == "Ethernet" then
        return icons.ethernet
    end
    return network.wifi_enabled and icons.wifi[4] or icons.wifi_off
end

-- The scanned list and the hidden-network row share one condition.
local radio_up_and_idle = computed({ mantle.network, ui.hidden_join }, function(network, joining)
    return radio_on(network) and not joining
end)

-- `connect_error` stays until the next attempt, so the dismissal is view state.
local error_dismissed = state("network_error_dismissed", false)

mantle.network:on_change(function(network, previous)
    if previous == nil then
        return
    end
    if network.connecting_ssid ~= nil and previous.connecting_ssid == nil then
        error_dismissed:set(false)
    elseif previous.connecting_ssid ~= nil and network.connecting_ssid == nil and network.connect_error == nil then
        -- An aborted join also clears `connecting_ssid` with no error, so success is the radio now
        -- holding that network, not the spinner stopping.
        local joined = util.active_access_point(network)
        if joined ~= nil and joined.ssid == previous.connecting_ssid and ui.panel_is(KIND) then
            ui.close_panel()
        end
    end
end)

-- Saved networks (the joined one included) first, then the rest. Within each, sort by tier, not
-- raw strength, so scan jitter cannot swap rows under the pointer.
local function before(left, right)
    if left.ap.active ~= right.ap.active then
        return left.ap.active
    end
    local left_tier, right_tier = util.signal_tier(left.ap.strength), util.signal_tier(right.ap.strength)
    if left_tier ~= right_tier then
        return left_tier > right_tier
    end
    return tostring(left.ap.ssid):lower() < tostring(right.ap.ssid):lower()
end

local rows = mantle.network:map(function(network)
    local connecting = network and network.connecting_ssid
    local sections = { saved = {}, available = {} }
    for _, ap in ipairs(access_points(network)) do
        local group = (ap.saved or ap.active) and sections.saved or sections.available
        group[#group + 1] = {
            kind = "ap",
            ap = ap,
            key = "ap-" .. tostring(ap.ssid),
            connecting = connecting ~= nil and connecting == ap.ssid,
            blocked = connecting ~= nil and connecting ~= ap.ssid,
        }
    end
    local out = {}
    for _, label in ipairs({ "saved", "available" }) do
        local group = sections[label]
        if #group > 0 then
            table.sort(group, before)
            out[#out + 1] = { kind = "header", label = label, key = "header-" .. label }
            table.move(group, 1, #group, #out + 1, out)
        end
    end
    return out
end)

-- Fixed, so titles line up whether a row's badge reads "2.4", "5G" or nothing.
local LEADING_WIDTH = theme.control.md

local function access_point_row(entry)
    if entry.kind == "header" then
        return section_header(entry.label)
    end
    local ap = entry.ap
    local band, color = util.band_of(ap)

    local leading = {
        glyph(icons.wifi[util.signal_tier(ap.strength)], color, theme.icon.md, { align_v = "Center" }),
        band and cell(util.bold(band), color, theme.font.xs, { align_v = "End" }) or nil,
    }
    local trailing = {
        ap.active and panel_action_icon(icons.disconnect, function()
            mantle.network:invoke("disconnect_wifi")
        end, { slot = "network-disconnect-" .. tostring(ap.ssid), tint = theme.RED }) or nil,
    }
    if ap.saved or ap.active then
        trailing[#trailing + 1] = panel_action_icon(icons.trash, function()
            mantle.network:invoke("forget", ap.ssid)
        end, { slot = "network-forget-" .. tostring(ap.ssid), tint = theme.RED })
    end
    if ap.secure then
        trailing[#trailing + 1] = glyph(icons.lock, theme.DIM, theme.font.xs, { align_v = "Center" })
    end
    return panel_row {
        slot = "network-ap-" .. tostring(ap.ssid),
        leading = row { width = LEADING_WIDTH, align_v = "Center", children = leading },
        title = ap.ssid or "?",
        subtitle = entry.connecting and "Connecting…" or nil,
        selected = ap.active,
        opacity = entry.blocked and theme.opacity.disabled or nil,
        trailing = row { spacing = theme.spacing.xs, align_v = "Center", children = trailing },
        on_activate = not ap.active and not entry.blocked and function()
            -- `hidden` is required; scanned `available_networks` entries are not hidden.
            mantle.network:invoke("connect", ap.ssid, false)
        end or nil,
    }
end

-- ## The credential sheet
-- One sheet walks a join from a typed name through the wait to the password, retitled at each step:
-- a form per row would put a `secure_submit` field in every one. `lib/ui_state.lua`'s
-- `credential_step` says which step is on screen, `hidden_join` whether the list stands aside.
local step = ui.credential_step

local function during(name)
    return step:map(function(current)
        return current == name
    end)
end

-- A failure keeps the sheet up here, rather than returning the error to the row it came from.
local sheet_title = util.bold(computed({ step, ui.hidden_ssid, mantle.network }, function(current, name, network)
    local target = (network and network.password_ssid) or name
    if current == "name" then
        return "Hidden network"
    elseif current == "waiting" then
        return string.format("Connecting to “%s”", target)
    elseif current == "failed" then
        return string.format("Could not join “%s”", target)
    end
    return string.format("Connect to “%s”", target)
end))

local error_message = util.label(mantle.network, function(network)
    return network.connect_error and network.connect_error.message or ""
end)

-- Enter, or Next. `hidden = true` makes the Supervisor write `802-11-wireless.hidden` and treat the
-- target as secured, since a network it cannot see is one it cannot ask about: either a saved
-- profile answers or `password_ssid` comes back and this sheet asks for the rest. The name is kept
-- for the title and Retry. Submitting nothing is not an attempt to join "".
local function submit_hidden_name()
    local name = util.trim(ui.hidden_draft:get())
    if name == "" then
        return
    end
    ui.hidden_ssid:set(name)
    mantle.network:invoke("connect", name, true)
end

-- Called by the indicator on every toggle: an open scans now and every 10 s after, a close cancels
-- the chain. Cancelling first keeps a quick close and reopen from running two.
local rescan = nil

local function scan_while_open()
    if rescan ~= nil then
        rescan:cancel()
    end
    if not ui.panel_is(KIND) then
        return
    end
    if radio_on(mantle.network:get()) then
        mantle.network:invoke("scan")
    end
    rescan = timer(10000, scan_while_open)
end

local body = {
    panel_header {
        title = "Network",
        icon = mantle.network:map(header_glyph),
        active = mantle.network:map(function(network)
            return network ~= nil and network.networking_enabled
        end),
        subtitle = mantle.network:map(state_line),
        trailing = {
            -- The rescan glyph spins inside its button while a scan is in flight.
            icon_button(icons.refresh, function()
                mantle.network:invoke("scan")
            end, {
                slot = "network-rescan",
                size = theme.control.sm,
                icon_size = theme.icon.sm,
                spinning = util.shown_when(mantle.network, function(network)
                    return network.scanning
                end),
                visible = util.shown_when(mantle.network, function(network)
                    return network ~= nil and (radio_on(network) or network.scanning)
                end),
            }),
            -- Controls the whole stack; off hides the tiles.
            toggle(mantle.network, function(network)
                return network.networking_enabled
            end, function(new_value)
                mantle.network:invoke("set_networking_enabled", new_value)
            end),
        },
    },
    row {
        width = "Fill",
        spacing = theme.spacing.xs,
        visible = util.shown_when(mantle.network, function(network)
            return network.networking_enabled
        end),
        children = {
            radio_tile("wifi", "Wi-Fi", icons.wifi[4], function(network)
                -- Keyed on the association, not `ssid`. A docked laptop's joined radio still has an
                -- address while `ssid` names the cable.
                local ap = util.active_access_point(network)
                return ap and detail_line(network.wifi_ip, (util.band_of(ap))) or ""
            end),
            radio_tile("ethernet", "Ethernet", icons.ethernet, function(network)
                return network.ethernet_enabled
                    and detail_line(network.ethernet_ip, speed_text(network.ethernet_speed)) or ""
            end),
        },
    },
    -- Closed by its button or the next attempt. It yields to the sheet, so one failure never shows twice.
    callout(icons.warning, error_message, {
        visible = computed({ mantle.network, step, error_dismissed }, function(network, current, dismissed)
            return current == "" and not dismissed
                and network ~= nil and network.connect_error ~= nil and network.connecting_ssid == nil
        end),
        trailing = panel_action_icon(icons.close, function()
            error_dismissed:set(true)
        end, { slot = "network-error-dismiss", tint = theme.RED }),
    }),
    -- Typed passwords never reach this VM: `mask_character` plus `secure_submit` keeps keystrokes in
    -- a native buffer and sends a `("network", "connect")` envelope, so `submit = true` is the only
    -- password path. The engine focuses a surface's *sole* secure field and refuses to guess between
    -- two, so the name field is plain; only shown fields are armed, letting each step take the
    -- keyboard while the other is down.
    column {
        width = "Fill",
        spacing = theme.spacing.sm,
        visible = step:map(function(current)
            return current ~= ""
        end),
        children = {
            cell(sheet_title, theme.FG, theme.font.sm, { width = "Fill" }),
            -- `autofocus` rather than a click: `panel_host` turns keyboard `Exclusive` on the same
            -- edge. The draft is stored per keystroke because Next has no other way to read it.
            input {
                visible = during("name"),
                field = textfield {
                    width = "Fill",
                    height = "Fill",
                    autofocus = true,
                    placeholder = "Network name",
                    font_size = theme.font.sm,
                    foreground = theme.FG,
                    on_change = function(typed)
                        ui.hidden_draft:set(typed or "")
                    end,
                    on_submit = submit_hidden_name,
                    -- Escape empties the field and releases the keyboard; take the sheet down too.
                    on_cancel = ui.clear_network_prompts,
                },
            },
            input {
                visible = during("password"),
                field = textfield {
                    width = "Fill",
                    height = "Fill",
                    placeholder = "Password",
                    mask_character = "•",
                    secure_submit = { capability = "network", action = "connect" },
                    on_cancel = ui.cancel_network_join,
                    font_size = theme.font.sm,
                    foreground = theme.FG,
                },
            },
            row {
                spacing = theme.spacing.xs,
                align_v = "Center",
                visible = during("waiting"),
                children = { spinner(during("waiting"), theme.icon.md), cell("Connecting…", theme.DIM, theme.font.xs) },
            },
            -- Under the field, not at the card's top: the error belongs to the network being asked
            -- about. A password step carries one when NetworkManager rejected the last key.
            callout(icons.warning, error_message, {
                visible = computed({ step, mantle.network }, function(current, network)
                    return current == "failed"
                        or (current == "password" and network ~= nil and network.connect_error ~= nil)
                end),
            }),
            row {
                width = "Fill",
                align_h = "End",
                spacing = theme.spacing.sm,
                children = {
                    action_button("Cancel", ui.cancel_network_join, "network-sheet-cancel", { tone = "quiet" }),
                    -- Hidden rather than disabled while the name is empty: `action_button` has no
                    -- disabled tone. Enter does the same for anyone already typing.
                    action_button("Next", submit_hidden_name, "network-sheet-next", {
                        tone = "solid",
                        visible = computed({ step, ui.hidden_draft }, function(current, draft)
                            return current == "name" and util.trim(draft) ~= ""
                        end),
                    }),
                    -- No `on_activate`: its click *is* the field's Enter, the only path a password
                    -- has out of the Renderer.
                    action_button("Connect", nil, "network-sheet-connect",
                        { tone = "solid", submit = true, visible = during("password") }),
                    -- A failed attempt leaves no pending intent, so Retry is a fresh `connect`.
                    action_button("Retry", function()
                        mantle.network:invoke("connect", ui.hidden_ssid:get(), true)
                    end, "network-sheet-retry", { tone = "solid", glyph = icons.warning, visible = during("failed") }),
                },
            },
        },
    },
    -- The sheet replaces the list during a hidden join rather than stacking above it.
    list {
        width = "Fill",
        max_height = rows:map(function(items)
            return util.fit_height(items, theme.panel_list_height, theme.spacing.xs, function(item)
                return item.kind == "header" and theme.section_header_height or theme.control.lg
            end)
        end),
        scroll = scroll("network_aps"),
        spacing = theme.spacing.xs,
        visible = radio_up_and_idle,
        source = rows,
        itemfn = access_point_row,
        key = function(entry)
            return entry.key
        end,
    },
    -- A network broadcasting no SSID is dropped from `available_networks`, so this row stands in for
    -- it and asks for the name. It leaves with the list while the sheet is asking.
    panel_row {
        slot = "network-hidden",
        leading = row {
            width = LEADING_WIDTH,
            align_v = "Center",
            children = { glyph(icons.wifi_hidden, theme.FG, theme.icon.md, { align_v = "Center" }) },
        },
        title = "Hidden network…",
        visible = radio_up_and_idle,
        trailing = glyph(icons.chevron_right, theme.DIM, theme.font.sm, { align_v = "Center" }),
        on_activate = ui.open_hidden_prompt,
    },
    panel_empty_state(
        mantle.network:map(function(network)
            if network == nil then
                return "NetworkManager is not responding"
            elseif not network.networking_enabled then
                return "Turn on networking to see networks"
            elseif not network.wifi_present then
                return "No Wi-Fi adapter found"
            elseif not network.wifi_enabled then
                return "Turn on Wi-Fi to see networks"
            elseif network.scanning then
                return "Looking for networks…"
            end
            return "No networks found"
        end),
        computed({ mantle.network, ui.hidden_join }, function(network, joining)
            return not radio_on(network) or (not joining and #access_points(network) == 0)
        end),
        {
            icon = mantle.network:map(function(network)
                return radio_on(network) and icons.wifi_none or icons.wifi_off
            end)
        }
    ),
}

return { kind = KIND, body = body, scan_while_open = scan_while_open }
