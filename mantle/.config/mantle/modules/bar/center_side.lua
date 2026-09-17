-- Layers rather than swaps: the active-window indicator is anchored unconditionally and the media
-- indicator fills the same box on top of it, so the spectrum plays over the window title instead of
-- replacing it.
--
-- A `rect` is the stacking parent -- `modules/global/modal_host.lua` uses the same shape for its
-- scrim and click catcher. The zone stays content-sized because invisible children contribute no
-- size (`resolve_sizes` in scene.rs), so with nothing playing it is exactly the title's width, and
-- with the overlay up it is `theme.center_zone_width`.
local media = require("modules.bar.indicators.media")
local window_title_module = require("modules.bar.indicators.active_window")

-- A stopped player stays on the bus with its metadata intact, so checking only for a player's
-- existence would leave the spectrum up over an unplayed track.
local playback_available = mantle.mpris:map(function(m)
    local player = ((m and m.players) or {})[1]
    return player ~= nil and player.play_state ~= "Stopped"
end)

-- The zone itself stays a `row` with one child. `modules/bar/init.lua` lays the three zones out
-- side by side, so a stacking parent used directly as the zone reads as two modules end to end.
return row {
    height = "Fill",
    align_h = "Center",
    align_v = "Center",
    children = { rect {
        height = "Fill",
        align_v = "Center",
        children = {
            row {
                height = "Fill",
                align_h = "Center",
                align_v = "Center",
                children = { window_title_module },
            },
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
