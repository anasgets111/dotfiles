local theme = require("config.theme")
local center = require("modules.bar.center_side")
local workspaces = require("modules.bar.indicators.workspace_strip")
local audio_panel = require("modules.bar.panels.audio_panel")

local LEFT = {
    "rescue", "power_menu", "updates", "idle_inhibitor", "keyboard_layout", "battery",
    "launcher_button", "wallpaper_button", "special_workspaces", "workspace_strip",
}
local RIGHT = { "privacy", "volume", "screen_recorder", "network", "bluetooth", "sys_tray", "date_time" }
local tooltips = {}

local function side(names, name, align)
    local children = {}
    for _, module in ipairs(names) do
        local indicator = require("modules.bar.indicators." .. module)
        children[#children + 1] = indicator.indicator
        for _, tip in ipairs(indicator.tooltips or {}) do
            tooltips[#tooltips + 1] = tip
        end
    end
    -- Fill sides share the remainder; the centre measures each content-sized inner row.
    return row {
        width = "Fill", height = "Fill", align_h = align, align_v = "Center",
        children = { row {
            geometry = geometry("bar-" .. name), height = "Fill", align_v = "Center",
            spacing = theme.spacing.sm, children = children,
        } },
    }
end

local indicator = row {
    width = "Fill", height = theme.bar_height,
    background = theme.GLASS_SURFACE, behind_blur = true,
    padding = { left = theme.spacing.md, right = theme.spacing.md },
    children = { side(LEFT, "left", "Start"), center, side(RIGHT, "right", "End") },
}
tooltips[#tooltips + 1] = audio_panel.output_tooltip
tooltips[#tooltips + 1] = audio_panel.input_tooltip

return { indicator = indicator, tooltips = tooltips, drag_ghost = workspaces.drag_ghost }
