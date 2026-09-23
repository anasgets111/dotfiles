local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local ui_state = require("lib.ui_state")
local panel_card = require("components.panel_card")
local panel_header = require("components.panel_header")
local section_header = require("components.section_header")

-- A real `xdg_toplevel`, opened from `power_menu.lua`. A `window` gets no monitor, anchor or size.
-- Thin on purpose: system info belongs in the notifications panel. This is the config's only
-- `window {}`, so it is also the only exercise of the toplevel.
return window {
    id = "settings",
    title = "Mantle settings",
    app_id = "mantle.settings",
    min_size = { width = 320, height = 240 },
    max_size = { width = 1280, height = 800 },
    visible = ui_state.settings_open,
    -- An opaque toplevel has no edge to round, hence `radius = 0`.
    child = panel_card({
        panel_header {
            title = "Mantle settings",
            on_close = function()
                ui_state.settings_open:set(false)
            end,
        },
        section_header("system"),
        cell(util.label(mantle.system, function(system)
            return "Up since " .. os.date("%H:%M:%S", system.time)
        end), theme.DIM, theme.font.xs),
        cell(util.label(mantle.audio, function(audio)
            return string.format("%d audio stream(s)", #(audio.apps or {}))
        end), theme.DIM, theme.font.xs),
        cell(util.label(mantle.screens, function(screens)
            return string.format("%d output(s)", #screens)
        end), theme.DIM, theme.font.xs),
    }, {
        width = "Fill",
        height = "Fill",
        padding = theme.spacing.lg,
        spacing = theme.spacing.sm,
        radius = 0,
    }),
}
