-- The full text behind the bar's red circle: the tooltip carries the first line, this scrolls the
-- traceback. A modal because those paths outgrow the panel host's 340px card.
local theme = require("config.theme")
local icons = require("config.icons")
local cell = require("components.cell")
local panel_card = require("components.panel_card")
local panel_header = require("components.panel_header")
local icon_button = require("components.icon_button")
local modal = require("components.modal")
local ui_state = require("lib.ui_state")
local error_log = require("lib.rescue")

-- Evaluating at all means the config loaded, so an open card is showing a fixed error.
-- ponytail: a failure in a file required after this one closes the card early; the circle stays, so
-- a click reopens it. Upgrade: `on_change` for bare signals.
ui_state.close_modal("rescue")

local header = panel_header {
    title = "Configuration error",
    subtitle = "Still painting the last scene that loaded",
    icon = icons.warning,
    accent = theme.RED,
    title_size = theme.font.xl,
    subtitle_size = theme.font.sm,
    trailing = {
        -- Nothing is selectable. `detach`: `wl-copy` owns the selection while it lives.
        icon_button(icons.copy, function()
            process.detach("wl-copy", { error_log:get() })
        end, { slot = "rescue-copy", size = theme.control.sm, icon_size = theme.icon.sm }),
    },
    on_close = function()
        ui_state.close_modal("rescue")
    end,
}

-- One entry per line, not one wrapped block: a traceback's indentation is its structure, and Lua
-- indents it with tabs, which a shaper advances by rather than aligning to.
local log = list {
    width = "Fill",
    max_height = theme.rescue_log_height,
    scroll = scroll("rescue_log"),
    source = error_log:map(function(text)
        local lines = {}
        for line in text:gmatch("[^\n]+") do
            lines[#lines + 1] = (line:gsub("\t", "    "))
        end
        return lines
    end),
    itemfn = function(line)
        return cell(line, theme.FG, theme.font.xs, { width = "Fill", wrap = "Word", max_lines = 4 })
    end,
}

return modal({
    kind = "rescue",
    card = panel_card({
        header,
        panel_card({ log }, { width = "Fill" }),
    }, {
        width = theme.rescue_modal_width,
        align_h = "Center",
        align_v = "Center",
        spacing = theme.spacing.md,
        padding = theme.spacing.lg,
        tone = "dialog",
    }),
})
