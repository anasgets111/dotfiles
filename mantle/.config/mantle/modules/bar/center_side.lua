local media = require("modules.bar.indicators.media")
local window_title_module = require("modules.bar.indicators.active_window")
local media_panel = require("modules.bar.panels.media_panel")
local ui_state = require("lib.ui_state")

local MEDIA_SLOT = "media_indicator"

local playback_available = mantle.mpris:map(function(mpris)
    local player = ((mpris and mpris.players) or {})[1]
    return player ~= nil and player.play_state ~= "Stopped"
end)

return row {
    height = "Fill",
    align_h = "Center",
    align_v = "Center",
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
