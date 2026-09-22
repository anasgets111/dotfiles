local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")

local function users_of(field)
    return function(p)
        return #((p or {})[field] or {}) > 0
    end
end

local function alert(glyph, field, slot)
    return icon_button(glyph, nil, {
        slot = slot,
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

local mic_tooltip = tooltip({
    id = "privacy_microphone_tooltip",
    slot = "privacy_microphone",
    text = mic_muted:map(function(muted)
        return muted and "Microphone muted" or "Microphone in use"
    end),
})

local camera_tooltip = tooltip({ id = "privacy_camera_tooltip", slot = "privacy_camera", text = "Camera in use" })

local screenshare_tooltip = tooltip({ id = "privacy_screenshare_tooltip", slot = "privacy_screenshare", text = "Screen sharing in progress" })

-- Camera and screencast are readouts; their circles do nothing. The microphone is the control.
-- It uses `audio:toggle_source_mute`; muting does not end capture, so the circle stays up.
local indicator = row {
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
        alert(icons.camera, "camera_users", "privacy_camera"),
        icon_button(mic_muted:map(function(muted)
            return muted and icons.mic_off or icons.mic_on
        end), function()
            mantle.audio:invoke("toggle_source_mute")
        end, {
            slot = "privacy_microphone",
            background = mic_muted:map(function(muted)
                return muted and theme.PEACH or theme.RED
            end),
            visible = mic_shown,
        }),
        alert(icons.screenshare, "screencast_users", "privacy_screenshare"),
    },
}

return {
    indicator = indicator,
    camera_tooltip = camera_tooltip,
    microphone_tooltip = mic_tooltip,
    screenshare_tooltip = screenshare_tooltip,
}
