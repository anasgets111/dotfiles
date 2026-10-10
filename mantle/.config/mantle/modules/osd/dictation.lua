-- Voxtype's dictation card, the OSD's sibling: the same tile, track and readout slots, holding a red
-- mic, the live mic level and the elapsed time while it records, a spinner while it transcribes. Sits
-- just above the OSD card, so a volume key while dictating shows both.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local glyph = require("components.glyph")
local spinner = require("components.spinner")
local osd_tile = require("components.osd_tile")
local dictation = require("lib.dictation")

local SLIDE = theme.osd_slide
local BAR = theme.spacing.xs
local BAR_HEIGHT = theme.icon.lg

local bars = {}
for index = 1, dictation.BARS do
    bars[index] = rect {
        width = BAR,
        height = BAR_HEIGHT,
        align_v = "center",
        radius = BAR / 2,
        background = theme.RED,
        -- Paint-only, so 30 frames a second never re-run layout. A silent bar stays a dot.
        scale = dictation.levels:map(function(levels)
            return { y = math.max(BAR / BAR_HEIGHT, levels[index] or 0) }
        end),
    }
end

local recording_view = {
    osd_tile(theme.RED, glyph(icons.mic_on, theme.RED, theme.font.xl, { align = "center", align_v = "center" })),
    row { width = "fill", align_h = "center", align_v = "center", spacing = BAR / 2, children = bars },
    -- Monospaced, so the readout keeps its width as the seconds turn.
    cell(dictation.elapsed_text, theme.FG, theme.font.lg, {
        bold = true, width = theme.osd_value_width, align = "end", align_v = "center", font = theme.mono_font,
    }),
}

local transcribing_view = {
    osd_tile(theme.ACCENT, spinner(dictation.active, theme.font.xl, theme.ACCENT)),
    cell("Transcribing…", theme.FG, theme.font.lg, { bold = true, width = "fill", align_v = "center" }),
}

return panel {
    id = "dictation",
    output = "active",
    layer = "overlay",
    anchor = { bottom = true, left = true, right = true },
    margin = { bottom = theme.osd_bottom_margin + theme.osd_height + theme.spacing.md - SLIDE },
    height = theme.osd_height + SLIDE,
    visible = util.linger(dictation.active, theme.animation_fast_ms),
    child = row {
        width = theme.osd_width,
        height = theme.osd_height,
        align_h = "center",
        align_v = "center",
        spacing = theme.spacing.lg,
        padding = { left = theme.spacing.xl, right = theme.spacing.xl },
        children = dictation.phase:map(function(phase)
            return phase == "recording" and recording_view or transcribing_view
        end),
        translate = dictation.active:map(function(shown)
            return { y = shown and 0 or SLIDE }
        end),
        opacity = util.choose(dictation.active, 1, 0),
        animate = dictation.active:map(function(shown)
            local duration = shown and theme.animation_ms or theme.animation_fast_ms
            return {
                opacity = { duration = duration, from = 0 },
                translate = { duration = duration, easing = shown and "out_cubic" or "in_quad", from = { y = SLIDE } },
            }
        end),
        background = theme.GLASS,
        behind_blur = true,
        radius = theme.radius.md,
        border_width = theme.border_width_medium,
        border_color = theme.GLASS_BORDER,
    },
}
