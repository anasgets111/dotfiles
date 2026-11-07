-- The Output and Microphone cards. The device name under each title opens one list: the current
-- devices, the profiles that would make another (Speakers, TV / Monitor) and Bluetooth headsets
-- whose card plays nothing yet.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local audio_lib = require("lib.audio")
local cell = require("components.cell")
local panel_card = require("components.panel_card")
local reveal = require("components.reveal")
local section_list = require("components.section_list")
local slider = require("components.slider")
local tooltip = require("components.tooltip")
local rows = require("modules.bar.panels.audio.rows")
local advanced = require("modules.bar.panels.audio.advanced")
local ui_state = require("lib.ui_state")

-- A profile switch makes its device a moment later; the device it makes becomes the default once.
-- One pending switch at a time, dropped when its device arrives or after 5 s, so a device that
-- never comes, or one another mixer moves off, is not chased.
local pending, pending_timer

local function expect(devices, card, suffix)
    pending = { devices = devices, card = card, suffix = suffix }
    if pending_timer then
        pending_timer:cancel()
    end
    pending_timer = timer(5000, function() pending = nil end)
end

mantle.audio:on_change(function(audio)
    local want = pending
    if want == nil then
        return
    end
    local device = util.find(audio[want.devices], function(device)
        return device.card == want.card
            and (want.suffix == nil or (device.node_name or ""):sub(- #want.suffix - 1) == "." .. want.suffix)
    end)
    if device == nil then
        return
    end
    pending = nil
    pending_timer:cancel()
    if device.active then
        return
    elseif want.devices == "sinks" then
        mantle.audio:set_default_sink(device.id)
    else
        mantle.audio:set_default_source(device.id)
    end
end)

local function device_icon(device, is_input)
    return audio_lib.audio_device_glyph(device, is_input) or (is_input and icons.mic or icons.speaker)
end

---@class AudioControlOpts
---@field direction table An `audio_lib.DIRECTIONS` entry.
---@field name string State and slot prefix.
---@field title string
---@field headroom? boolean Up to `audio_lib.MAX_VOLUME`, the boost colour past a tick at 100%.
---@field chip? Node Before the readout.
---@field note? Signal<string> A third line under the device name, hidden while `""`.

-- The live peak bar under each slider: linear percent of full scale, independent of the volume.
local METER_HEIGHT = 3

---@param opts AudioControlOpts
local function audio_control(opts)
    local direction, is_input = opts.direction, opts.direction.is_input
    local picker = rows.open_picker:map(function(key) return key == opts.name end)
    -- The default device, or an empty table before one exists.
    local function active(audio)
        return audio_lib.active_device(audio[direction.devices]) or {}
    end
    -- Handlers act on the default at click time, not the one the card was built with.
    local function current()
        return audio_lib.active_device((mantle.audio:get() or {})[direction.devices])
    end

    local options = mantle.audio:map(function(audio)
        local out = {}
        for _, device in ipairs(audio[direction.devices]) do
            out[#out + 1] = {
                kind = "device",
                id = device.id,
                title = audio_lib.device_name(device) or "?",
                icon = device_icon(device, is_input),
                active = device.active,
                key = opts.name .. "-device-" .. device.id,
                height = rows.OPTION_HEIGHT,
            }
        end
        for _, creator in ipairs(audio_lib.creators(audio, direction)) do
            out[#out + 1] = util.with(creator, "kind", "profile")
            out[#out].key = opts.name .. "-profile-" .. creator.card .. "-" .. creator.index
            out[#out].height = rows.OPTION_HEIGHT
        end
        return out
    end, {})

    local choices = section_list(options, "audio_options_" .. opts.name, function(item)
        return rows.option_row(item, function()
            if item.kind == "device" then
                if is_input then
                    mantle.audio:set_default_source(item.id)
                else
                    mantle.audio:set_default_sink(item.id)
                end
            else
                expect(direction.devices, item.card, item.suffix)
                mantle.audio:set_card_profile(item.card, item.index)
            end
            rows.open_picker:set("")
        end)
    end)

    local is_muted = mantle.audio:map(function(audio)
        return active(audio).muted
    end, false)
    local mute_glyph = is_muted:map(function(muted) return rows.mute_glyph(muted, is_input) end)
    local tint = util.choose(is_muted, theme.DIM, theme.FG)
    local leading_glyph = computed({ mantle.audio, mute_glyph }, function(audio, fallback)
        return not active(audio).muted and audio_lib.audio_device_glyph(active(audio), is_input) or fallback
    end, rows.mute_glyph(false, is_input))
    local held = state("audio_pending_" .. opts.name, -1)
    local max = opts.headroom and audio_lib.MAX_VOLUME or 100
    local mute_tooltip = tooltip({
        id = "audio_mute_" .. opts.name .. "_tooltip",
        in_panel = true,
        slot = "audio-mute-" .. opts.name,
        children = { cell(util.choose(is_muted, "Unmute", "Mute"), theme.FG, theme.font.sm) },
    })

    -- The device name is the picker's button once there is a second choice.
    local lines = { rows.picker_button {
        slot = "audio-picker-" .. opts.name,
        label = util.label(mantle.audio, function(audio)
            return audio_lib.device_name(audio_lib.active_device(audio[direction.devices])) or "No device"
        end),
        key = opts.name,
        choosable = options:map(function(items) return #items > 1 end),
    } }
    if opts.note then
        lines[#lines + 1] = cell(opts.note, theme.DIM, theme.font.xs, {
            width = "fill",
            visible = opts.note:map(function(note) return note ~= "" end),
        })
    end
    local header = rows.header {
        leading = rows.glyph(leading_glyph, tint),
        title = util.bold(opts.title),
        lines = lines,
        trailing = rows.trailing({ opts.chip }, rows.percent_cell(computed({ mantle.audio, held },
            function(audio, value) return rows.percent(value >= 0 and value or active(audio).volume) end,
            "--"), tint, true), rows.mute_button(mute_glyph, is_input, function()
            local device = current()
            if device then
                mantle.audio:toggle_mute(device.id)
            end
        end, {
            slot = "audio-mute-" .. opts.name,
            disabled = mantle.audio:map(function(audio)
                return active(audio).volume == nil
            end, true),
        })),
    }

    local track = column {
        width = "fill",
        spacing = theme.spacing.xs,
        margin = rows.TRACK_MARGIN,
        opacity = util.choose(is_muted, theme.opacity.muted, 1),
        animate = { opacity = theme.animation_ms },
        children = { slider {
            name = "audio_pending_" .. opts.name,
            accessible_name = opts.title .. " volume",
            signal = mantle.audio,
            read = function(audio)
                return active(audio).volume
            end,
            on_commit = function(value)
                local device = current()
                if device then
                    mantle.audio:set_volume(device.id, value)
                end
            end,
            pending = held,
            max = max,
            steps = max / 5,
            split_at = opts.headroom and 100 or nil,
            marker = opts.headroom,
            headroom_color = util.choose(is_muted, theme.INACTIVE, theme.RED),
            height = theme.audio_slider_height,
            color = util.choose(is_muted, theme.INACTIVE, theme.ACCENT),
        }, rect {
            width = "fill",
            height = METER_HEIGHT,
            radius = METER_HEIGHT / 2,
            background = theme.SURFACE,
            children = { rect {
                width = computed({ mantle.audio_levels, mantle.audio }, function(levels, audio)
                    local id = active(audio).id
                    local level = levels and util.find(levels.levels, function(found) return found.id == id end)
                    return string.format("%d%%", math.floor((level and level.peak or 0) + 0.5))
                end, "0%"),
                height = "fill",
                radius = METER_HEIGHT / 2,
                background = util.choose(is_muted, theme.INACTIVE, theme.ACCENT),
                animate = { width = 66 },
            } },
        } },
    }
    -- The list opens under the slider, so the slider never moves.
    local card = panel_card({
        reveal(column { width = "fill", spacing = rows.GRID.track_gap, children = { header, track } },
            choices, picker, { slot = "audio-picker-" .. opts.name }),
    }, {
        width = "fill",
        visible = mantle.audio:map(function(audio)
            return #audio[direction.devices] > 0
        end, false),
        spacing = rows.GRID.track_gap,
        padding = rows.GRID.pad,
    })
    return card, mute_tooltip
end

-- Off-centre balance shows as a chip that opens Advanced, where its slider lives.
local chip_hover = hover("audio-balance-chip")
local balance_chip = rect {
    hover = chip_hover,
    visible = mantle.audio:map(function(audio)
        return math.abs((audio_lib.default_sink(audio) or {}).balance or 0) > 0.01
    end, false),
    on_click = function(_, mouse_button)
        if mouse_button == "left" then
            advanced.open:set(true)
        end
    end,
    radius = theme.radius.sm,
    padding = { left = theme.spacing.xs, right = theme.spacing.xs },
    background = util.choose(chip_hover, theme.ACCENT_LIGHT, theme.ACCENT_SUBTLE),
    animate = { background = theme.animation_ms },
    children = { cell("L/R", theme.ACCENT, theme.font.xs, { align_v = "center" }) },
}

local output, output_tooltip = audio_control {
    direction = audio_lib.DIRECTIONS[1],
    name = "output",
    title = "Output",
    headroom = true,
    chip = balance_chip,
}

-- The privacy indicator's microphone consumers, named.
local input, input_tooltip = audio_control {
    direction = audio_lib.DIRECTIONS[2],
    name = "input",
    title = "Microphone",
    note = mantle.privacy:map(function(privacy)
        return audio_lib.used_by(privacy.microphone_users) or ""
    end, ""),
}

-- Meters run only while the audio panel is open, on the default output and input. The key changes
-- when either default does; a reload keeps the old list, so it is sent once at load too.
local metered = computed({ ui_state.panel_showing("audio"), mantle.audio }, function(open, audio)
    local ids = {}
    for _, direction in ipairs(open and audio and audio_lib.DIRECTIONS or {}) do
        local device = audio_lib.active_device(audio[direction.devices])
        ids[#ids + 1] = device and device.id or nil
    end
    return table.concat(ids, ",")
end, "")
local function meter(key)
    local ids = {}
    for id in key:gmatch("%d+") do
        ids[#ids + 1] = tonumber(id)
    end
    mantle.audio:set_level_meters(ids)
end
metered:on_change(meter)
meter(metered:get())

return {
    output = output,
    input = input,
    tooltips = { output_tooltip, input_tooltip },
}
