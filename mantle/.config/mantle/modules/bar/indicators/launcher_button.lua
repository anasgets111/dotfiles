local icons = require("config.icons")
local icon_button = require("components.icon_button")
local ui_state = require("lib.ui_state")
local tooltip = require("components.tooltip")

local SLOT = "launcher"

local launcher_button = icon_button(icons.launcher, function()
    ui_state.toggle_modal("launcher")
end, { slot = SLOT, selected = ui_state.modal_showing("launcher") })

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
