-- Red circles appear only while their device is in use, and the group disappears when none is.
--
-- `PrivacyState` reports `camera_users`, `microphone_users`, and `screencast_users` from the same
-- PipeWire connection.
--
-- "In use" is PipeWire `Running`, not stream existence. A browser tab can keep a capture node open
-- between calls, so existence would leave the microphone circle lit.
--
-- Red ground uses `text_contrast` for the glyph colour, not a red label.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local icon_button = require("components.icon_button")

local function users_of(field)
    return function(p)
        return #((p or {})[field] or {}) > 0
    end
end

local function alert(glyph, field, on_activate)
    return icon_button(glyph, on_activate, {
        background = theme.RED,
        visible = util.shown_when(mantle.privacy, users_of(field)),
    })
end

-- The microphone has two states: `warning` ground and a struck-through glyph when muted, `critical`
-- and the plain glyph when live, shown while active or muted. A muted microphone therefore stays
-- available to unmute.
local mic_muted = mantle.audio:map(function(a)
    return a ~= nil and a.source_muted == true
end)
local mic_shown = computed({ mantle.privacy, mic_muted }, function(p, muted)
    return users_of("microphone_users")(p) or muted
end)

-- Camera and screencast are readouts; their circles do nothing. The microphone is the control.
-- It uses `audio:toggle_source_mute`; muting does not end capture, so the circle stays up.
return row {
    align_v = "Center",
    spacing = theme.spacing.sm,
    -- Invisible children leave layout, but the row still contributes spacing. Hide the group, or
    -- `left_side.lua` still gives the empty row that gap.
    -- Use `mic_shown`, not `microphone_users`: a muted microphone appears without a user.
    -- Hiding the row would hide it too.
    visible = computed({ mantle.privacy, mic_shown }, function(p, mic)
        return mic or users_of("camera_users")(p) or users_of("screencast_users")(p)
    end),
    children = {
        alert(icons.camera, "camera_users"),
        icon_button(mic_muted:map(function(muted)
            return muted and icons.mic_off or icons.mic_on
        end), function()
            mantle.audio:invoke("toggle_source_mute")
        end, {
            background = mic_muted:map(function(muted)
                return muted and theme.PEACH or theme.RED
            end),
            visible = mic_shown,
        }),
        alert(icons.screenshare, "screencast_users"),
    },
}
