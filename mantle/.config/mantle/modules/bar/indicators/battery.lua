local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local tooltip = require("components.tooltip")

local SLOT = "battery"

-- Colour follows the draining check alone; the glyph shows cable state. Accent, not green, which
-- would add a fourth state.
local function battery_color(battery)
    if battery == nil then
        return theme.DIM
    elseif util.battery_at_most(battery, util.battery_thresholds.critical) then
        return theme.RED
    elseif util.battery_at_most(battery, util.battery_thresholds.low) then
        return theme.PEACH
    end
    return theme.ACCENT
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
-- beside it. Bold keeps dark ink readable over the opaque accent fill.
local GLYPH = util.bold(mantle.battery:map(util.battery_glyph))
local PERCENT = util.bold(util.label(mantle.battery, function(battery)
    return string.format("%d%%", battery.percent)
end))

-- `width` is the pill's, so the copy inside the fill lines up with the one under it.
local function readout(color, width)
    return row {
        width = width,
        height = "Fill",
        align_h = "Center",
        align_v = "Center",
        spacing = theme.spacing.xs,
        children = {
            cell(GLYPH, color, theme.icon.md, { align_v = "Center" }),
            cell(PERCENT, color, theme.font.sm, { align_v = "Center" }),
        },
    }
end

local fill = rect {
    width = mantle.battery:map(function(battery)
        return string.format("%d%%", math.floor(math.max(0, math.min(100, (battery and battery.percent) or 0)) + 0.5))
    end),
    height = "Fill",
    background = mantle.battery:map(battery_color),
    -- The level slides and the threshold colour fades; the entry's presence blinks the fill twice
    -- when the cable goes in.
    animate = plug_flash:map(function(flashing)
        return {
            width = { duration = theme.animation_ms, easing = "OutCubic" },
            background = { duration = theme.animation_ms, easing = "OutCubic" },
            opacity = flashing and {
                duration = theme.animation_fast_ms,
                loops = 2,
                keyframes = { 0, 0, { value = 1, duration = 0 }, 1 },
            } or nil,
        }
    end),
    children = { readout(ON_FILL, theme.battery_pill_width) },
}

local battery_module = rect {
    width = theme.battery_pill_width,
    height = theme.item_height,
    align_v = "Center",
    radius = theme.item_radius,
    clip = "Rounded",
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
    children = { readout(ON_PILL, "Fill"), fill },
}

local battery_tooltip = tooltip({
    id = "battery_tooltip",
    slot = SLOT,
    text = mantle.battery:map(function(battery)
        if battery == nil then
            return "Battery unavailable"
        elseif battery.state == "FullyCharged" then
            return "Fully charged"
        end
        local eta = util.battery_eta(battery)
        if eta ~= "" then
            return eta:sub(3)
        end
        local phrase = util.battery_phrase(battery.state)
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

return { indicator = battery_module, tooltip = battery_tooltip }
