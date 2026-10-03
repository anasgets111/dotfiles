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
        width = "fill",
        spacing = theme.spacing.sm,
        visible = counting_down,
        children = {
            row { width = "fill", spacing = theme.spacing.sm, align_v = "center", children = {
                cell(progress:map(function(value) return value.title end), theme.FG, theme.font.sm, { width = "fill" }),
                cell(progress:map(function(value) return value.time end), theme.DIM, theme.font.sm),
            } },
            rect {
                width = "fill",
                height = theme.meter_height,
                radius = theme.meter_height / 2,
                clip = "rounded",
                children = {
                    meter(progress, function(value) return value.total end, theme.ACCENT, nil, {
                        motion = progress:map(function(value)
                            return value.total > 0 and { duration = idle.TICK * 1000, easing = "linear" }
                                or { duration = theme.animation_fast_ms, easing = "out_cubic" }
                        end),
                    }),
                    rect { width = progress:map(function(value) return string.format("%.3f%%", value.completed) end),
                        height = "fill", background = theme.TEXT_MUTED },
                    row { width = "fill", height = "fill", children = idle.schedule:map(function(plan)
                        local marks = {}
                        for index, entry in ipairs(plan.list) do
                            marks[index] = rect {
                                width = index == #plan.list and "fill" or string.format("%.6f%%", entry.delay / plan.total * 100),
                                height = "fill",
                                children = index < #plan.list and { rect {
                                    width = theme.border_width_medium, height = "fill", align_h = "end", background = theme.DIM,
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
