-- Bottom-centred glass card, two layouts chosen by the entry's `level`, fed by
-- `modules/osd/service.lua` and lingering so the fade-out plays before the unmap. One panel with
-- two switched rows: separate surfaces would overlap at the same position.
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")
local glyph = require("components.glyph")
local meter = require("components.meter")
local osd = require("modules.osd.service")

-- A short settle, not a swoop: this card acknowledges a key already pressed, dozens of times a day.
local SLIDE = theme.s(12, 8)
-- Exit is quicker: a card whose two seconds are up is not news.
local RISE_MS = theme.animation_ms
local FALL_MS = theme.animation_fast_ms

-- Both layouts inset their content by the same amount.
local PADDING = theme.spacing.xl

-- Half of `theme.spacing.lg` each side, so a text-tight card is not cramped but stays centred.
local SLACK = theme.spacing.lg / 2

local function read(field)
    return osd.entry:map(function(e)
        return e[field]
    end)
end

local function bold(field)
    return osd.entry:map(function(e)
        return { { text = e[field] or "", bold = true } }
    end)
end

-- Slider layout: accent glyph, filling track, bold readout.
local level_row = row {
    -- A track has no intrinsic width, so this layout states one. The toggle row measures instead;
    -- only one is visible, and an invisible child takes no space.
    width = theme.osd_width,
    height = "Fill",
    align_v = "Center",
    spacing = theme.spacing.lg,
    padding = { left = PADDING, right = PADDING },
    visible = osd.entry:map(function(e)
        return e.level ~= nil
    end),
    children = {
        glyph(read("glyph"), theme.ACCENT, theme.font.xxl, { align_v = "Center" }),
        -- A held volume key retargets every few frames: easing restarts from a standstill and
        -- trails the number, a spring keeps its velocity.
        meter(osd.entry, function(e)
            return e.level or 0
        end, osd.entry:map(function(e)
            return e.color or theme.ACCENT
        end), "Fill", theme.osd_track, { motion = theme.spring_tracking }),
        text {
            content = bold("text"),
            foreground = theme.FG,
            font_size = theme.font.lg,
            width = theme.s(52, 40),
            text_align = "End",
            align_v = "Center",
        },
    },
}

-- Toggle layout: glyph in an accent-tinted tile and bold text beside it, centered.
local fact_row = row {
    -- No `width`: the card is these words. `theme.osd_toggle_min` is their floor; `align_h`
    -- centres the pair on a card sized by that floor rather than by the text.
    min_width = theme.osd_toggle_min,
    height = "Fill",
    align_h = "Center",
    align_v = "Center",
    spacing = theme.spacing.lg,
    -- Without it, the words reach the card edge and can run past it.
    padding = { left = PADDING + SLACK, right = PADDING + SLACK },
    visible = osd.entry:map(function(e)
        return e.level == nil
    end),
    children = {
        -- `align_*` places the box, not its child; a filling row centers the glyph inside the tile.
        rect {
            width = theme.osd_tile,
            height = theme.osd_tile,
            align_v = "Center",
            background = theme.ACCENT_LIGHT,
            border_width = theme.border_width,
            border_color = theme.ACCENT_MEDIUM,
            radius = theme.radius.md,
            children = { row {
                width = "Fill",
                height = "Fill",
                align_h = "Center",
                align_v = "Center",
                children = { glyph(read("glyph"), theme.ACCENT, theme.font.xl, { align_v = "Center" }) },
            } },
        },
        -- No `width`, so it sizes to its own words and everything above measures it.
        text {
            content = bold("text"),
            foreground = theme.FG,
            font_size = theme.font.lg,
            align_v = "Center",
        },
    },
}

return panel {
    id = "osd",
    layer = "Overlay",
    -- No `left`/`right`: the protocol centres an axis with neither edge anchored and leaves its
    -- width measurable, where two anchored edges would span the output.
    anchor = { bottom = true },
    -- `SLIDE` taller and that much lower, so the rise stays inside the surface that clips it.
    margin = { bottom = theme.s(132, 90) - SLIDE },
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
        background = theme.GLASS,
        blur = true,
        radius = theme.radius.md,
        border_width = theme.border_width,
        border_color = theme.BORDER,
        children = { level_row, fact_row },
    },
}
