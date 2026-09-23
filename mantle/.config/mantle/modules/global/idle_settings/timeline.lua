-- One chamber per runnable stage, filling over its own delay. Equal widths, not proportional ones:
-- a 30-second stage before a 15-minute one would be 3% of the card. Each prints its own delay; the
-- masthead keeps the running total. A hold or an empty plan replaces the timeline with a banner,
-- since a bar that can never fill says less than the reason.
local theme = require("config.theme")
local icons = require("config.icons")
local cell = require("components.cell")
local glyph = require("components.glyph")
local idle = require("lib.idle")

---@param settings Signal<table> `store.idle` resolved through `idle.read`
return function(settings)
    local counting_down = computed({ settings, idle.schedule, idle.inhibited }, function(resolved, plan, held)
        return resolved.enabled and plan.total > 0 and not held
    end)

    local function chamber(entry)
        -- Stages before the armed one are full and later ones empty. The armed one fills over its delay.
        local progress = computed({ idle.arming, idle.schedule }, function(arming, plan)
            local position, armed_position
            for index, item in ipairs(plan.list) do
                if item.key == entry.key then
                    position = index
                end
                if item.key == arming.key then
                    armed_position = index
                end
            end
            if position == nil or armed_position == nil or position > armed_position then
                return 0
            end
            if position < armed_position then
                return 1
            end
            return math.max(0, math.min(1, arming.elapsed / math.max(1, entry.delay)))
        end)
        -- Signals resolve before `width` is parsed, as in `components/meter.lua`.
        local fill = progress:map(function(fraction)
            return string.format("%d%%", math.floor(fraction * 100 + 0.5))
        end)
        local ink = progress:map(function(fraction)
            return fraction > 0 and theme.FG or theme.DIM
        end)
        return rect {
            width = "Fill",
            height = "Fill",
            children = {
                rect { width = fill, height = "Fill", background = theme.ACCENT_MEDIUM },
                row {
                    width = "Fill",
                    height = "Fill",
                    align_h = "Center",
                    align_v = "Center",
                    spacing = theme.spacing.xs,
                    children = {
                        glyph(entry.icon, ink, theme.icon.sm, { align_v = "Center" }),
                        cell(idle.format(entry.delay), ink, theme.font.xs, { align_v = "Center" }),
                    },
                },
            },
        }
    end

    local function banner(codepoint, content, tint, ground, visible)
        return row {
            width = "Fill",
            height = theme.idle_track_height,
            align_v = "Center",
            radius = theme.radius.sm,
            background = ground,
            spacing = theme.spacing.sm,
            padding = { left = theme.spacing.md, right = theme.spacing.md },
            visible = visible,
            children = {
                glyph(codepoint, tint, theme.icon.sm, { align_v = "Center" }),
                cell(content, tint, theme.font.xs, { width = "Fill", align_v = "Center" }),
            },
        }
    end

    return {
        -- `list` is `NodeBase`, not `BoxBase`: it places but does not paint, so `background`, `radius`
        -- and `clip` go on this parent. The types do not catch the mistake; the engine does, at runtime.
        row {
            width = "Fill",
            height = theme.idle_track_height,
            radius = theme.radius.sm,
            -- Square chambers butt together; the parent rounds the outer ends. `clip` is needed because
            -- children do not inherit the parent's arc.
            clip = "Rounded",
            background = theme.GLASS_CONTENT,
            visible = counting_down,
            children = {
                list {
                    width = "Fill",
                    height = "Fill",
                    direction = "Horizontal",
                    source = idle.schedule:map(function(plan)
                        return plan.list
                    end),
                    key = function(entry)
                        return entry.key
                    end,
                    itemfn = chamber,
                },
            },
        },
        banner(icons.awake, computed({ idle.reasons, idle.inhibited }, idle.held_text), theme.ACCENT,
            theme.ACCENT_SUBTLE, idle.inhibited),
        banner(icons.idle, settings:map(function(resolved)
            return resolved.enabled and "Nothing is scheduled on this profile" or "Automatic actions are off"
        end), theme.DIM, theme.GLASS_CONTENT, computed({ counting_down, idle.inhibited }, function(counting, held)
            return not counting and not held
        end)),
    }
end
