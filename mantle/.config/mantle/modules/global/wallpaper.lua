-- A `Background` panel with one image per output. `child` is keyed by output name, so a monitor
-- plugged in later gets its own file and fit. `async` decodes off the render thread (a synchronous
-- decode stalls it ~160ms per change) and `transition` holds the old image until the cross-fade.
local wallpaper = require("lib.wallpaper")
local theme = require("config.theme")

-- Built twice: Niri's `place-within-backdrop` moves a surface rather than copying it.
local function wallpaper_panel(id, visible)
    -- `"Ignore"` (layer-shell `-1`) covers the output; `false` would yield to the bar's reservation.
    return panel {
        id = id,
        visible = visible, -- `nil` on the desktop, which is never conditional.
        layer = "Background",
        anchor = { top = true, bottom = true, left = true, right = true },
        exclusive = "Ignore",
        width = "Fill",
        height = "Fill",
        -- A failed decode shows dark rather than looking like an unmapped surface.
        background = theme.CRUST,
        child = function(output)
            return image {
                -- `retain` holds the last picture across a source change, so keep the node's `id`
                -- stable and put the path in `source`, not its identity.
                id = "wallpaper_image",
                source = wallpaper.path_of(output),
                fit = wallpaper.fit_of(output),
                async = true,
                -- Implies `retain`; the shader is a `.frag` from `wallpaper.SHADER_FOLDER`.
                transition = wallpaper.transition(),
                width = "Fill",
                height = "Fill",
            }
        end,
    }
end

-- Hyprland has no backdrop and niri draws it only in the overview, so the surface exists only then
-- (`false` destroys it); otherwise an animated wallpaper repaints it for nobody. The picture is the
-- desktop panel's shared cache entry, so the rebuild decodes nothing.
local in_overview = mantle.workspaces:map(function(workspaces)
    return workspaces ~= nil and workspaces.compositor == "niri" and workspaces.overview_open == true
end)

return {
    desktop = wallpaper_panel("wallpaper"),
    overview = wallpaper_panel("overview_wallpaper", in_overview),
}
