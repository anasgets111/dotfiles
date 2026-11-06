-- App streams. One or two show inline; three or more sit behind a disclosure. An app's device
-- name opens the devices it can move to under it.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local glyph = require("components.glyph")
local panel_row = require("components.panel_row")
local panel_card = require("components.panel_card")
local reveal = require("components.reveal")
local disclosure = require("lib.disclosure")
local rows = require("modules.bar.panels.audio.rows")

local INLINE_MAX = 2

local mixer_open = disclosure.state("audio_mixer_open", false)

-- speech-dispatcher's `sd_*` output modules hold idle streams open forever, so they stay out.
local function shown(audio)
    return util.filter(audio.apps, function(app) return not (app.binary or ""):match("^sd_") end)
end

local mixer_rows = computed({ mantle.audio, rows.open_picker }, function(audio, open_key)
    local out = {}
    for _, app in ipairs(shown(audio)) do
        local devices = app.recording and audio.sources or audio.sinks
        local default = util.active_device(devices)
        local target = util.find(devices, function(device) return device.id == app.target end)
        local open = open_key == "app-" .. app.id
        out[#out + 1] = {
            kind = "stream",
            app = app,
            open = open,
            -- Where it plays: its linked device, else the default it will reach.
            device = util.device_name(target or default) or "No device",
            -- Default counts as a choice, so any device makes two.
            choosable = #devices > 0,
            key = "app-" .. app.id,
            height = rows.LEVEL_HEIGHT,
        }
        local follows = app.pinned_to == nil
        if open then
            out[#out + 1] = {
                kind = "target",
                app = app.id,
                title = "Default",
                icon = icons.auto,
                active = follows,
                key = "target-" .. app.id .. "-default",
                height = rows.OPTION_HEIGHT,
            }
            for _, device in ipairs(devices) do
                out[#out + 1] = {
                    kind = "target",
                    app = app.id,
                    device = device.id,
                    title = util.device_name(device) or "?",
                    icon = util.audio_device_glyph(device, app.recording)
                        or (app.recording and icons.mic or icons.speaker),
                    active = device.id == app.pinned_to,
                    key = "target-" .. app.id .. "-" .. device.id,
                    height = rows.OPTION_HEIGHT,
                }
            end
        end
    end
    return out
end, {})

local function mixer_row(item)
    if item.kind == "target" then
        return rows.option_row(item, function()
            mantle.audio:set_app_target(item.app, item.device)
            rows.open_picker:set("")
        end)
    end
    local app = item.app
    local applications = mantle.applications:get()
    local entry = util.app_entry(applications, app.binary)
        or util.app_entry(applications, app.process_name)
        or util.app_entry(applications, app.name)
    local icon_name = entry and entry.icon or app.icon
    return rows.level_row {
        key = "app_" .. tostring(app.id),
        leading = icon_name and icon { name = icon_name, size = rows.GRID.icon, align_v = "center" }
            or rows.glyph(app.recording and icons.mic or icons.music_note),
        title = entry and entry.name or app.name or app.process_name or "Unknown",
        picker = { key = "app-" .. app.id, label = item.device, choosable = item.choosable },
        level = app,
        read = function(audio)
            local stream = util.find(audio.apps, function(stream) return stream.id == app.id end)
            return stream and stream.volume
        end,
        set_volume = function(value) mantle.audio:set_app_volume(app.id, value) end,
        set_muted = function(muted) mantle.audio:set_app_muted(app.id, muted) end,
        is_input = app.recording,
        badge = glyph(icons.mic, theme.DIM, theme.icon.sm,
            { align_v = "center", visible = app.recording and icon_name ~= nil }),
    }
end

local count = mantle.audio:map(function(audio) return #shown(audio) end, 0)

local list_node = list {
    width = "fill",
    max_height = mixer_rows:map(function(items)
        return util.fit_height(items, theme.panel_list_height, theme.spacing.sm, function(item)
            return item.height
        end)
    end),
    scroll = scroll("audio_mixer"),
    animate = { scroll = theme.scroll_ease },
    spacing = theme.spacing.sm,
    items = mixer_rows,
    each = mixer_row,
    key = function(item)
        return item.key
    end,
}

local heading = panel_row {
    slot = "audio-mixer",
    height = rows.GRID.row_height,
    leading = rows.icon_column(rows.glyph(icons.mixer)),
    title = "Application mixer",
    subtitle = util.label(count, function(n) return string.format("%d active", n) end),
    expanded = mixer_open,
    visible = count:map(function(n) return n > INLINE_MAX end),
}

return {
    -- Apps playing, not recording, for the panel header.
    playing = mantle.audio:map(function(audio)
        return #util.filter(shown(audio), function(app) return not app.recording end)
    end, 0),
    -- Carded like Output and Microphone, heading included, so every section shares one grid.
    body = panel_card({
        reveal(heading, list_node, computed({ count, mixer_open }, function(n, open)
            return n <= INLINE_MAX or open
        end), { slot = "audio-mixer" }),
    }, {
        width = "fill",
        padding = rows.GRID.pad,
        visible = count:map(function(n) return n > 0 end),
    }),
}
