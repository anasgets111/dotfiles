-- Output and Microphone cards, each with one device picker, then app streams and a collapsed
-- Advanced section. The sections live in `modules/bar/panels/audio/`.
local util = require("lib.util")
local panel_header = require("components.panel_header")
local panel_empty_state = require("components.panel_empty_state")
local picker = require("modules.bar.panels.audio.picker")
local mixer = require("modules.bar.panels.audio.mixer")
local advanced = require("modules.bar.panels.audio.advanced")

local body = {
    panel_header {
        title = "Audio",
        icon = mantle.audio:map(util.volume_glyph, util.volume_glyph()),
        active = mantle.audio:map(function(audio)
            local sink = util.default_sink(audio)
            return sink ~= nil and sink.volume ~= nil and not sink.muted
        end, false),
        -- The cards below name the device and level; the header says only what plays.
        subtitle = mixer.playing:map(function(count)
            return count == 0 and "" or count == 1 and "1 app playing" or string.format("%d apps playing", count)
        end),
    },
    panel_empty_state("Audio unavailable", mantle.audio:map(function(audio)
        return #audio.sinks == 0 and #audio.sources == 0
    end, false)),
    picker.output,
    picker.input,
    mixer.body,
    advanced.body,
}

return {
    kind = "audio",
    body = body,
    output_tooltip = picker.tooltips[1],
    input_tooltip = picker.tooltips[2],
}
