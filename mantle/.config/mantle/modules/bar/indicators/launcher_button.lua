local icons = require("config.icons")
local icon_button = require("components.icon_button")
local ui_state = require("lib.ui_state")
local tooltip = require("components.tooltip")

local SLOT = "launcher"

local launcher_button = icon_button(icons.launcher, function()
    ui_state.toggle_modal("launcher")
end, { slot = SLOT, selected = ui_state.modal_showing("launcher") })

local launcher_tooltip = tooltip({
    slot = SLOT,
    text = "Open application launcher",
    detail = mantle.applications:map(function(applications)
        local count = 0
        for _, entry in ipairs(applications and applications.entries or {}) do
            if not entry.no_display then count = count + 1 end
        end
        return string.format("%d application(s)", count)
    end),
})

return { indicator = launcher_button, tooltips = { launcher_tooltip } }
