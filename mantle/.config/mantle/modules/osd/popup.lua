-- Bottom-centred glass card, two layouts chosen by the entry's `level`, fed by
-- `modules/osd/service.lua` and lingering so the fade-out plays before the unmap. One panel with
-- two switched rows: separate surfaces would overlap at the same position.
local theme = require("config.theme")
local util = require("lib.util")
local glyph = require("components.glyph")
local meter = require("components.meter")
local osd = require("modules.osd.service")

local SLIDE = theme.osd_slide
-- Exit is quicker. A card whose two seconds are up is not news.
local RISE_MS = theme.animation_ms
local FALL_MS = theme.animation_fast_ms

-- Both layouts inset their content by the same amount.
local PADDING = theme.spacing.xl

local entry_glyph = osd.entry:map(function(entry)
    return entry.glyph
end)
local entry_text = osd.entry:map(function(entry)
    return { { text = entry.text or "", bold = true } }
end)
-- The tile and the fill share one colour, so brightness is yellow end to end.
local level_color = osd.entry:map(function(entry)
    return entry.color or theme.ACCENT
end)

-- The glyph on a tinted tile, leading both layouts, so the card is one shape whose trailing half
-- changes. `align_*` places the box, not its child; a filling row centres the glyph inside.
local function tile()
    return rect {
        width = theme.osd_tile,
        height = theme.osd_tile,
        align_v = "Center",
        background = level_color:map(function(color)
            return theme.with_opacity(color, theme.opacity.light)
        end),
        border_width = theme.border_width,
        border_color = level_color:map(function(color)
            return theme.with_opacity(color, theme.opacity.medium)
        end),
        radius = theme.radius.md,
        children = { row {
            width = "Fill",
            height = "Fill",
            align_h = "Center",
            align_v = "Center",
            children = { glyph(entry_glyph, level_color, theme.font.xl, { align_v = "Center" }) },
        } },
    }
end

-- Slider layout: tile, filling track, bold readout.
local level_row = row {
    -- A track has no intrinsic width, so this layout states one. The toggle row measures instead;
    -- only one is visible, and an invisible child takes no space.
    width = theme.osd_width,
    height = "Fill",
    align_v = "Center",
    spacing = theme.spacing.lg,
    padding = { left = PADDING, right = PADDING },
    visible = osd.entry:map(function(entry)
        return entry.level ~= nil
    end),
    children = {
        tile(),
        -- A held volume key retargets every few frames: easing restarts from a standstill and
        -- trails the number, a spring keeps its velocity.
        meter(osd.entry, function(entry)
            return entry.level or 0
        end, level_color, theme.osd_track, { motion = theme.spring_tracking }),
        text {
            content = entry_text,
            foreground = theme.FG,
            font_size = theme.font.lg,
            width = theme.osd_value_width,
            text_align = "End",
            align_v = "Center",
        },
    },
}

-- Toggle layout: the tile and bold text beside it, centred.
local fact_row = row {
    -- No `width`: the card is these words. `theme.osd_toggle_min` is their floor; `align_h`
    -- centres the pair on a card sized by that floor rather than by the text.
    min_width = theme.osd_toggle_min,
    height = "Fill",
    align_h = "Center",
    align_v = "Center",
    spacing = theme.spacing.lg,
    -- Half of `spacing.lg` more each side, or the words reach the card edge and can run past it.
    padding = { left = PADDING + theme.spacing.lg / 2, right = PADDING + theme.spacing.lg / 2 },
    visible = osd.entry:map(function(entry)
        return entry.level == nil
    end),
    children = {
        tile(),
        -- No `width`, so it sizes to its own words and everything above measures it.
        text {
            content = entry_text,
            foreground = theme.FG,
            font_size = theme.font.lg,
            align_v = "Center",
        },
    },
}

return panel {
    id = "osd",
    -- One instance, on the output the compositor picks at each show.
    monitor = "Active",
    layer = "Overlay",
    -- No `left`/`right`: the protocol centres an axis with neither edge anchored and leaves its
    -- width measurable, where two anchored edges would span the output.
    anchor = { bottom = true },
    -- `SLIDE` taller and that much lower, so the rise stays inside the surface that clips it.
    margin = { bottom = theme.osd_bottom_margin - SLIDE },
    -- No `width`: the surface is the card, and the card is its content.
    height = theme.osd_height + SLIDE,
    -- Map until exit completes at `FALL_MS`; holding it for the entry's beat left an idle overlay.
    visible = util.linger(osd.visible, FALL_MS),
    child = column {
        height = theme.osd_height,
        -- `translate` is paint-only, so the card is solved once; easing `margin` re-ran the solver.
        translate = osd.visible:map(function(shown)
            return { y = shown and 0 or SLIDE }
        end),
        opacity = osd.visible:map(function(shown)
            return shown and 1 or 0
        end),
        -- A signal lets entry decelerate and exit accelerate with separate curves.
        animate = osd.visible:map(function(shown)
            local duration = shown and RISE_MS or FALL_MS
            return {
                opacity = { duration = duration, from = 0 },
                translate = {
                    duration = duration,
                    easing = shown and "OutCubic" or "InQuad",
                    from = { y = SLIDE },
                },
            }
        end),
        -- The same sheet and edge as a notification card: both float over wallpaper.
        background = theme.GLASS,
        blur = true,
        radius = theme.radius.md,
        border_width = theme.border_width_medium,
        border_color = theme.GLASS_BORDER,
        children = { level_row, fact_row },
    },
}
