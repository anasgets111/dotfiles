-- Card profiles and ports turned into the choices the audio panel offers. No nodes.
-- Profiles are read from `profile.name`, which PipeWire leaves untranslated, not `description`.
local icons = require("config.icons")
local audio_config = require("config.audio")
local util = require("lib.util")

local audio = {}

audio.MAX_VOLUME = 150

function audio.active_device(devices)
    return util.find(devices, function(device) return device.active end)
end

function audio.default_sink(audio_state)
    return audio.active_device(audio_state and audio_state.sinks)
end

local ANALOG_PORTS = {
    output = { speaker = "Speakers", headphones = "Headphones", headset = "Headset", line = "Line out" },
    input = { mic = "Built-in mic", headset = "Headset mic", line = "Line in" },
}

-- What a person calls an `AudioDevice`: the `config/audio.lua` label, a Bluetooth device's own
-- name, "TV / Monitor" for HDMI, "Speakers" or "Headphones" for an analog jack, else its name
-- without redundant ALSA words.
-- ponytail: HDMI never names its display. PipeWire's routes here carry only `port.type`, the
-- availability group and an icon name, and the engine passes no route info on. A monitor name from
-- the ELD in `mantle.audio` is the upgrade.
function audio.device_name(device)
    if device == nil then
        return nil
    end
    local node = device.node_name or ""
    local label = audio_config.names[node]
    if label then
        return label
    elseif device.bus == "bluetooth" then
        return device.name
    elseif device.port == "hdmi" or device.port == "displayport" or node:find("%.hdmi%-") then
        local extra = node:match("%-extra(%d+)$")
        return "TV / Monitor" .. (extra and " " .. (tonumber(extra) + 1) or "")
    end
    local jack = node:find("analog") and device.port
        and ANALOG_PORTS[node:match("^alsa_input") and "input" or "output"][device.port]
    if jack then
        return jack
    end
    local name = device.name or ""
    name = name:gsub("%s*[Hh]igh [Dd]efinition [Aa]udio [Cc]ontroller", ""):gsub("%s*H?D? ?[Aa]udio [Cc]ontroller", "")
    name = name:gsub("%s*[Dd]igital [Ss]tereo", ""):gsub("%s*[Aa]nalog [Ss]tereo", "")
    name = name:gsub("%s*%(HDMI%)", " HDMI"):gsub("%s*%(S/PDIF%)", " S/PDIF"):gsub("%s*%(IEC958%)", " S/PDIF")
    name = name:gsub("%s+", " "):match("^%s*(.-)%s*$")
    return name ~= "" and name or device.name
end

-- "Used by A", "Used by A and B" or "Used by A +2" for `PrivacyUser`s, `nil` for none.
function audio.used_by(users)
    local count = #(users or {})
    if count == 0 then
        return nil
    elseif count == 1 then
        return "Used by " .. users[1].app_name
    elseif count == 2 then
        return string.format("Used by %s and %s", users[1].app_name, users[2].app_name)
    end
    return string.format("Used by %s +%d", users[1].app_name, count - 1)
end

-- `audio.audio_device_glyph`'s hints, strongest first: `{ field, pattern, glyph, input glyph? }`.
local AUDIO_DEVICE_HINTS = {
    { "port",        "headset",     "headset" },
    { "port",        "headphones",  "headphones" },
    { "port",        "hdmi",        "television" },
    { "port",        "displayport", "television" },
    { "form_factor", "headset",     "headset" },
    { "form_factor", "hands%-free", "headset" },
    { "form_factor", "headphone",   "headphones", "headset" },
    { "form_factor", "tv",          "television" },
    { "form_factor", "webcam",      "webcam" },
    { "form_factor", "handset",     "phone" },
    { "bus",         "usb",         "usb" },
}

-- Glyph for an `AudioDevice`, or `nil` when nothing names one; callers supply the fallback.
function audio.audio_device_glyph(device, is_input)
    for _, hint in ipairs(AUDIO_DEVICE_HINTS) do
        local value = device and device[hint[1]]
        if value and value:find(hint[2]) then
            return icons[is_input and hint[4] or hint[3]]
        end
    end
end

-- The default output's glyph. Takes the raw audio payload, not a signal; callers choose when to
-- read it. Font glyphs let the OSD tint the volume icon.
function audio.volume_glyph(audio_state)
    local sink = audio.default_sink(audio_state)
    if sink == nil or sink.volume == nil then
        return "--"
    elseif sink.muted then
        return icons.vol_muted
    end
    local percent = sink.volume
    if percent < 1 then
        return icons.vol_zero
    elseif percent < 33 then
        return icons.vol_low
    elseif percent < 66 then
        return icons.vol_mid
    end
    return icons.vol_high
end

audio.DIRECTIONS = {
    { port = "output", devices = "sinks",   part = "output", others = "Other outputs", is_input = false },
    { port = "input",  devices = "sources", part = "input",  others = "Other inputs",  is_input = true },
}

-- The `output:` or `input:` part of a profile name, e.g. `hdmi-stereo-extra1`.
function audio.part(name, which)
    return name:match(which .. ":([^+]+)")
end

-- Advanced labels for ALSA outputs, keyed by the output part without its `-extraN` suffix.
local OUTPUT_LABELS = {
    ["analog-stereo"] = "Speakers",
    ["hdmi-stereo"] = "HDMI",
    ["hdmi-surround"] = "HDMI 5.1",
    ["hdmi-surround71"] = "HDMI 7.1",
}

-- `hdmi-stereo-extra1` is `hdmi-stereo` and the number `2`.
local function split_extra(output)
    local base, extra = output:match("^(.-)%-extra(%d+)$")
    return base or output, extra and tonumber(extra) + 1
end

local function numbered(label, number)
    return number and string.format("%s %d", label, number) or label
end

-- A profile's short label: its codec, a known output, else its description without the
-- "Output + … Input" tail.
function audio.profile_label(profile)
    if profile.codec then
        return profile.codec
    end
    local output = audio.part(profile.name, "output")
    if output then
        local base, number = split_extra(output)
        local label = OUTPUT_LABELS[base] or (base:match("^iec958") and "Optical")
        if label then
            return numbered(label, number)
        end
    end
    local cleaned = profile.description:gsub("%s*%+.*$", ""):gsub("%s+Output$", "")
    return audio.device_name({ name = cleaned }) or cleaned
end

-- What the output picker calls a profile, matching `audio.device_name` on the sink it makes.
local function output_name(profile)
    local output = audio.part(profile.name, "output")
    local base, number = split_extra(output or "")
    if base:match("^hdmi") then
        return numbered("TV / Monitor", number)
    elseif base == "analog-stereo" then
        return "Speakers"
    end
    return audio.profile_label(profile)
end

function audio.profile_icon(profile)
    local output = audio.part(profile.name, "output") or ""
    if profile.codec then
        return icons.bt_on
    elseif output:match("^hdmi") then
        return icons.television
    end
    return icons.speaker
end

-- One choice per output, in card order: no `off`, `pro-audio`, input-only or unplugged profile
-- (the active one stays), and on a Bluetooth card only codecs. Of an output's pair the active
-- variant wins, then a plugged one, then the one that keeps the microphone, so switching output
-- keeps the input.
-- Each: `{ index, label, active, available, output, surround }`.
function audio.profile_choices(card)
    local by_label, choices = {}, {}
    for _, profile in ipairs(card.profiles) do
        local output = audio.part(profile.name, "output")
        local shown = profile.available or profile.index == card.active
        if shown and (card.mac and profile.codec or not card.mac and output) then
            local label = audio.profile_label(profile)
            local held = by_label[label]
            if held == nil then
                held = { label = label, profile = profile }
                by_label[label] = held
                choices[#choices + 1] = held
            end
            local active, plugged = profile.index == card.active, profile.available
            local with_input = audio.part(profile.name, "input") ~= nil
            local better = held.index == nil or not held.active and (active
                or plugged and not held.available
                or plugged == held.available and with_input and not held.with_input)
            if better then
                held.index, held.active, held.available, held.with_input = profile.index, active, plugged, with_input
                held.profile, held.output = profile, output
                held.surround = output ~= nil and output:find("surround") ~= nil
            end
        end
    end
    return choices
end

-- Plugged ports of one direction that work under the active profile, which `set_port` requires.
function audio.port_choices(card, direction)
    local ports = util.filter(card.ports, function(port)
        return port.direction == direction.port and port.available
            and util.find(port.profiles, function(index) return index == card.active end) ~= nil
    end)
    local choices = {}
    for _, port in ipairs(ports) do
        choices[#choices + 1] = {
            index = port.index,
            label = port.description,
            active = port.active,
            available = true,
            icon = audio.audio_device_glyph({ port = port.type }, direction.is_input)
                or (direction.is_input and icons.mic or icons.speaker),
        }
    end
    return choices
end

-- The first plugged profile of a Bluetooth card whose name starts with `prefix`. PipeWire's bare
-- `a2dp-sink` is its preferred codec, so an exact match wins.
local function bluetooth_profile(card, prefix)
    local exact = util.find(card.profiles, function(profile)
        return profile.available and profile.name == prefix
    end)
    return exact or util.find(card.profiles, function(profile)
        return profile.available and profile.name:sub(1, #prefix) == prefix
    end)
end

-- Picker entries that switch a card's profile to make a new device of `direction`, for cards that
-- have none: `{ card, index, title, icon, available, suffix }`. `suffix` is the end of the
-- `node_name` the new device gets, `nil` on Bluetooth, where the card alone identifies it.
-- Surround layouts stay in Advanced.
function audio.creators(state, direction)
    local out = {}
    for _, card in ipairs(state.cards) do
        local has_device = util.find(state[direction.devices], function(device)
            return device.card == card.device
        end) ~= nil
        local active = util.find(card.profiles, function(profile) return profile.index == card.active end)
        if card.mac then
            local profile = not has_device and bluetooth_profile(card, direction.is_input and "headset-head-unit"
                or "a2dp-sink")
            if profile then
                out[#out + 1] = {
                    card = card.device,
                    index = profile.index,
                    title = direction.is_input and card.name .. " (headset)" or card.name,
                    icon = icons.bt_on,
                    available = true,
                }
            end
        elseif not direction.is_input then
            for _, choice in ipairs(audio.profile_choices(card)) do
                if not choice.active and not choice.surround then
                    out[#out + 1] = {
                        card = card.device,
                        index = choice.index,
                        title = output_name(choice.profile),
                        icon = audio.profile_icon(choice.profile),
                        available = choice.available,
                        suffix = choice.output,
                    }
                end
            end
        elseif not has_device then
            -- The same output with an input added, else an input-only profile when nothing plays.
            local keep = active and audio.part(active.name, "output")
            local profile = util.find(card.profiles, function(profile)
                return profile.available and audio.part(profile.name, "input") ~= nil
                    and audio.part(profile.name, "output") == keep
            end)
            if profile then
                out[#out + 1] = {
                    card = card.device,
                    index = profile.index,
                    title = "Built-in mic",
                    icon = icons.mic,
                    available = true,
                    suffix = audio.part(profile.name, "input"),
                }
            end
        end
    end
    return out
end

return audio
