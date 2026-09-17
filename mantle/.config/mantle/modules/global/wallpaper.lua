-- Wallpaper is not a capability: a `Background` panel with one image per output, using
-- `lib/wallpaper.lua`. `child` is keyed by output name, so each screen gets its own file
-- and fit, including monitors plugged in later without a reload.
--
-- `async` with `transition` decodes off the render thread, holds the current
-- image until replacement is ready, then cross-fades. Synchronous decode stalls the render thread
-- 162.7ms per change (114ms in release), and `async` without `retain` flashes the ground.
local wallpaper = require("lib.wallpaper")

-- Built twice: `place-within-backdrop` moves a surface into Niri's backdrop rather than copying it,
-- so the desktop needs its own. Unblurred: `blur` blurs what is behind a node, and an `image`
-- takes no shader outside a `transition`.
local function wallpaper_panel(id, visible)
    -- Anchor all four edges so the compositor sizes both axes over the output.
    --
    -- Use `"Ignore"`, not `false`. Both reserve nothing, but `false` respects other reservations (a
    -- bar shrinks and displaces the surface). Layer-shell `-1` ignores them and covers the output.
    -- `true` also reads as 0 for an all-edge surface with no single edge.
    return panel {
        id = id,
        visible = visible, -- `nil` on the desktop, which is never conditional.
        layer = "Background",
        anchor = { top = true, bottom = true, left = true, right = true },
        exclusive = "Ignore",
        width = "Fill",
        height = "Fill",
        -- Under the image: a failed decode leaves the desktop dark, not transparent, so the failure is
        -- visible instead of looking like an unmapped surface.
        background = "#11111bff",
        child = function(output)
            return image {
                -- `retain` holds the last picture across a source change, so keep the node's `id`
                -- stable and put the path in `source`, not its identity.
                id = "wallpaper_image",
                source = wallpaper.path_of(output),
                fit = wallpaper.fit_of(output),
                async = true,
                -- `transition` implies `retain`: one declaration holds the old picture and
                -- crosses with the selected `.frag` from `wallpaper.SHADER_FOLDER`, not an engine-known
                -- name.
                transition = wallpaper.transition(),
                width = "Fill",
                height = "Fill",
            }
        end,
    }
end

-- Hyprland has no backdrop, so the second panel would decode a picture nothing draws. `false`
-- destroys the surface rather than hiding it, and reads `nil` until the first answer.
local on_niri = mantle.workspaces:map(function(w)
    return w ~= nil and w.compositor == "niri"
end)

return {
    desktop = wallpaper_panel("wallpaper"),
    overview = wallpaper_panel("overview_wallpaper", on_niri),
}
