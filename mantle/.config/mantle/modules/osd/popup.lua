-- Bottom-centred glass card, two layouts chosen by the entry's `level`, fed by
-- `modules/osd/service.lua` and lingering so the fade-out plays before the unmap. One panel with
-- two switched rows: separate surfaces would overlap at the same position.
local theme = require("config.theme")
local util = require("lib.util")
local glyph = require("components.glyph")
local cell = require("components.cell")
local meter = require("components.meter")
local osd_tile = require("components.osd_tile")
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

-- The glyph on a tinted tile leads both layouts, so the card is one shape whose trailing half changes.
local function tile()
    return osd_tile(level_color, glyph(entry_glyph, level_color, theme.font.xl, { align = "center", align_v = "center" }))
end

-- Slider layout: tile, filling track, bold readout.
local level_row = row {
    -- A track has no intrinsic width, so this layout states one. The toggle row measures instead;
    -- only one is visible, and an invisible child takes no space.
    width = theme.osd_width,
    height = "fill",
    align_v = "center",
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
        cell(entry_text, theme.FG, theme.font.lg, {
            width = theme.osd_value_width, align = "end", align_v = "center",
        }),
    },
}

-- Toggle layout: the tile and bold text beside it, centred.
local fact_row = row {
    -- No `width`: the card is these words. `theme.osd_toggle_min` is their floor; `align_h`
    -- centres the pair on a card sized by that floor rather than by the text.
    min_width = theme.osd_toggle_min,
    height = "fill",
    align_h = "center",
    align_v = "center",
    spacing = theme.spacing.lg,
    -- Half of `spacing.lg` more each side, or the words reach the card edge and can run past it.
    padding = { left = PADDING + theme.spacing.lg / 2, right = PADDING + theme.spacing.lg / 2 },
    visible = osd.entry:map(function(entry)
        return entry.level == nil
    end),
    children = {
        tile(),
        -- No `width`, so it sizes to its own words and everything above measures it.
        cell(entry_text, theme.FG, theme.font.lg, { align_v = "center" }),
    },
}

return panel {
    id = "osd",
    -- One instance, on the output the compositor picks at each show.
    output = "active",
    layer = "overlay",
    -- Spans the output, so a new entry's width never resizes the surface: Hyprland draws one frame
    -- of a shrunk content-sized layer at its old centre, leaving a sliver past the card's edge. The
    -- empty sides claim no input.
    anchor = { bottom = true, left = true, right = true },
    -- `SLIDE` taller and that much lower, so the rise stays inside the surface that clips it.
    margin = { bottom = theme.osd_bottom_margin - SLIDE },
    height = theme.osd_height + SLIDE,
    -- Map until exit completes at `FALL_MS`; holding it for the entry's beat left an idle overlay.
    visible = util.linger(osd.visible, FALL_MS),
    child = column {
        -- No `width`: the card is its content.
        height = theme.osd_height,
        align_h = "center",
        -- Cuts the outgoing layout to the easing edge.
        clip = "rounded",
        -- `translate` is paint-only, so the card is solved once; easing `margin` re-ran the solver.
        translate = osd.visible:map(function(shown)
            return { y = shown and 0 or SLIDE }
        end),
        opacity = util.choose(osd.visible, 1, 0),
        -- A signal lets entry decelerate and exit accelerate with separate curves.
        animate = osd.visible:map(function(shown)
            local duration = shown and RISE_MS or FALL_MS
            return {
                opacity = { duration = duration, from = 0 },
                translate = {
                    duration = duration,
                    easing = shown and "out_cubic" or "in_quad",
                    from = { y = SLIDE },
                },
                -- A new entry eases the card to its new content width.
                width = { duration = theme.animation_ms, easing = "out_cubic" },
            }
        end),
        -- The same sheet and edge as a notification card: both float over wallpaper.
        background = theme.GLASS,
        behind_blur = true,
        radius = theme.radius.md,
        border_width = theme.border_width_medium,
        border_color = theme.GLASS_BORDER,
        children = { level_row, fact_row },
    },
}
