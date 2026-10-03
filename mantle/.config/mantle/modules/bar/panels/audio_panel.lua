-- Output and microphone rows open their device lists above the sliders. App streams stay flat.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local glyph = require("components.glyph")
local panel_action_icon = require("components.panel_action_icon")
local panel_header = require("components.panel_header")
local panel_card = require("components.panel_card")
local panel_row = require("components.panel_row")
local slider = require("components.slider")
local tooltip = require("components.tooltip")
local disclosure = require("lib.disclosure")

local tooltips = {}
local mixer_open = disclosure.state("audio_mixer_open", false)
local TRACK_INSET = theme.spacing.sm * 2 + theme.icon.md

local function percent(value)
    return value and string.format("%d%%", math.floor(value + 0.5)) or "--"
end

---@class AudioControlOpts
---@field name string The slider's state name.
---@field title string
---@field volume string The `AudioState` field holding the volume.
---@field muted string The `AudioState` field holding the mute flag.
---@field devices string The `AudioState` device list, for the subtitle, leading glyph and picker.
---@field is_input? boolean
---@field set_volume string The `mantle.audio` action taking one volume.
---@field set_default string The `mantle.audio` action taking one device id.
---@field headroom? boolean Past 100%: a red fill and a marker at 100%.
---@field toggle_mute string The `mantle.audio` action taking nothing.
---@field visible? Bound
---@field under? Node[]

---@param opts AudioControlOpts
local function audio_control(opts)
    local picker = disclosure.state("audio_" .. opts.name .. "_picker", false)
    local devices = mantle.audio:map(function(audio)
        return (audio and audio[opts.devices]) or {}
    end)
    local choices = list {
        width = "Fill",
        spacing = theme.spacing.xs,
        max_height = devices:map(function(items)
            return util.fit_height(items, theme.panel_list_height, theme.spacing.xs, function()
                return theme.control.lg
            end)
        end),
        scroll = scroll("audio_devices_" .. opts.name),
        source = devices,
        itemfn = function(device)
            return panel_row {
                slot = "audio-device-" .. opts.name .. "-" .. tostring(device.id),
                leading = rect {
                    width = theme.icon.md,
                    height = theme.icon.md,
                    children = { glyph(util.audio_device_glyph(device, opts.is_input)
                        or (opts.is_input and icons.mic_on or icons.speaker), theme.FG, theme.icon.md,
                        { align = "Center", align_v = "Center" }) },
                },
                title = util.device_name(device) or "?",
                color = device.active and theme.ACCENT or nil,
                trailing = glyph(icons.check, theme.ACCENT, theme.icon.sm, { visible = device.active }),
                on_activate = function()
                    mantle.audio[opts.set_default](mantle.audio, device.id)
                    picker:set(false)
                end,
            }
        end,
        key = function(device)
            return tostring(device.id)
        end,
    }
    local is_muted = mantle.audio:map(function(audio)
        return audio ~= nil and audio[opts.muted]
    end)
    local mute_glyph = util.choose(is_muted, opts.is_input and icons.mic_off or icons.vol_muted,
        opts.is_input and icons.mic_on or icons.vol_high)
    local tint = util.choose(is_muted, theme.DIM, theme.FG)
    local leading_glyph = computed({ mantle.audio, mute_glyph }, function(audio, fallback)
        return audio and not audio[opts.muted]
            and util.audio_device_glyph(util.active_device(audio[opts.devices]), opts.is_input) or fallback
    end)
    local held = state("audio_pending_" .. opts.name, -1)
    local max = opts.headroom and util.MAX_VOLUME or 100
    tooltips[opts.name] = tooltip({
        id = "audio_mute_" .. opts.name .. "_tooltip",
        in_panel = true,
        slot = "audio-mute-" .. opts.name,
        children = { cell(util.choose(is_muted, "Unmute", "Mute"), theme.FG, theme.font.sm) },
    })

    local header = {
        slot = "audio-picker-" .. opts.name,
        leading = rect {
            width = theme.icon.md,
            height = theme.icon.md,
            children = { glyph(leading_glyph, tint, theme.icon.md, { align = "Center", align_v = "Center" }) },
        },
        title = util.bold(opts.title),
        subtitle = util.label(mantle.audio, function(audio)
            return util.device_name(util.active_device(audio[opts.devices])) or "No device"
        end),
        trailing = row {
            spacing = theme.spacing.sm,
            align_v = "Center",
            children = {
                cell(util.bold(computed({ mantle.audio, held }, function(audio, held_value)
                    return percent(held_value >= 0 and held_value or audio and audio[opts.volume])
                end)), tint, theme.font.sm, { width = theme.control.lg, align = "End", align_v = "Center" }),
                panel_action_icon(mute_glyph, function()
                    mantle.audio[opts.toggle_mute](mantle.audio)
                end, {
                    slot = "audio-mute-" .. opts.name,
                    size = "md",
                    disabled = mantle.audio:map(function(audio)
                        return audio == nil or audio[opts.volume] == nil
                    end),
                }),
            },
        },
    }
    local children = {
        column {
            width = "Fill",
            children = devices:map(function(items)
                local opts_row = util.with(header, "expanded", #items > 1 and picker or nil)
                opts_row.details = #items > 1 and choices or nil
                return { panel_row(opts_row) }
            end),
        },
        column {
            width = "Fill",
            spacing = theme.spacing.sm,
            margin = { left = TRACK_INSET, right = theme.spacing.sm },
            children = util.concat({ slider {
                name = "audio_pending_" .. opts.name,
                signal = mantle.audio,
                read = function(audio)
                    return audio[opts.volume]
                end,
                on_commit = function(value)
                    mantle.audio[opts.set_volume](mantle.audio, value)
                end,
                pending = held,
                max = max,
                steps = max / 5,
                split_at = opts.headroom and 100 or nil,
                marker = opts.headroom,
                headroom_color = util.choose(is_muted, theme.INACTIVE, theme.RED),
                height = theme.audio_slider_height,
                color = util.choose(is_muted, theme.INACTIVE, theme.ACCENT),
            } }, opts.under),
        },
    }

    return panel_card(children, {
        width = "Fill",
        visible = opts.visible,
        spacing = theme.spacing.sm,
        padding = theme.spacing.sm,
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
    local tint = app.muted and theme.DIM or theme.FG
    local held = state("audio_pending_app_" .. tostring(app.id), -1)
    return column {
        width = "Fill",
        spacing = theme.spacing.xs,
        children = {
            panel_row {
                leading = rect { width = theme.icon.md, height = theme.icon.md, children = { leading } },
                title = name,
                height = theme.control.md,
                opacity = (app.muted or app.volume == nil) and theme.opacity.muted or nil,
                trailing = row {
                    spacing = theme.spacing.sm,
                    align_v = "Center",
                    children = {
                        glyph(icons.mic_on, theme.DIM, theme.icon.sm,
                            { align_v = "Center", visible = app.recording and icon_name ~= nil }),
                        cell(held:map(function(value)
                            return percent(value >= 0 and value or app.volume)
                        end), tint, theme.font.sm, {
                            width = theme.control.lg, align = "End", align_v = "Center",
                        }),
                        panel_action_icon(app.muted and icons.vol_muted or icons.vol_high, app.volume and function()
                            mantle.audio:set_app_muted(app.id, not app.muted)
                        end, { slot = "audio-stream-mute-" .. tostring(app.id), tint = tint }),
                    },
                },
            },
            column {
                width = "Fill",
                margin = { left = TRACK_INSET, right = theme.spacing.sm },
                children = { slider {
                    name = "audio_pending_app_" .. tostring(app.id),
                    pending = held,
                    signal = mantle.audio,
                    read = function(audio)
                        local stream = util.find(audio.apps, function(stream) return stream.id == app.id end)
                        return stream and stream.volume
                    end,
                    on_commit = function(value)
                        mantle.audio:set_app_volume(app.id, value)
                    end,
                    max = 100,
                    steps = 20,
                    color = app.muted and theme.INACTIVE or theme.ACCENT,
                } },
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
            local device = util.device_name(util.active_device(audio.sinks))
            return percent(audio.volume) .. (device and " · " .. device or "")
        end),
    },
    audio_control {
        name = "output",
        title = "Output",
        volume = "volume",
        muted = "muted",
        devices = "sinks",
        set_volume = "set_volume",
        set_default = "set_default_sink",
        toggle_mute = "toggle_mute",
        headroom = true,
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
        volume = "source_volume",
        muted = "source_muted",
        devices = "sources",
        is_input = true,
        set_volume = "set_source_volume",
        set_default = "set_default_source",
        toggle_mute = "toggle_source_mute",
        visible = util.shown_when(mantle.audio, function(audio)
            return util.active_device(audio.sources) ~= nil
        end),
    },
    -- Flat: a disclosure row and its list, not a third card.
    panel_row {
        slot = "audio-mixer",
        icon = icons.mixer,
        title = "Application mixer",
        subtitle = util.label(streams, function(list)
            return string.format("%d active", #list)
        end),
        expanded = mixer_open,
        visible = streams:map(function(list)
            return #list > 0
        end),
        details = list {
            width = "Fill",
            max_height = streams:map(function(list)
                return util.fit_height(list, theme.panel_list_height, theme.spacing.sm, function()
                    return STREAM_HEIGHT
                end)
            end),
            scroll = scroll("audio_mixer"),
            spacing = theme.spacing.sm,
            source = streams,
            itemfn = stream_row,
            key = function(app)
                return tostring(app.id)
            end,
        },
    },
}

return {
    kind = "audio",
    body = body,
    output_tooltip = tooltips.output,
    input_tooltip = tooltips.input
}
