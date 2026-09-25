local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")

local function users_of(field)
    return function(privacy)
        return #((privacy or {})[field] or {}) > 0
    end
end

local function alert(glyph, field, slot)
    return icon_button(glyph, nil, {
        slot = slot,
        background = theme.RED,
        visible = util.shown_when(mantle.privacy, users_of(field)),
    })
end

-- The microphone shows while active or muted, so a muted one stays reachable to unmute. Muted is
-- peach with a struck-through glyph, live is red with the plain one.
local mic_muted = mantle.audio:map(function(audio)
    return audio ~= nil and audio.source_muted == true
end)
local mic_shown = computed({ mantle.privacy, mic_muted }, function(privacy, muted)
    return users_of("microphone_users")(privacy) or muted
end)

local mic_tooltip = tooltip({
    id = "privacy_microphone_tooltip",
    slot = "privacy_microphone",
    text = mic_muted:map(function(muted)
        return muted and "Microphone muted" or "Microphone in use"
    end),
})

local camera_tooltip = tooltip({ id = "privacy_camera_tooltip", slot = "privacy_camera", text = "Camera in use" })

local screenshare_tooltip = tooltip({
    id = "privacy_screenshare_tooltip", slot = "privacy_screenshare", text = "Screen sharing in progress",
})

-- Camera and screencast circles are readouts. The microphone circle toggles source mute, which does
-- not end capture, so it stays up.
local indicator = row {
    align_v = "Center",
    spacing = theme.spacing.sm,
    -- Invisible children leave layout, but the row still takes `right_side.lua`'s gap, so the group
    -- hides itself. Keyed on `mic_shown`: a muted microphone appears without a user.
    visible = computed({ mantle.privacy, mic_shown }, function(privacy, mic)
        return mic or users_of("camera_users")(privacy) or users_of("screencast_users")(privacy)
    end),
    children = {
        alert(icons.camera, "camera_users", "privacy_camera"),
        icon_button(mic_muted:map(function(muted)
            return muted and icons.mic_off or icons.mic_on
        end), function()
            mantle.audio:toggle_source_mute()
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
