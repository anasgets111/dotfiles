-- Battery side effects with no surface: charger OSD, low-battery toasts, brightness and suspend.
-- Each acts on a crossing; the first push (`previous == nil`) is not one.
local icons = require("config.icons")
local util = require("lib.util")
local osd = require("modules.osd.service")

local thresholds = util.battery_thresholds

local function notify(summary, body, critical)
    process.detach("notify-send",
        { "-a", "Battery", "-u", critical and "critical" or "normal", "-t", "5000", "-e", summary, body })
end

-- Mains state is `mantle.power` (UPower manager `OnBattery`), not the battery capability.
mantle.power:on_change(function(power, previous)
    if previous == nil or power.on_battery == nil or power.on_battery == previous.on_battery then
        return
    end
    local battery = mantle.battery:get()
    if not (battery and battery.present) then
        return
    end
    osd.show("battery", {
        glyph = power.on_battery and icons.battery_levels[2] or icons.battery_ac,
        text = power.on_battery and "Charger disconnected" or "Charger connected",
    })
    -- Two brightness levels, not dimming. Keyboard backlight has no capability for it.
    mantle.brightness:invoke("set", power.on_battery and 10 or 100)
end)

mantle.battery:on_change(function(battery, previous)
    if previous == nil or not battery.present then
        return
    end
    -- `Charging` to `PendingCharge` proves only that charging stopped (limit, weak charger or thermal
    -- pause), so the card says what, not why. `PendingCharge` also follows `Discharging` briefly at
    -- every plug-in; gating on leaving `Charging` drops that, and a plug-in already at the limit.
    if battery.state == "PendingCharge" and previous.state == "Charging" then
        osd.show("battery", { glyph = icons.battery_ac, text = "Charging paused" })
    elseif previous.state == "Charging" and battery.state ~= "Charging"
        and (battery.state == "FullyCharged" or battery.percent >= 100) then
        osd.show("battery", { glyph = icons.battery_ac, text = "Fully charged" })
    end
    -- Downward crossings; unplugging again at 15% reports `low` again.
    local function crossed(percent)
        return util.battery_at_most(battery, percent) and not util.battery_at_most(previous, percent)
    end
    if crossed(thresholds.low) then
        notify("Low Battery", "Plug in soon!", false)
    end
    if crossed(thresholds.critical) then
        notify("Critical Battery", string.format("Automatic suspend at %d%%!", thresholds.suspend), true)
    end
    if crossed(thresholds.suspend) then
        process.detach("systemctl", { "suspend" })
    end
end)
