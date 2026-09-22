local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local ui_state = require("lib.ui_state")
local panel_card = require("components.panel_card")
local panel_header = require("components.panel_header")
local section_header = require("components.section_header")

-- A real `xdg_toplevel`, opened by `power_menu.lua` and closable through its `panel_header`. A
-- `window` gets no monitor, anchor, or size; inspect placement with `niri msg windows`.
--
-- This holds readouts without indicators: system info belongs at the top of the
-- notifications panel, and a second copy here would be the same numbers twice.
--
-- What is left is thin on purpose. This file is the config's only `window {}`, so it is also the
-- only exercise of the toplevel -- surviving a compositor that gives it no monitor, anchor or
-- size. Deleting it for being thin would delete that.
return window {
    id = "settings",
    title = "Mantle settings",
    app_id = "mantle.settings",
    min_size = { width = 320, height = 240 },
    max_size = { width = 1280, height = 800 },
    visible = ui_state.settings_open,
    -- This opaque toplevel has no edge to round.
    -- Set `radius = 0`.
    child = panel_card({
        panel_header {
            title = "Mantle settings",
            on_close = function()
                ui_state.settings_open:set(false)
            end,
        },
        section_header("system"),
        cell(util.label(mantle.system, function(s)
            return "Up since " .. os.date("%H:%M:%S", s.time)
        end), theme.DIM, theme.font.xs),
        cell(util.label(mantle.audio, function(a)
            return string.format("%d audio stream(s)", #(a.apps or {}))
        end), theme.DIM, theme.font.xs),
        cell(util.label(mantle.screens, function(s)
            return string.format("%d output(s)", #s)
        end), theme.DIM, theme.font.xs),
    }, {
        width = "Fill",
        height = "Fill",
        padding = {
            top = theme.spacing.lg,
            right = theme.spacing.lg,
            bottom = theme.spacing.lg,
            left = theme.spacing.lg,
        },
        spacing = theme.spacing.sm,
        radius = 0,
    }),
}
