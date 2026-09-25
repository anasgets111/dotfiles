local theme = require("config.theme")
local media = require("modules.bar.indicators.media")
local volume = require("modules.bar.indicators.volume")
local power_menu = require("modules.bar.indicators.power_menu")
local workspaces = require("modules.bar.indicators.workspace_strip")
local window_title_module = require("modules.bar.indicators.active_window")
local media_panel = require("modules.bar.panels.media_panel")
local ui_state = require("lib.ui_state")

local MEDIA_SLOT = "media_indicator"

local playback_available = mantle.mpris:map(function(mpris)
    local player = ((mpris and mpris.players) or {})[1]
    return player ~= nil and player.play_state ~= "Stopped"
end)

-- Hidden, the row measures zero, so the test uses its last shown rect.
local center_geometry = geometry("bar-center")
local shown_rect
local center_rect = center_geometry:map(function(rect)
    if rect.width > 0 then
        shown_rect = rect
    end
    return shown_rect
end)

-- Hides when a side's indicators reach it, as an expanded pill or volume slider can.
-- ponytail: every output's bar shares these nodes, so monitors of different widths overwrite one
-- measurement. Upgrade: a per-output `child` in `panel_host.lua` with per-output geometry names.
-- Growth counts from the pass that starts an ease, not the one after it, so the centre hides before
-- an indicator reaches it; a shrink waits for the ease to settle.
local function growth(rect, target)
    return rect.width > 0 and math.max(0, target - rect.width) or 0
end

local clear = computed({
    center_rect,
    geometry("bar-left"),
    geometry("bar-right"),
    power_menu.pill.geometry,
    power_menu.pill.width,
    workspaces.pill.geometry,
    workspaces.pill.width,
    volume.geometry,
    volume.width,
}, function(center, left, right, power, power_width, strip, strip_width, slider, slider_width)
    local gap = theme.spacing.sm
    local left_end = left.x + left.width + growth(power, power_width) + growth(strip, strip_width)
    return center == nil
        or (left_end + gap <= center.x and center.x + center.width + gap <= right.x - growth(slider, slider_width))
end)

return row {
    geometry = center_geometry,
    height = "Fill",
    align_h = "Center",
    align_v = "Center",
    visible = clear,
    children = { rect {
        height = "Fill",
        align_v = "Center",
        hover = hover(MEDIA_SLOT),
        on_hover = function(is_hovered)
            ui_state.set_media_hover("trigger", is_hovered)
            if is_hovered and playback_available:get()
                and (not ui_state.panel_open:get() or ui_state.panel_kind:get() == media_panel.kind) then
                ui_state.open_panel(media_panel.kind, hover_rect(MEDIA_SLOT):get())
            end
        end,
        children = {
            window_title_module,
            row {
                height = "Fill",
                align_h = "Center",
                align_v = "Center",
                visible = playback_available,
                children = { media },
            },
        },
    } },
}
