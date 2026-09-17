-- One equal-width chamber per runnable stage fills over its own window and shows how close the
-- screen is to going dark.
--
-- Chambers are not delay-proportional: with a 30-second stage followed by 15 minutes, the first
-- would be 3% of the card and its glyph would not fit. Each prints its delay, so proportions are
-- readable but not to scale.
--
-- A chamber prints its stage delay, not the running total. The masthead keeps the total by
-- counting down to the next stage.
--
-- Replace the timeline, rather than dim it, when a hold blocks countdown or no action is scheduled;
-- a bar that can never fill is worse than the reason.
local theme = require("config.theme")
local icons = require("config.icons")
local cell = require("components.cell")
local glyph = require("components.glyph")
local idle = require("lib.idle")

---@param settings Signal<table> `store.idle` resolved through `idle.read`
return function(settings)
    local plan_now = idle.schedule

    local counting_down = computed({ settings, plan_now, idle.inhibited }, function(resolved, plan, held)
        return resolved.enabled and plan.total > 0 and not held
    end)

    -- Chamber state comes from `idle.arming`: earlier stages are full, later stages are empty, and
    -- the stage fills over its delay.
    local function chamber_progress(entry)
        return computed({ idle.arming, plan_now }, function(arming, plan)
            local position, armed_position
            for index, item in ipairs(plan.list) do
                if item.key == entry.key then
                    position = index
                end
                if item.key == arming.key then
                    armed_position = index
                end
            end
            if position == nil or armed_position == nil then
                return 0
            end
            if position < armed_position then
                return 1
            end
            if position > armed_position then
                return 0
            end
            return math.max(0, math.min(1, arming.elapsed / math.max(1, entry.delay)))
        end)
    end

    local function chamber(entry)
        local progress = chamber_progress(entry)
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

    -- Wrap the `list` in a `row`: `list` is `NodeBase`, not `BoxBase` (`lua-meta/nodes.lua`,
    -- `nodes.rs` `BOX_KINDS`), so it places but does not paint. Put `background`, `radius`, and `clip`
    -- on the parent. `just types` misses unknown table keys; the engine rejects the re-resolve at
    -- runtime.
    local timeline = row {
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
                source = plan_now:map(function(plan)
                    return plan.list
                end),
                key = function(entry)
                    return entry.key
                end,
                itemfn = chamber,
            },
        },
    }

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

    local held_banner = banner(
        icons.awake,
        computed({ idle.reasons, idle.inhibited }, idle.held_text),
        theme.ACCENT,
        theme.ACCENT_SUBTLE,
        idle.inhibited
    )

    local paused_banner = banner(
        icons.idle,
        settings:map(function(resolved)
            return resolved.enabled and "Nothing is scheduled on this profile" or "Automatic actions are off"
        end),
        theme.DIM,
        theme.GLASS_CONTENT,
        computed({ counting_down, idle.inhibited }, function(counting, held)
            return not counting and not held
        end)
    )

    return timeline, held_banner, paused_banner
end
