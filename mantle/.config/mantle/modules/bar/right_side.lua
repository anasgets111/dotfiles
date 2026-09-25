local theme = require("config.theme")
local privacy_module = require("modules.bar.indicators.privacy")
local volume_module = require("modules.bar.indicators.volume")
local screen_recorder = require("modules.bar.indicators.screen_recorder")
local network = require("modules.bar.indicators.network")
local bluetooth = require("modules.bar.indicators.bluetooth")
local tray_module = require("modules.bar.indicators.sys_tray")
local bell = require("modules.bar.indicators.notification_bell")
local date_time = require("modules.bar.indicators.date_time")
local ui_state = require("lib.ui_state")
local icon_button = require("components.icon_button")

-- TEMP: opens the effects demo (modules/probe_fx.lua). Remove with it.
local fx_probe = state("fx_probe", false)
local fx_button = icon_button("\u{f0d0}", function()
    fx_probe:set(not fx_probe:get())
end, { slot = "fx_probe_button", selected = fx_probe })

-- One control holds bell and clock, and a single button fills it. The whole readout opens the
-- notifications panel; calendar detail lives in the clock's hover tooltip.
local clock_pill = icon_button(nil, nil, {
    slot = date_time.slot,
    radius = theme.item_radius,
    selected = ui_state.panel_showing(bell.kind),
    on_button = function(rect, mouse_button)
        if mouse_button == "left" or mouse_button == "right" then
            bell.open(rect)
        elseif mouse_button == "middle" then
            local notifications = mantle.notifications:get()
            mantle.notifications:set_dnd(not (notifications and notifications.dnd))
        end
    end,
    content = row {
        height = "Fill",
        align_v = "Center",
        spacing = theme.spacing.xs,
        -- Without this inset, bell and minutes run under the pill's radius.
        padding = { left = theme.spacing.sm, right = theme.spacing.sm },
        children = { bell.bell, date_time.clock },
    },
})

return row {
    width = "Fill",
    height = "Fill",
    align_h = "End",
    align_v = "Center",
    children = { row {
        geometry = geometry("bar-right"),
        height = "Fill",
        align_v = "Center",
        spacing = theme.spacing.sm,
        children = {
            privacy_module.indicator,
            volume_module.indicator,
            screen_recorder.indicator,
            network.indicator,
            bluetooth.indicator,
            tray_module.indicator,
            fx_button, -- TEMP effects demo
            clock_pill,
        },
    } },
}
