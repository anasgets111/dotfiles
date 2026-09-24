-- A glyph circle expands to a slider on hover. Drag and wheel set volume; middle-click mutes, and
-- right-click opens the audio panel. Width and ground ease through `animate`, while the percentage
-- appears at once, because `visible` is not a property a tween carries.
local theme = require("config.theme")
local util = require("lib.util")
local ui_state = require("lib.ui_state")
local cell = require("components.cell")
local glyph = require("components.glyph")
local slider = require("components.slider")

local SLOT = "volume"
local hovered = hover(SLOT)
local dragging = state("volume_dragging", false)
-- The slider's held value, `-1` when none; the readout follows a drag before PipeWire answers.
local held = state("volume_pending", -1)
local expanded = computed({ hovered, dragging }, function(is_hovered, is_dragging)
    return is_hovered or is_dragging
end)

local function muted(audio)
    return audio ~= nil and audio.muted
end

local function volume(audio)
    return audio and audio.volume
end

-- Muted uses the content ground to say "this is off" without changing glyph colour.
local ground = computed({ mantle.audio, hovered }, function(audio, is_hovered)
    if is_hovered then
        return theme.GLASS_CONTROL_HOVER
    end
    return muted(audio) and theme.GLASS_CONTENT or theme.GLASS_CONTROL
end)

-- Muted makes the fill inactive, so 60% reads as a grey bar, not purple "loud".
local fill = mantle.audio:map(function(audio)
    return muted(audio) and theme.INACTIVE or theme.ACCENT
end)
local headroom = mantle.audio:map(function(audio)
    return muted(audio) and theme.INACTIVE or theme.RED
end)

local width = expanded:map(function(is_expanded)
    return is_expanded and theme.volume_expanded_width or theme.item_width
end)
local volume_glyph = mantle.audio:map(util.volume_glyph)
local readout = computed({ mantle.audio, held }, function(audio, pending)
    if volume(audio) == nil then
        return "--"
    elseif audio.muted then
        return "Muted"
    end
    return string.format("%d%%", math.floor((pending >= 0 and pending or audio.volume) * 100 + 0.5))
end)

return slider {
    name = "volume_pending",
    signal = mantle.audio,
    read = volume,
    on_commit = function(value)
        mantle.audio:set_volume(value)
        -- After the level, so an unmute is never heard at the old one.
        mantle.audio:set_muted(false)
    end,
    max = util.MAX_VOLUME,
    split_at = 1,
    pending = held,
    headroom_color = headroom,
    width = width,
    height = theme.item_height,
    align_v = "Center",
    hover = hovered,
    dragging = dragging,
    radius = theme.item_radius,
    background = ground,
    color = fill,
    fill_visible = expanded,
    animate = { width = theme.animation_ms, background = theme.animation_ms, border_color = theme.animation_ms },
    border_width = theme.border_width,
    border_color = computed({ hovered, ui_state.panel_showing("audio") }, function(is_hovered, open)
        if open then
            return theme.ACCENT
        end
        return is_hovered and theme.GLASS_BORDER_HOVER or theme.GLASS_BORDER
    end),
    on_click = function(rect, mouse_button)
        if mouse_button == "middle" then
            mantle.audio:toggle_mute()
        elseif mouse_button == "right" then
            ui_state.toggle_panel("audio", rect)
        end
    end,
    -- Eases with the control, so the copies inside the bars stay on the one under them.
    label = function(under)
        ---@cast under Signal<Color>
        local ink = under:map(theme.text_contrast)
        return row {
            width = width,
            height = "Fill",
            align_h = "Center",
            align_v = "Center",
            spacing = theme.spacing.xs,
            animate = { width = theme.animation_ms },
            children = {
                glyph(volume_glyph, ink, theme.icon.lg, { align_v = "Center" }),
                -- A hidden percentage costs no width or spacing gap.
                cell(readout, ink, theme.font.sm, { align_v = "Center", visible = expanded }),
            },
        }
    end,
}
