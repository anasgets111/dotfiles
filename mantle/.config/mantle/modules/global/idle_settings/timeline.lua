-- One next-action line above a continuous timeline, with duration-weighted boundaries.
local theme = require("config.theme")
local cell = require("components.cell")
local meter = require("components.meter")
local idle = require("lib.idle")

---@param settings Signal<table> `store.idle` resolved through `idle.read`
return function(settings)
    local counting_down = computed({ settings, idle.schedule, idle.inhibited }, function(resolved, plan, held)
        return resolved.enabled and plan.total > 0 and not held
    end)
    local progress = computed({ idle.arming, idle.schedule, idle.armed_at, idle.fired_at },
        function(arming, plan, stamps, fired)
            local position = 1
            for index, entry in ipairs(plan.list) do
                if entry.key == arming.key then
                    position = index; break
                end
            end
            local entry = plan.list[position]
            if not entry then return { title = "", time = "", completed = 0, total = 0 } end
            local done = position == #plan.list and stamps[entry.key] ~= nil and fired[entry.key] == stamps[entry.key]
            local running = arming.key == entry.key
            local elapsed = running and math.max(0, math.min(entry.delay, arming.elapsed)) or 0
            local completed = done and plan.total or entry.at - entry.delay
            return {
                title = done and "Actions complete" or entry.title,
                time = done and "Done" or running and "in " .. idle.clock(entry.delay - elapsed)
                    or "after " .. idle.format(entry.delay),
                completed = completed / plan.total * 100,
                total = (completed + (done and 0 or elapsed)) / plan.total * 100,
            }
        end)

    return column {
        width = "Fill",
        spacing = theme.spacing.sm,
        visible = counting_down,
        children = {
            row { width = "Fill", spacing = theme.spacing.sm, align_v = "Center", children = {
                cell(progress:map(function(value) return value.title end), theme.FG, theme.font.sm, { width = "Fill" }),
                cell(progress:map(function(value) return value.time end), theme.DIM, theme.font.sm),
            } },
            rect {
                width = "Fill",
                height = theme.meter_height,
                radius = theme.meter_height / 2,
                clip = "Rounded",
                children = {
                    meter(progress, function(value) return value.total end, theme.ACCENT, nil, {
                        motion = progress:map(function(value)
                            return value.total > 0 and { duration = idle.TICK * 1000, easing = "Linear" }
                                or { duration = theme.animation_fast_ms, easing = "OutCubic" }
                        end),
                    }),
                    rect { width = progress:map(function(value) return string.format("%.3f%%", value.completed) end),
                        height = "Fill", background = theme.TEXT_MUTED },
                    row { width = "Fill", height = "Fill", children = idle.schedule:map(function(plan)
                        local marks = {}
                        for index, entry in ipairs(plan.list) do
                            marks[index] = rect {
                                width = index == #plan.list and "Fill" or string.format("%.6f%%", entry.delay / plan.total * 100),
                                height = "Fill",
                                children = index < #plan.list and { rect {
                                    width = theme.border_width_medium, height = "Fill", align_h = "End", background = theme.DIM,
                                } } or {},
                            }
                        end
                        return marks
                    end) },
                },
            },
        },
    }
end
