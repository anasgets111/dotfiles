-- A pointer target opens the media panel. It has no glyph or track text; the track belongs to the
-- panel.
--
-- ## Why the bars are flat
--
-- Cava needs 30fps frames. The engine has no shader or canvas node; its nine node types draw no
-- waveform.
-- `rect`s can carry levels, but per-frame pushes are the first such path here; the bar logs
-- `exceeded the 5ms CPU budget` failures. Not attempted; see the ADR.
--
-- Flat is not a placeholder shape, though: a spectrum at zero level draws exactly this row.
local theme = require("config.theme")
local ui_state = require("lib.ui_state")
local media_panel = require("modules.bar.panels.media_panel")

-- Cava's configured bar count is 256. Fewer here because each is a real node, not a shader lane.
-- At rest it reads as the same fine rule; 256 static children buy nothing until they carry levels.
local BARS = 48

local GAP = theme.border_width
local BAR_HEIGHT = theme.border_width_medium

local tint = mantle.mpris:map(function(m)
    for _, player in ipairs((m and m.players) or {}) do
        if player.play_state == "Playing" then
            return theme.ACCENT_MEDIUM
        end
    end
    return theme.ACCENT_SUBTLE
end)

local children = {}
for index = 1, BARS do
    children[index] = rect {
        width = "Fill",
        height = BAR_HEIGHT,
        align_v = "End",
        background = tint,
    }
end

-- Click toggles the panel, matching every other indicator.
return button {
    width = theme.center_zone_width,
    height = "Fill",
    on_click = function(rect_, mouse_button)
        if mouse_button ~= "left" then
            return
        end
        ui_state.toggle_panel(media_panel.kind, rect_)
    end,
    children = { row {
        width = "Fill",
        height = "Fill",
        align_v = "End",
        padding = { top = theme.spacing.xs, right = theme.spacing.xs, bottom = theme.spacing.xs, left = theme.spacing.xs },
        spacing = GAP,
        animate = { background = { duration = theme.animation_ms, easing = "OutCubic" } },
        children = children,
    } },
}
