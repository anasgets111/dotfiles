local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local tooltip = require("components.tooltip")

local SLOT = "battery"

-- UPower's names. `pending_charge` is every plug-in, and its charge-end threshold disagrees with
-- sysfs here, so neither pending state claims a charge limit.
local BATTERY_PHRASES = {
    charging = "charging",
    discharging = "discharging",
    empty = "empty",
    fully_charged = "full",
    pending_charge = "waiting to charge",
    pending_discharge = "waiting to discharge",
}

-- `"2h 14m left"`, or `""`. UPower estimates one duration at a time, and neither while it learns
-- the rate, so an empty answer is ordinary in the first minute after a plug or a boot.
local function battery_eta(battery)
    local seconds = battery.time_to_empty or battery.time_to_full
    if not seconds then
        return ""
    end
    local suffix = battery.time_to_empty and "left" or "to full"
    local hours, minutes = seconds // 3600, seconds % 3600 // 60
    return hours > 0 and string.format("%dh %02dm %s", hours, minutes, suffix)
        or string.format("%dm %s", minutes, suffix)
end

-- Colour marks low charge while draining; the glyph shows cable state.
local function battery_color(battery)
    if battery == nil then
        return theme.DIM
    elseif util.battery_at_most(battery, util.battery_thresholds.critical) then
        return theme.RED
    elseif util.battery_at_most(battery, util.battery_thresholds.low) then
        return theme.PEACH
    end
    return theme.DIM
end

-- Two copies of the readout, one per ground: the fill's box clips its copy, so the contrast colour
-- flips at the fill edge, mid-glyph.
local ON_PILL = theme.text_contrast(theme.GLASS_CONTROL)
local ON_FILL = mantle.battery:map(function(battery)
    return theme.text_contrast(battery_color(battery))
end)

-- `pulse` marks a change and `computed` keeps only the rising edge, so unplugging does not flash.
-- The two-cycle flash lasts four `animation_fast_ms` in all.
local plugged = mantle.battery:map(function(battery)
    return battery ~= nil and battery.present and not util.battery_is_draining(battery.state)
end)
local plug_flash = computed({ pulse(plugged, theme.animation_fast_ms * 4), plugged }, function(fired, on)
    return fired and on
end)

-- `cell`, not `glyph`: `components/glyph.lua` forces the icon font and would mismatch the circles
-- beside it. Bold keeps dark ink readable over the opaque fill.
local GLYPH = util.bold(mantle.battery:map(util.battery_glyph))
local PERCENT = util.bold(util.label(mantle.battery, function(battery)
    return string.format("%d%%", battery.percent)
end))

local function readout(color)
    return row {
        width = "fill",
        height = "fill",
        align_h = "center",
        align_v = "center",
        spacing = theme.spacing.xs,
        children = {
            cell(GLYPH, color, theme.icon.md, { align_v = "center" }),
            cell(PERCENT, color, theme.font.sm, { align_v = "center" }),
        },
    }
end

local fill = rect {
    width = mantle.battery:map(function(battery)
        return string.format("%d%%", math.floor(math.max(0, math.min(100, (battery and battery.percent) or 0)) + 0.5))
    end),
    height = "fill",
    background = mantle.battery:map(battery_color),
    -- The level slides and the threshold colour fades; the entry's presence blinks the fill twice
    -- when the cable goes in.
    animate = plug_flash:map(function(flashing)
        return {
            width = { duration = theme.animation_ms, easing = "out_cubic" },
            background = { duration = theme.animation_ms, easing = "out_cubic" },
            opacity = flashing and {
                duration = theme.animation_fast_ms,
                loops = 2,
                keyframes = { 0, 0, { value = 1, duration = 0 }, 1 },
            } or nil,
        }
    end),
    -- A pill-wide box, so the copy inside the fill lines up with the one under it; the row alone
    -- would centre on the fill, since its `align_h` also places it.
    children = { rect { width = theme.battery_pill_width, height = "fill", children = { readout(ON_FILL) } } },
}

local battery_module = rect {
    width = theme.battery_pill_width,
    height = theme.item_height,
    align_v = "center",
    radius = theme.item_radius,
    clip = "rounded",
    background = theme.GLASS_CONTROL,
    border_width = theme.border_width,
    border_color = theme.GLASS_BORDER,
    hover = hover(SLOT),
    -- A desktop's UPower `DisplayDevice` answers `present = false`, and a percentage pill reporting
    -- no percentage is worse than none. `shown_when` also keeps it down until the first snapshot.
    visible = util.shown_when(mantle.battery, function(battery)
        return battery.present
    end),
    -- Pill copy first: the fill paints over it, and shows it again while the plug flash fades.
    children = { readout(ON_PILL), fill },
}

local battery_tooltip = tooltip({
    slot = SLOT,
    text = mantle.battery:map(function(battery)
        if battery == nil then
            return "Battery unavailable"
        elseif battery.state == "fully_charged" then
            return "Fully charged"
        end
        local eta = battery_eta(battery)
        if eta ~= "" then
            return eta
        end
        local phrase = BATTERY_PHRASES[battery.state] or "state unknown"
        return phrase:sub(1, 1):upper() .. phrase:sub(2)
    end),
    detail = util.label(mantle.power, function(power)
        local parts = {}
        if power.on_battery ~= nil then
            parts[#parts + 1] = power.on_battery and "Power: Battery" or "Power: AC"
        end
        if power.active_profile ~= nil then
            parts[#parts + 1] = "PPD: " .. power.active_profile
        end
        return #parts > 0 and table.concat(parts, " · ") or "No power detail"
    end),
})

return { indicator = battery_module, tooltips = { battery_tooltip } }
