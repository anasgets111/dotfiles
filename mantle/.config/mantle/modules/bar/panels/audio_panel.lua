-- Masthead, output/microphone cards with pickers, and one slider per app stream. Device pickers and
-- the mixer expand on click, tracked by three `state()` signals. The two cards are composite controls
-- (label row, slider, picker); the mixer is a list, so it sits on the panel.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local glyph = require("components.glyph")
local icon_button = require("components.icon_button")
local panel_action_icon = require("components.panel_action_icon")
local panel_header = require("components.panel_header")
local panel_card = require("components.panel_card")
local panel_row = require("components.panel_row")
local slider = require("components.slider")
local tooltip = require("components.tooltip")
local ui_state = require("lib.ui_state")

local tooltips = {}
local mixer_open = state("audio_mixer_open", false)

local function percent(value)
    return value and string.format("%d%%", math.floor(value * 100 + 0.5)) or "--"
end

-- Remove redundant ALSA description words.
local function device_name(device)
    if device == nil then
        return nil
    end
    local name = device.name or ""
    name = name:gsub("%s*[Hh]igh [Dd]efinition [Aa]udio [Cc]ontroller", ""):gsub("%s*H?D? ?[Aa]udio [Cc]ontroller", "")
    name = name:gsub("%s*[Dd]igital [Ss]tereo", ""):gsub("%s*[Aa]nalog [Ss]tereo", "")
    name = name:gsub("%s*%(HDMI%)", " HDMI"):gsub("%s*%(S/PDIF%)", " S/PDIF"):gsub("%s*%(IEC958%)", " S/PDIF")
    name = name:gsub("%s+", " "):match("^%s*(.-)%s*$")
    return name ~= "" and name or device.name
end

---@class AudioControlOpts
---@field name string The slider's state name.
---@field title string
---@field glyph_on string
---@field glyph_off string
---@field volume string The `AudioState` field holding the volume.
---@field muted string The `AudioState` field holding the mute flag.
---@field devices string The `AudioState` device list, for the subtitle, leading glyph and picker.
---@field is_input? boolean
---@field set_volume string The `mantle.audio` action taking one volume.
---@field set_default string The `mantle.audio` action taking one device id.
---@field headroom? boolean Past 100%: a red fill and a marker at 100%.
---@field toggle_mute string The `mantle.audio` action taking nothing.
---@field picker StateSignal<boolean> Whether the device picker is open.
---@field visible? Bound
---@field under? Node[]

---@param opts AudioControlOpts
local function device_picker(opts)
    local devices = mantle.audio:map(function(audio)
        return (audio and audio[opts.devices]) or {}
    end)
    return column {
        width = "Fill",
        spacing = theme.spacing.xs,
        visible = devices:map(function(list)
            return #list > 1
        end),
        children = {
            panel_row {
                slot = "audio-picker-" .. opts.name,
                icon = opts.is_input and icons.mic_on or icons.speaker,
                title = "Choose device",
                expanded = opts.picker,
            },
            list {
                width = "Fill",
                spacing = theme.spacing.xs,
                visible = opts.picker,
                source = devices,
                itemfn = function(device)
                    return panel_row {
                        slot = "audio-device-" .. opts.name .. "-" .. tostring(device.id),
                        icon = util.audio_device_glyph(device, opts.is_input)
                            or (opts.is_input and icons.mic_on or icons.speaker),
                        title = device_name(device) or "?",
                        selected = device.active,
                        trailing = glyph(icons.check, device.active and theme.ACCENT or theme.CLEAR, theme.font.sm),
                        on_activate = function()
                            mantle.audio[opts.set_default](mantle.audio, device.id)
                            opts.picker:set(false)
                        end,
                    }
                end,
                key = function(device)
                    return tostring(device.id)
                end,
            },
        },
    }
end

---@param opts AudioControlOpts
local function audio_control(opts)
    local is_muted = mantle.audio:map(function(audio)
        return audio ~= nil and audio[opts.muted]
    end)
    local function when_muted(muted_value, unmuted_value)
        return is_muted:map(function(muted)
            return muted and muted_value or unmuted_value
        end)
    end
    local mute_glyph = when_muted(opts.glyph_off, opts.glyph_on)
    local tint = when_muted(theme.DIM, theme.ACCENT)
    local leading_glyph = computed({ mantle.audio, mute_glyph }, function(audio, fallback)
        return audio and not audio[opts.muted]
            and util.audio_device_glyph(util.active_device(audio[opts.devices]), opts.is_input) or fallback
    end)
    local held = state("audio_pending_" .. opts.name, -1)
    tooltips[opts.name] = tooltip({
        id = "audio_mute_" .. opts.name .. "_tooltip",
        in_panel = true,
        slot = "audio-mute-" .. opts.name,
        children = { cell(when_muted("Unmute", "Mute"), theme.FG, theme.font.sm) },
    })

    local children = util.concat({
        panel_row {
            icon = leading_glyph,
            icon_color = tint,
            title = util.bold(opts.title),
            subtitle = util.label(mantle.audio, function(audio)
                return device_name(util.active_device(audio[opts.devices])) or "No device"
            end),
            trailing = row {
                spacing = theme.spacing.sm,
                align_v = "Center",
                children = {
                    cell(util.bold(computed({ mantle.audio, held }, function(audio, held_value)
                        return percent(held_value >= 0 and held_value or audio and audio[opts.volume])
                    end)), tint, theme.font.sm, { align_v = "Center" }),
                    icon_button(mute_glyph, function()
                        mantle.audio[opts.toggle_mute](mantle.audio)
                    end, {
                        slot = "audio-mute-" .. opts.name,
                        size = theme.control.md,
                        icon_size = theme.icon.sm,
                        opacity = mantle.audio:map(function(audio)
                            return audio ~= nil and audio[opts.volume] ~= nil and 1 or theme.opacity.disabled
                        end),
                        background = when_muted(theme.GLASS_CONTROL, theme.ACCENT),
                    }),
                },
            },
        },
        slider {
            name = "audio_pending_" .. opts.name,
            signal = mantle.audio,
            read = function(audio)
                return audio[opts.volume]
            end,
            on_commit = function(value)
                mantle.audio[opts.set_volume](mantle.audio, value)
            end,
            pending = held,
            max = opts.headroom and util.MAX_VOLUME or nil,
            split_at = opts.headroom and 1 or nil,
            marker = opts.headroom,
            headroom_color = when_muted(theme.INACTIVE, theme.RED),
            height = theme.audio_slider_height,
            color = when_muted(theme.INACTIVE, theme.ACCENT),
        },
    }, opts.under)
    children[#children + 1] = device_picker(opts)

    return panel_card(children, {
        width = "Fill",
        visible = opts.visible,
        spacing = theme.spacing.sm,
        padding = theme.spacing.md,
    })
end

local function stream_row(app)
    local applications = mantle.applications:get()
    local entry = util.app_entry(applications, app.binary)
        or util.app_entry(applications, app.process_name)
        or util.app_entry(applications, app.name)
    local name = entry and entry.name or app.name or app.process_name or "Unknown"
    local icon_name = entry and entry.icon or app.icon
    local leading = icon_name and icon { name = icon_name, size = theme.icon.md, align_v = "Center" }
        or glyph(app.recording and icons.mic_on or icons.music_note, theme.FG, theme.icon.md, { align_v = "Center" })
    local tint = app.muted and theme.DIM or theme.ACCENT
    return column {
        width = "Fill",
        spacing = theme.spacing.xs,
        children = {
            panel_row {
                leading = leading,
                title = name,
                height = theme.control.md,
                opacity = (app.muted or app.volume == nil) and theme.opacity.muted or nil,
                trailing = row {
                    spacing = theme.spacing.sm,
                    align_v = "Center",
                    children = {
                        glyph(icons.mic_on, theme.DIM, theme.icon.sm,
                            { align_v = "Center", visible = app.recording and icon_name ~= nil }),
                        cell(percent(app.volume), tint, theme.font.sm, { align_v = "Center" }),
                        panel_action_icon(app.muted and icons.vol_muted or icons.vol_high, app.volume and function()
                            mantle.audio:set_app_muted(app.id, not app.muted)
                        end, { slot = "audio-stream-mute-" .. tostring(app.id), tint = tint }),
                    },
                },
            },
            slider {
                name = "audio_pending_app_" .. tostring(app.id),
                signal = mantle.audio,
                read = function(audio)
                    for _, stream in ipairs(audio.apps or {}) do
                        if stream.id == app.id then
                            return stream.volume
                        end
                    end
                end,
                on_commit = function(value)
                    mantle.audio:set_app_volume(app.id, value)
                end,
                color = tint,
            },
        },
    }
end

-- A stream is its row plus its track, so the list is cut between streams, not through a slider.
local STREAM_HEIGHT = theme.control.md + theme.spacing.xs + theme.slider_height

-- speech-dispatcher's `sd_*` output modules hold idle streams open forever.
local streams = mantle.audio:map(function(audio)
    local shown = {}
    for _, app in ipairs((audio and audio.apps) or {}) do
        if not (app.binary or ""):match("^sd_") then
            shown[#shown + 1] = app
        end
    end
    return shown
end)

local body = {
    panel_header {
        title = "Audio",
        icon = mantle.audio:map(util.volume_glyph),
        active = mantle.audio:map(function(audio)
            return audio ~= nil and audio.volume ~= nil and not audio.muted
        end),
        subtitle = util.label(mantle.audio, function(audio)
            if audio.muted then
                return "Muted"
            end
            local device = device_name(util.active_device(audio.sinks))
            return percent(audio.volume) .. (device and " · " .. device or "")
        end),
    },
    audio_control {
        name = "output",
        title = "Output",
        glyph_on = icons.vol_high,
        glyph_off = icons.vol_muted,
        volume = "volume",
        muted = "muted",
        devices = "sinks",
        set_volume = "set_volume",
        set_default = "set_default_sink",
        toggle_mute = "toggle_mute",
        headroom = true,
        picker = ui_state.audio_output_picker,
        under = {
            row {
                width = "Fill",
                spacing = theme.spacing.sm,
                align_v = "Center",
                visible = util.shown_when(mantle.audio, function(audio)
                    return audio.balance ~= nil
                end),
                children = {
                    cell("L", theme.DIM, theme.font.xs),
                    -- Accent headroom keeps the fill one color past the center.
                    slider {
                        name = "audio_pending_balance",
                        signal = mantle.audio,
                        read = function(audio)
                            return audio.balance and audio.balance + 1
                        end,
                        on_commit = function(value)
                            mantle.audio:set_balance(value - 1)
                        end,
                        max = 2,
                        split_at = 1,
                        marker = true,
                        headroom_color = theme.ACCENT,
                    },
                    cell("R", theme.DIM, theme.font.xs),
                },
            },
        },
    },
    audio_control {
        name = "input",
        title = "Microphone",
        glyph_on = icons.mic_on,
        glyph_off = icons.mic_off,
        volume = "source_volume",
        muted = "source_muted",
        devices = "sources",
        is_input = true,
        set_volume = "set_source_volume",
        set_default = "set_default_source",
        toggle_mute = "toggle_source_mute",
        picker = ui_state.audio_input_picker,
        visible = util.shown_when(mantle.audio, function(audio)
            return util.active_device(audio.sources) ~= nil
        end),
    },
    -- Flat, like the device pickers: a disclosure row and its list, not a third card.
    column {
        width = "Fill",
        spacing = theme.spacing.xs,
        visible = streams:map(function(list)
            return #list > 0
        end),
        children = {
            panel_row {
                slot = "audio-mixer",
                icon = icons.mixer,
                title = "Application mixer",
                subtitle = util.label(streams, function(list)
                    return string.format("%d active", #list)
                end),
                expanded = mixer_open,
            },
            list {
                width = "Fill",
                max_height = streams:map(function(list)
                    return util.fit_height(list, theme.panel_list_height, theme.spacing.sm, function()
                        return STREAM_HEIGHT
                    end)
                end),
                scroll = scroll("audio_mixer"),
                spacing = theme.spacing.sm,
                visible = mixer_open,
                source = streams,
                itemfn = stream_row,
                key = function(app)
                    return tostring(app.id)
                end,
            },
        },
    },
}

return { kind = "audio", body = body, output_tooltip = tooltips.output, input_tooltip = tooltips.input }
