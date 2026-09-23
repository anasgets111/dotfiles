-- On/off switch for boolean writes, with the next capability snapshot as the only readback. Takes
-- the raw signal plus `read` (the caller knows which field), and hands `on_change` the flipped value.
--
-- The thumb slides on a spacer's eased `width`, because `align_h` would snap and `margin`'s edge table
-- cannot carry a tween.
local theme = require("config.theme")
local util = require("lib.util")

-- Everything derives from `control.xs`, so the switch scales with it.
local TRACK_HEIGHT = theme.control.xs
local TRACK_WIDTH = math.floor(TRACK_HEIGHT * 2.3 + 0.5)
local PAD = math.max(3, math.floor(TRACK_HEIGHT * 0.12 + 0.5))
local THUMB = TRACK_HEIGHT - 2 * PAD
local TRAVEL = TRACK_WIDTH - 2 * PAD - THUMB

return function(signal, read, on_change)
    local on = signal:map(function(value)
        return util.read_bool(value, read)
    end)
    return button {
        width = TRACK_WIDTH,
        height = TRACK_HEIGHT,
        on_click = function(_, mouse_button)
            if mouse_button == "left" then
                on_change(not util.read_bool(signal:get(), read))
            end
        end,
        children = { row {
            width = "Fill",
            height = "Fill",
            radius = TRACK_HEIGHT / 2,
            padding = PAD,
            -- Not green, which reads as a status light and adds a second accent to a mauve shell.
            background = on:map(function(checked)
                return checked and theme.with_opacity(theme.ACCENT, theme.opacity.full) or theme.GLASS_CONTROL
            end),
            -- The same hairline all other glass controls carry.
            border_width = theme.border_width,
            border_color = theme.GLASS_BORDER,
            animate = { background = { duration = theme.animation_ms, easing = "OutCubic" } },
            children = {
                rect {
                    width = on:map(function(checked)
                        return checked and TRAVEL or 0
                    end),
                    height = "Fill",
                    animate = { width = { duration = theme.animation_ms, easing = "OutQuad" } },
                },
                rect {
                    width = THUMB,
                    height = THUMB,
                    radius = THUMB / 2,
                    background = theme.FG,
                    -- Separates the thumb from a lit track it nearly matches.
                    border_width = theme.border_width,
                    border_color = theme.BORDER_SUBTLE,
                    align_v = "Center",
                },
            },
        } },
    }
end
