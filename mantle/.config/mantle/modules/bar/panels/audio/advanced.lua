-- The collapsed "Advanced" disclosure: balance, one row per card for every profile (surround
-- layouts, Bluetooth codecs) and port, and the devices that are not the default.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local audio_lib = require("lib.audio")
local cell = require("components.cell")
local glyph = require("components.glyph")
local panel_action_icon = require("components.panel_action_icon")
local panel_card = require("components.panel_card")
local panel_row = require("components.panel_row")
local section_header = require("components.section_header")
local section_list = require("components.section_list")
local slider = require("components.slider")
local disclosure = require("lib.disclosure")
local rows = require("modules.bar.panels.audio.rows")

local open = disclosure.state("audio_advanced_open", false)
-- The `cards[].device` whose choices are open, or `-1`. One card opens at a time.
local card_for = disclosure.state("audio_card_for", -1)

local PORT_TITLES = { output = "Output port", input = "Input port" }

local card_rows = computed({ mantle.audio, card_for }, function(audio, open_for)
    local out = {}
    local function add_choices(card, what, choices)
        for _, choice in ipairs(choices) do
            out[#out + 1] = {
                kind = "choice",
                what = what,
                card = card.device,
                index = choice.index,
                title = choice.label,
                icon = choice.icon or audio_lib.profile_icon(choice.profile),
                active = choice.active,
                available = choice.available,
                key = what .. "-" .. card.device .. "-" .. choice.index,
                height = rows.OPTION_HEIGHT,
            }
        end
    end
    for _, card in ipairs(audio.cards) do
        local profiles = audio_lib.profile_choices(card)
        local ports = {}
        for _, direction in ipairs(audio_lib.DIRECTIONS) do
            local choices = audio_lib.port_choices(card, direction)
            if #choices > 1 then
                ports[#ports + 1] = { title = PORT_TITLES[direction.port], key = direction.port, choices = choices }
            end
        end
        if #profiles > 1 or #ports > 0 then
            local active = util.find(card.profiles, function(profile) return profile.index == card.active end)
            local expanded = open_for == card.device
            out[#out + 1] = {
                kind = "card",
                card = card.device,
                title = audio_lib.device_name({ name = card.name }),
                value = active and audio_lib.profile_label(active) or "--",
                icon = card.mac and icons.bt_on or icons.speaker,
                open = expanded,
                key = "card-" .. card.device,
            }
            if expanded then
                add_choices(card, "profile", #profiles > 1 and profiles or {})
                for _, port in ipairs(ports) do
                    out[#out + 1] = {
                        kind = "header", label = port.title, key = "header-" .. port.key .. "-" .. card.device,
                    }
                    add_choices(card, "port", port.choices)
                end
            end
        end
    end
    for _, direction in ipairs(audio_lib.DIRECTIONS) do
        local others = util.filter(audio[direction.devices], function(device) return not device.active end)
        if #others > 0 then
            out[#out + 1] = { kind = "header", label = direction.others, key = "header-" .. direction.devices }
        end
        for _, device in ipairs(others) do
            out[#out + 1] = {
                kind = "device",
                device = device,
                is_input = direction.is_input,
                key = direction.devices .. "-" .. device.id,
                height = rows.LEVEL_HEIGHT,
            }
        end
    end
    return out
end, {})

local function device_row(device, is_input)
    local devices = is_input and "sources" or "sinks"
    local key = devices .. "_" .. tostring(device.id)
    return rows.level_row {
        key = key,
        leading = rows.glyph(audio_lib.audio_device_glyph(device, is_input) or (is_input and icons.mic or icons.speaker)),
        title = audio_lib.device_name(device) or "?",
        level = device,
        is_input = is_input,
        headroom = not is_input,
        read = function(audio)
            local found = util.find(audio[devices], function(candidate) return candidate.id == device.id end)
            return found and found.volume
        end,
        set_volume = function(value) mantle.audio:set_volume(device.id, value) end,
        set_muted = function(muted) mantle.audio:set_muted(device.id, muted) end,
        badge = panel_action_icon(icons.make_default, function()
            if is_input then
                mantle.audio:set_default_source(device.id)
            else
                mantle.audio:set_default_sink(device.id)
            end
        end, { slot = "audio-make-default-" .. key }),
    }
end

local function card_row(item)
    if item.kind == "header" then
        return section_header(item.label)
    elseif item.kind == "device" then
        return device_row(item.device, item.is_input)
    elseif item.kind == "choice" then
        return rows.option_row(item, function()
            if item.what == "profile" then
                mantle.audio:set_card_profile(item.card, item.index)
            else
                mantle.audio:set_port(item.card, item.index)
            end
            card_for:set(-1)
        end)
    end
    return panel_row {
        slot = "audio-card-" .. item.card,
        leading = rows.icon_column(rows.glyph(item.icon)),
        title = item.title,
        trailing = row {
            spacing = rows.GRID.gap,
            align_v = "center",
            children = {
                cell(item.value, theme.DIM, theme.font.sm, { align_v = "center" }),
                glyph(item.open and icons.chevron_down or icons.chevron_right, theme.DIM, theme.icon.sm,
                    { align_v = "center" }),
            },
        },
        on_activate = function()
            card_for:set(card_for:get() == item.card and -1 or item.card)
        end,
    }
end

local has_balance = mantle.audio:map(function(audio)
    return (audio_lib.default_sink(audio) or {}).balance ~= nil
end, false)

local function balance_of(audio)
    return (audio_lib.default_sink(audio) or {}).balance
end

-- "Centre", or the louder side and how far: "L 20%".
local function balance_label(balance)
    if balance == nil then
        return "--"
    elseif math.abs(balance) < 0.01 then
        return "Centre"
    end
    return string.format("%s %d%%", balance < 0 and "L" or "R", math.floor(math.abs(balance) * 100 + 0.5))
end

-- The default output's balance, laid out like every level row: title and value, then a slider on
-- the shared edges with its ends named under it. The fill grows from the centre tick, so centred
-- shows no fill.
local balance_row = column {
    width = "fill",
    spacing = rows.GRID.track_gap,
    visible = has_balance,
    children = {
        rows.header {
            title = "Balance",
            trailing = { cell(mantle.audio:map(function(audio) return balance_label(balance_of(audio)) end, "--"),
                theme.DIM, theme.font.sm, { align_v = "center" }) },
        },
        column {
            width = "fill",
            margin = rows.TRACK_MARGIN,
            children = { slider {
                name = "audio_pending_balance",
                accessible_name = "Balance",
                signal = mantle.audio,
                read = function(audio)
                    local balance = balance_of(audio)
                    return balance and balance + 1
                end,
                on_commit = function(value)
                    local sink = audio_lib.default_sink(mantle.audio:get())
                    if sink then
                        mantle.audio:set_balance(sink.id, value - 1)
                    end
                end,
                max = 2,
                origin = 1,
                marker = true,
            } },
        },
        row {
            width = "fill",
            margin = rows.TRACK_MARGIN,
            children = {
                cell("L", theme.DIM, theme.font.xs, { width = "fill" }),
                cell("R", theme.DIM, theme.font.xs),
            },
        },
    },
}

return {
    open = open,
    -- One card, collapsed row included, on the shared grid; hidden while it would be empty.
    body = panel_card({
        panel_row {
            slot = "audio-advanced",
            height = rows.GRID.row_height,
            leading = rows.icon_column(rows.glyph(icons.settings)),
            title = "Advanced",
            expanded = open,
            animate_details = true,
            details = column {
                width = "fill",
                spacing = theme.spacing.xs,
                children = { balance_row, section_list(card_rows, "audio_cards", card_row) },
            },
        },
    }, {
        width = "fill",
        padding = rows.GRID.pad,
        visible = computed({ has_balance, card_rows }, function(balance, items)
            return balance or #items > 0
        end, false),
    }),
}
