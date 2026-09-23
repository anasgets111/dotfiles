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

-- One control holds bell and clock, and a single button fills it. The whole readout opens the
-- notifications panel; calendar detail lives in the clock's hover tooltip.
local hovered = hover(date_time.slot)

-- The border rings accent while the panel is up, a third state above hover.
local panel_showing = ui_state.panel_showing(bell.kind)

local clock_pill = button {
    height = theme.item_height,
    align_v = "Center",
    hover = hovered,
    radius = theme.item_radius,
    background = computed({ hovered, panel_showing }, function(is_hovered, is_open)
        return (is_hovered or is_open) and theme.GLASS_CONTROL_HOVER or theme.GLASS_CONTROL
    end),
    border_width = theme.border_width,
    border_color = computed({ hovered, panel_showing }, function(is_hovered, is_open)
        if is_open then
            return theme.ACCENT
        end
        return is_hovered and theme.GLASS_BORDER_HOVER or theme.GLASS_BORDER
    end),
    animate = { background = theme.animation_ms },
    on_click = function(rect, mouse_button)
        if mouse_button == "left" or mouse_button == "right" then
            bell.open(rect)
        elseif mouse_button == "middle" then
            local notifications = mantle.notifications:get()
            mantle.notifications:invoke("set_dnd", not (notifications and notifications.dnd))
        end
    end,
    children = { row {
        height = "Fill",
        align_v = "Center",
        spacing = theme.spacing.xs,
        -- Without this inset, bell and minutes run under the pill's radius.
        padding = { left = theme.spacing.sm, right = theme.spacing.sm },
        children = { bell.bell, date_time.clock },
    } },
}

return row {
    width = "Fill",
    height = "Fill",
    align_h = "End",
    align_v = "Center",
    spacing = theme.spacing.sm,
    children = {
        privacy_module.indicator,
        volume_module,
        screen_recorder.indicator,
        network.indicator,
        bluetooth.indicator,
        tray_module.indicator,
        clock_pill,
    },
}
