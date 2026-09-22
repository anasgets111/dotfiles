-- Masthead, two radio tiles, and access points with the joined one first.
--
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
local ui = require("lib.ui_state")

local KIND = "network"
local SCROLL = scroll("network_aps")

-- Payload order is connected, saved, then descending raw signal. The list re-sorts by tier.
local function access_points(n)
    return (n and n.available_networks) or {}
end

-- A tile's second line.
local function detail_line(first, second)
    return first and second and (first .. " · " .. second) or first or second or ""
end

-- NetworkManager reports Mb/s, with `0` for unknown.
local function speed_text(mbps)
    return mbps >= 1000 and string.format("%g Gb/s", mbps / 1000) or mbps > 0 and string.format("%d Mb/s", mbps) or nil
end

local function radio_on(n)
    return n ~= nil and n.networking_enabled and n.wifi_present and n.wifi_enabled
end

-- Header subtitle, in priority order: an off stack speaks before its radios. No payload means
-- NetworkManager never answered.
local function state_line(n)
    if n == nil then
        return "Unavailable"
    end
    if not n.networking_enabled then
        return "Off"
    end
    if n.connecting_ssid then
        return "Connecting to " .. n.connecting_ssid
    end
    if n.ssid == "Ethernet" then
        return "Ethernet connected"
    end
    if n.ssid then
        return n.ssid
    end
    if not n.wifi_enabled then
        return "Wi-Fi off"
    end
    return n.scanning and "Scanning…" or "Not connected"
end

local function header_glyph(n)
    if n == nil or not n.networking_enabled then
        return icons.wifi_off
    end
    if n.ssid == "Ethernet" then
        return icons.ethernet
    end
    return n.wifi_enabled and icons.wifi[4] or icons.wifi_off
end

-- The scanned list and the hidden-network row share one condition.
local radio_up_and_idle = computed({ mantle.network, ui.hidden_join }, function(n, joining)
    return radio_on(n) and not joining
end)

-- `connect_error` stays until the next attempt, so the dismissal is view state.
local error_dismissed = state("network_error_dismissed", false)

mantle.network:on_change(function(n, previous)
    if previous == nil then
        return
    end
    if n.connecting_ssid ~= nil and previous.connecting_ssid == nil then
        error_dismissed:set(false)
    elseif previous.connecting_ssid ~= nil and n.connecting_ssid == nil and n.connect_error == nil then
        -- An aborted join also clears `connecting_ssid` with no error, so success is the radio now
        -- holding that network, not the spinner stopping.
        local joined = util.active_access_point(n)
        local succeeded = joined ~= nil and joined.ssid == previous.connecting_ssid
        if succeeded and ui.panel_open:get() and ui.panel_kind:get() == KIND then
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

local rows = mantle.network:map(function(n)
    local connecting = n and n.connecting_ssid
    local sections = { saved = {}, available = {} }
    for _, ap in ipairs(access_points(n)) do
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

local function access_point_row(entry)
    if entry.kind == "header" then
        return section_header(entry.label)
    end
    local ap = entry.ap
    local band, color = util.band_of(ap)

    local leading = { glyph(icons.wifi[util.signal_tier(ap.strength)], color, theme.icon.md, { align_v = "Center" }) }
    if band then
        leading[#leading + 1] = cell(util.bold(band), color, theme.font.xs, { align_v = "End" })
    end

    local trailing = {}
    if ap.active then
        trailing[#trailing + 1] = panel_action_icon(icons.disconnect, function()
            mantle.network:invoke("disconnect_wifi")
        end, { slot = "network-disconnect-" .. tostring(ap.ssid), tint = theme.RED })
    end
    if ap.saved or ap.active then
        trailing[#trailing + 1] = panel_action_icon(icons.trash, function()
            mantle.network:invoke("forget", ap.ssid)
        end, { slot = "network-forget-" .. tostring(ap.ssid), tint = theme.RED })
    end
    if ap.secure then
        trailing[#trailing + 1] = glyph(icons.lock, theme.DIM, theme.font.xs, { align_v = "Center" })
    end

    local clickable = not ap.active and not entry.blocked
    return panel_row {
        slot = "network-ap-" .. tostring(ap.ssid),
        leading = row { align_v = "Center", children = leading },
        title = ap.ssid or "?",
        subtitle = entry.connecting and "Connecting…" or nil,
        selected = ap.active,
        opacity = entry.blocked and theme.opacity.disabled or nil,
        trailing = row { spacing = theme.spacing.xs, align_v = "Center", children = trailing },
        on_activate = clickable and function()
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
local sheet_title = util.bold(computed({ step, ui.hidden_ssid, mantle.network }, function(current, name, n)
    local target = (n and n.password_ssid) or name
    if current == "name" then
        return "Hidden network"
    elseif current == "waiting" then
        return string.format("Connecting to “%s”", target)
    elseif current == "failed" then
        return string.format("Could not join “%s”", target)
    end
    return string.format("Connect to “%s”", target)
end))

local error_message = util.label(mantle.network, function(n)
    return n.connect_error and n.connect_error.message or ""
end)

-- Enter, or Next. `hidden = true` makes the Supervisor write `802-11-wireless.hidden` and treat the
-- target as secured, since a network it cannot see is one it cannot ask about: either a saved
-- profile answers or `password_ssid` comes back and this sheet asks for the rest. The name is kept
-- for the title and Retry. Submitting nothing is not an attempt to join "".
local function submit_hidden_name()
    local name = ui.hidden_draft:get():match("^%s*(.-)%s*$")
    if name == "" then
        return
    end
    ui.hidden_ssid:set(name)
    mantle.network:invoke("connect", name, true)
end

-- A failed attempt leaves no pending intent, so Retry is a fresh `connect`, not a resubmission.
local function retry_hidden()
    mantle.network:invoke("connect", ui.hidden_ssid:get(), true)
end

-- Called by the indicator on every toggle: an open scans now and every `RESCAN_MS` after, a close
-- cancels the chain. Cancelling first keeps a quick close and reopen from running two.
local RESCAN_MS = 10000
local rescan = nil

local function scan_while_open()
    if rescan ~= nil then
        rescan:cancel()
    end
    if not (ui.panel_open:get() and ui.panel_kind:get() == KIND) then
        return
    end
    if radio_on(mantle.network:get()) then
        mantle.network:invoke("scan")
    end
    rescan = timer(RESCAN_MS, scan_while_open)
end

local body = {
    panel_header {
        title = "Network",
        icon = mantle.network:map(header_glyph),
        active = mantle.network:map(function(n)
            return n ~= nil and n.networking_enabled
        end),
        subtitle = mantle.network:map(state_line),
        trailing = {
            -- Rescan swaps for a spinner while scanning; `scanning` flips on click.
            icon_button(icons.refresh, function()
                mantle.network:invoke("scan")
            end, {
                slot = "network-rescan",
                size = theme.control.sm,
                icon_size = theme.icon.sm,
                visible = util.shown_when(mantle.network, function(n)
                    return radio_on(n) and not n.scanning
                end),
            }),
            spinner(util.shown_when(mantle.network, function(n)
                return n.scanning
            end), theme.icon.md),
            -- Controls the whole stack; off hides the tiles.
            toggle(mantle.network, function(n)
                return n.networking_enabled
            end, function(new_value)
                mantle.network:invoke("set_networking_enabled", new_value)
            end),
        },
    },
    -- Two radio tiles, each with its address under the label; Wi-Fi adds the joined band.
    row {
        width = "Fill",
        spacing = theme.spacing.xs,
        visible = util.shown_when(mantle.network, function(n)
            return n.networking_enabled
        end),
        children = {
            panel_toggle_card {
                slot = "network-wifi-tile",
                icon = icons.wifi[4],
                label = util.label(mantle.network, function(n)
                    return n.wifi_present and "Wi-Fi" or "No Wi-Fi"
                end),
                disabled = util.shown_when(mantle.network, function(n)
                    return not n.wifi_present
                end),
                -- Keyed on the association, not `ssid`. A docked laptop's joined radio still has an
                -- address while `ssid` names the cable.
                detail = util.label(mantle.network, function(n)
                    local ap = util.active_access_point(n)
                    if ap == nil then
                        return ""
                    end
                    return detail_line(n.wifi_ip, (util.band_of(ap)))
                end),
                signal = mantle.network,
                read = function(n)
                    return n.wifi_enabled
                end,
                on_change = function(new_value)
                    mantle.network:invoke("set_wifi_enabled", new_value)
                end,
            },
            panel_toggle_card {
                slot = "network-ethernet-tile",
                icon = icons.ethernet,
                label = util.label(mantle.network, function(n)
                    return n.ethernet_present and "Ethernet" or "No Ethernet"
                end),
                disabled = util.shown_when(mantle.network, function(n)
                    return not n.ethernet_present
                end),
                detail = util.label(mantle.network, function(n)
                    return n.ethernet_enabled and detail_line(n.ethernet_ip, speed_text(n.ethernet_speed)) or ""
                end),
                signal = mantle.network,
                read = function(n)
                    return n.ethernet_enabled
                end,
                on_change = function(new_value)
                    mantle.network:invoke("set_ethernet_enabled", new_value)
                end,
            },
        },
    },
    -- Error card, red on a red-tinted ground, closed by its own button or the next attempt. It
    -- yields to the sheet, preventing two copies reading as two failures.
    row {
        width = "Fill",
        spacing = theme.spacing.sm,
        align_v = "Center",
        padding = theme.spacing.sm,
        radius = theme.radius.md,
        background = theme.ALERT_BG,
        visible = computed({ mantle.network, step, error_dismissed }, function(n, current, dismissed)
            return current == ""
                and not dismissed
                and n ~= nil
                and n.connect_error ~= nil
                and n.connecting_ssid == nil
        end),
        children = {
            glyph(icons.warning, theme.RED, theme.icon.sm, { align_v = "Center" }),
            cell(error_message, theme.RED, theme.font.sm, { width = "Fill", wrap = "Word", max_lines = 2 }),
            panel_action_icon(icons.close, function()
                error_dismissed:set(true)
            end, { slot = "network-error-dismiss", tint = theme.RED }),
        },
    },
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
                    mask_character = "*",
                    secure_submit = { capability = "network", action = "connect" },
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
            row {
                width = "Fill",
                spacing = theme.spacing.xs,
                align_v = "Center",
                visible = computed({ step, mantle.network }, function(current, n)
                    return current == "failed" or (current == "password" and n ~= nil and n.connect_error ~= nil)
                end),
                children = {
                    glyph(icons.warning, theme.RED, theme.icon.sm, { align_v = "Center" }),
                    cell(error_message, theme.RED, theme.font.xs, { width = "Fill", wrap = "Word", max_lines = 2 }),
                },
            },
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
                            return current == "name" and draft:match("^%s*(.-)%s*$") ~= ""
                        end),
                    }),
                    -- No `on_activate`: its click *is* the field's Enter, the only path a password
                    -- has out of the Renderer.
                    action_button("Connect", nil, "network-sheet-connect", {
                        tone = "solid",
                        submit = true,
                        visible = during("password"),
                    }),
                    action_button("Retry", retry_hidden, "network-sheet-retry", {
                        tone = "solid",
                        glyph = icons.warning,
                        visible = during("failed"),
                    }),
                },
            },
        },
    },
    -- Rows up to the cap, then a scrolling viewport. The sheet replaces it during a hidden join
    -- rather than stacking above it.
    list {
        width = "Fill",
        max_height = theme.panel_list_height,
        scroll = SCROLL,
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
        icon = icons.wifi_hidden,
        title = "Hidden network…",
        visible = radio_up_and_idle,
        trailing = glyph(icons.chevron_right, theme.DIM, theme.font.sm, { align_v = "Center" }),
        on_activate = ui.open_hidden_prompt,
    },
    panel_empty_state(
        mantle.network:map(function(n)
            if n == nil then
                return "Network unavailable"
            elseif not n.networking_enabled then
                return "Networking off"
            elseif not n.wifi_present then
                return "No Wi-Fi adapter"
            elseif not n.wifi_enabled then
                return "Wi-Fi off"
            elseif n.scanning then
                return "Scanning…"
            end
            return "No networks found"
        end),
        computed({ mantle.network, ui.hidden_join }, function(n, joining)
            return not radio_on(n) or (not joining and #access_points(n) == 0)
        end),
        {
            icon = mantle.network:map(function(n)
                return radio_on(n) and icons.wifi_none or icons.wifi_off
            end),
        }
    ),
}

return { kind = KIND, body = body, scan_while_open = scan_while_open }
