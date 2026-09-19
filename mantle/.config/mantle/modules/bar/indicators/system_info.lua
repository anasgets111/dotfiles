-- A full-width "System" button that collapses to readouts and opens into metric tiles.
--
-- Though this file lives under `Indicators/`, it is used from
-- `modules/bar/panels/notification_history.lua`.
--
-- ## What is missing, and why it is not a bug
--
-- Only `cpu_percent`, `ram_percent`, `swap_percent`, `temp_cores` and `temp_gpu` are exposed, so
-- the GPU usage tile, per-disk rows, and uptime/boot footer are absent rather than faked. Their
-- space holds swap under memory and the GPU's temperature where the GPU tile would sit.
--
-- ## A factory, not a node
--
-- Each instance owns its `expanded` flag, so the same widget in two places does not open in both.
-- Here the caller names the instance.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local glyph = require("components.glyph")
local meter = require("components.meter")
local panel_card = require("components.panel_card")
local expander_header = require("components.expander_header")

-- `sysinfo`'s three pollers start dormant until configured; without this, the readouts
-- stay at pre-first-sample `0%`. Configure here because this is the only module reading them.
--
-- CPU every 2s and RAM every 5s, about as slow as a readout can tick before it reads as frozen.
-- Temperatures ride with RAM: they are a tile's second line, not a number anyone watches move, and
-- the hwmon pass is one read of both `temp_cores` and `temp_gpu`.
--
-- There is no ref-counting control here: `configure` sets an interval and zero stops a poller for
-- everyone. The choice is polling always or never; two file reads every couple of seconds is the
-- cheaper mistake.
mantle.sysinfo:invoke("configure", { cpu_interval = 2, ram_interval = 5, temp_interval = 5 })

-- Red past 90%, peach past 75%, and the readout's own colour below that. `sysinfo` pushes whole
-- percents, so the thresholds are 90 and 75 rather than 0.9 and 0.75.
local function status_color(percent, fallback)
    if percent >= 90 then
        return theme.RED
    elseif percent >= 75 then
        return theme.PEACH
    end
    return fallback
end

local function percent_of(state_value, field)
    return (state_value and state_value[field]) or 0
end

-- `SysinfoState` carries no GPU utilization, so the tile's meter plots temperature over the span
-- between an idle and a throttling card rather than treating Celsius as a percentage: 30°C reads
-- empty, 90°C full.
-- ponytail: one fixed span for every card. A GPU that idles hot or throttles early reads off by a
-- band; take the floor and ceiling from `hwmon`'s own trip points if one ever does.
local GPU_FLOOR = 30
local GPU_CEILING = 90

local function gpu_temp(s)
    return (s and s.temp_gpu) or 0
end

-- Bands named by `gpu_caption` below, so the colour and the words never disagree.
local gpu_color = mantle.sysinfo:map(function(s)
    local celsius = gpu_temp(s)
    if celsius >= 85 then
        return theme.RED
    elseif celsius >= 70 then
        return theme.PEACH
    end
    return theme.GREEN
end)

local function tint(field, fallback)
    return mantle.sysinfo:map(function(s)
        return status_color(percent_of(s, field), fallback)
    end)
end

-- `temp_cores` is one entry per hwmon sensor, not per core. The hottest sensor is the honest
-- stand-in: a mean over sensors that may include a chipset probe reads cooler than any core
-- actually is.
local function hottest_core(s)
    local hottest = 0
    for _, celsius in ipairs((s and s.temp_cores) or {}) do
        if celsius > hottest then
            hottest = celsius
        end
    end
    return hottest
end

-- Uses the glass content tone behind a glass border hairline -- not `panel_card`'s own default,
-- which is the opaque ground a whole panel body sits on.
local function tile(children, opts)
    opts = opts or {}
    return panel_card(children, {
        width = "Fill",
        visible = opts.visible,
        background = theme.GLASS_CONTENT,
        radius = theme.radius.lg,
        border_width = theme.border_width,
        border_color = theme.GLASS_BORDER,
        spacing = theme.spacing.xs,
        padding = theme.spacing.sm,
    })
end

local function readout(read)
    return util.bold(util.label(mantle.sysinfo, read))
end

local function metric_tile(codepoint, label, field, accent, detail)
    local t = tint(field, accent)
    return tile {
        row {
            width = "Fill",
            align_v = "Center",
            spacing = theme.spacing.xs,
            children = {
                glyph(codepoint, accent, theme.icon.sm, { align_v = "Center" }),
                cell({ { text = label, bold = true } }, theme.FG, theme.font.sm, {
                    width = "Fill",
                    align_v = "Center",
                }),
                cell(readout(function(s)
                    return string.format("%d%%", percent_of(s, field))
                end), t, theme.font.md, { align_v = "Center" }),
            },
        },
        -- The meter's fill takes the same tint, so a track turning red is the same warning as its
        -- number turning red.
        meter(mantle.sysinfo, function(s)
            return percent_of(s, field)
        end, t, "Fill", theme.spacing.xs),
        cell(detail, theme.DIM, theme.font.xs, { width = "Fill" }),
    }
end

-- One collapsed readout: `CPU 12%`, bold and tinted.
local function summary_readout(label, field, accent)
    return cell(readout(function(s)
        return string.format("%s %d%%", label, percent_of(s, field))
    end), tint(field, accent), theme.font.xs, { align_v = "Center" })
end

---@param id string Names this instance's `expanded` state and its hover slot.
return function(id)
    local expanded = state("sysinfo_expanded_" .. id, false)
    -- The collapsed summary is the filling child, right-aligned inside it, so the chevron stays at
    -- the far edge whether or not the readouts are showing.
    local head = expander_header(expanded, "sysinfo-" .. id, "System", row {
        width = "Fill",
        align_h = "End",
        align_v = "Center",
        spacing = theme.spacing.sm,
        visible = expanded:map(function(open)
            return not open
        end),
        children = {
            summary_readout("CPU", "cpu_percent", theme.ACCENT),
            summary_readout("RAM", "ram_percent", theme.GREEN),
            summary_readout("SWAP", "swap_percent", theme.PEACH),
            cell(readout(function(s)
                local t = (s and s.temp_gpu) or -1
                return t > 0 and string.format("GPU %d°C", t) or ""
            end), gpu_color, theme.font.xs, {
                align_v = "Center",
                visible = util.shown_when(mantle.sysinfo, function(s)
                    return (s.temp_gpu or -1) > 0
                end),
            }),
        },
    })

    -- `visible` is the shape this config already uses for expansion
    -- (`components/notification_card.lua`), and an invisible node takes no size or spacing gap, so
    -- the card retracts cleanly without a clip.
    local details = column {
        width = "Fill",
        spacing = theme.spacing.sm,
        visible = expanded,
        children = {
            row {
                width = "Fill",
                spacing = theme.spacing.sm,
                children = {
                    metric_tile(icons.cpu, "CPU", "cpu_percent", theme.ACCENT, util.label(mantle.sysinfo, function(s)
                        local celsius = hottest_core(s)
                        return celsius > 0 and string.format("%d°C", celsius) or "No temperature"
                    end)),
                    -- `sysinfo` pushes percentages only. Swap is the memory fact it does push, and
                    -- it has no tile of its own.
                    metric_tile(icons.ram, "Memory", "ram_percent", theme.GREEN, util.label(mantle.sysinfo, function(s)
                        local swap = percent_of(s, "swap_percent")
                        return swap > 0 and string.format("Swap %d%%", swap) or "No swap in use"
                    end)),
                },
            },
            -- The GPU tile spans both columns, matching CPU and Memory tile structure.
            tile({
                row {
                    width = "Fill",
                    align_v = "Center",
                    spacing = theme.spacing.xs,
                    children = {
                        glyph(icons.gpu, gpu_color, theme.icon.sm, { align_v = "Center" }),
                        cell({ { text = "GPU", bold = true } }, theme.FG, theme.font.sm, {
                            width = "Fill",
                            align_v = "Center",
                        }),
                        cell(readout(function(s)
                            return string.format("%d°C", gpu_temp(s))
                        end), gpu_color, theme.font.md, { align_v = "Center" }),
                    },
                },
                meter(mantle.sysinfo, function(s)
                    local filled = (gpu_temp(s) - GPU_FLOOR) * 100 // (GPU_CEILING - GPU_FLOOR)
                    return math.min(100, math.max(0, filled))
                end, gpu_color, "Fill", theme.spacing.xs),
                cell(util.label(mantle.sysinfo, function(s)
                    local celsius = gpu_temp(s)
                    if celsius >= 85 then
                        return "Thermal throttle warning"
                    elseif celsius >= 70 then
                        return "Heavy thermal load"
                    end
                    return "Nominal temperature"
                end), theme.DIM, theme.font.xs, { width = "Fill" }),
            }, {
                visible = util.shown_when(mantle.sysinfo, function(s)
                    return (s.temp_gpu or -1) > 0
                end),
            }),
        },
    }

    return column {
        width = "Fill",
        spacing = theme.spacing.sm,
        children = { head, details },
    }
end
