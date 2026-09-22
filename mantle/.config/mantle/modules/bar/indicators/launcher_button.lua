-- A circular icon button between the battery and workspaces.
local icons = require("config.icons")
local icon_button = require("components.icon_button")
local ui_state = require("lib.ui_state")
local tooltip = require("components.tooltip")

local SLOT = "launcher"

local launcher_button = icon_button(icons.launcher, function()
    -- Refresh on open, not a timer: only this click needs the directory walked.
    if not ui_state.launcher_open:get() then
        mantle.applications:invoke("refresh")
    end
    ui_state.toggle_modal("launcher")
end, { slot = SLOT, selected = ui_state.launcher_open })

local launcher_tooltip = tooltip({
    id = "launcher_tooltip",
    slot = SLOT,
    text = "Open application launcher",
    detail = mantle.applications:map(function(applications)
        local entries = applications and applications.entries
        return string.format("%d application(s)", entries and #entries or 0)
    end),
})

return { button = launcher_button, tooltip = launcher_tooltip }
