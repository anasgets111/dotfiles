-- A left-to-right fill, five-level glyph, and percentage. The only pill on this bar carries a
-- number.
--
-- The percentage-sized `rect` applies `components/meter.lua`'s stacking trick to the whole control.
-- It is not a 6px bar. A `rect` has no main axis, so children stack at its origin.
--
-- `clip = "Rounded"` on the pill cuts the square-cornered fill to its arc; the engine clips only
-- to rectangles, so the radius has to sit on the pill, not the fill.
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local tooltip = require("components.tooltip")

local SLOT = "battery"

-- Only the draining check changes colour. The glyph shows cable state; gating colour on both would
-- put a plugged-in battery at 90% in the same green.
local function battery_color(b)
    if b == nil then
        return theme.DIM
    end
    -- Warn only while draining. Red at 14% on the charger is wrong.
    if util.battery_at_most(b, util.battery_thresholds.critical) then
        return theme.RED
    end
    if util.battery_at_most(b, util.battery_thresholds.low) then
        return theme.PEACH
    end
    -- The accent color, not green. Green would add a fourth state.
    return theme.ACCENT
end

-- Two copies of the readout, one per ground: the fill's box clips its copy, so the contrast colour
-- flips at the fill edge, mid-glyph.
local ON_PILL = theme.text_contrast(theme.GLASS_CONTROL)
local ON_FILL = mantle.battery:map(function(b)
    return theme.text_contrast(battery_color(b))
end)

-- `pulse` marks a change and `computed` keeps only the rising edge, so unplugging does not flash.
-- The two-cycle flash lasts four `animation_fast_ms` in all.
local plugged = mantle.battery:map(function(b)
    return b ~= nil and b.present and not util.battery_is_draining(b.state)
end)
local plug_flash = computed({ pulse(plugged, theme.animation_fast_ms * 4), plugged }, function(fired, on)
    return fired and on
end)

-- Use `cell`, not `glyph`: both lines are in the text font; `components/glyph.lua` would force the
-- icon font and mismatch the circles beside it. Both are bold, which keeps dark ink readable over
-- the opaque accent fill.
local GLYPH = mantle.battery:map(function(b)
    return { { text = util.battery_glyph(b), bold = true } }
end)
local PERCENT = util.bold(util.label(mantle.battery, function(b)
    return string.format("%d%%", b.percent)
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
    width = mantle.battery:map(function(b)
        if b == nil then
            return "0%"
        end
        return string.format("%d%%", math.floor(math.max(0, math.min(100, b.percent or 0)) + 0.5))
    end),
    height = "Fill",
    background = mantle.battery:map(battery_color),
    -- The level slides and threshold colour fades, while the fill blinks twice when the
    -- cable goes in. The entry's presence runs the sequence.
    animate = plug_flash:map(function(flashing)
        local eases = {
            width = theme.animation_ms,
            background = { duration = theme.animation_ms, easing = "OutCubic" },
        }
        if flashing then
            eases.opacity = {
                duration = theme.animation_fast_ms,
                loops = 2,
                keyframes = { 0, 0, { value = 1, duration = 0 }, 1 },
            }
        end
        return eases
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
    -- A desktop's UPower `DisplayDevice` answers `present = false`; unguarded, that shows a dim AC
    -- glyph and the word "ac" -- a percentage pill reporting that there is no percentage. Hidden
    -- nodes take no width and no spacing gap, so the zone closes up, and `shown_when` keeps it down
    -- until the first snapshot rather than flashing an empty pill.
    visible = util.shown_when(mantle.battery, function(b)
        return b.present
    end),
    -- Pill copy first: the fill paints over it, and shows it again while the plug flash fades.
    children = { readout(ON_PILL, "Fill"), fill },
}

local battery_tooltip = tooltip({
    id = "battery_tooltip",
    slot = SLOT,
    children = {
        cell(util.label(mantle.battery, function(b)
            return string.format("%d%% %s%s", b.percent, util.battery_phrase(b.state), util.battery_eta(b))
        end), theme.FG, theme.font.sm),
        cell(util.label(mantle.power, function(p)
            local parts = {}
            if p.on_battery ~= nil then
                parts[#parts + 1] = p.on_battery and "On battery" or "On AC"
            end
            if p.energy_rate ~= nil then
                parts[#parts + 1] = string.format("%.1f W", p.energy_rate)
            end
            if p.active_profile ~= nil then
                parts[#parts + 1] = p.active_profile
            end
            return #parts > 0 and table.concat(parts, ", ") or "No power detail"
        end), theme.DIM, theme.font.xs),
    },
})

return { indicator = battery_module, tooltip = battery_tooltip }
