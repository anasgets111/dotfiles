-- A full-width "System" button that collapses to readouts and opens into metric tiles. It lives
-- under `indicators/` but is used from `modules/bar/panels/notification_history.lua`.
--
-- `sysinfo` exposes only `cpu_percent`, `ram_percent`, `swap_percent`, `temp_cores` and `temp_gpu`,
-- so GPU usage, per-disk rows and an uptime footer are absent rather than faked; swap sits under
-- memory and the GPU's temperature where its usage tile would.
--
-- A factory, not a node: each instance owns its `expanded` flag, named by the caller, so the same
-- widget in two places does not open in both.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local glyph = require("components.glyph")
local meter = require("components.meter")
local panel_card = require("components.panel_card")
local expander_header = require("components.expander_header")

-- `sysinfo`'s pollers stay dormant until configured, and this is the only module reading them. CPU
-- every 2s and RAM every 5s is about as slow as a readout can tick before it reads as frozen;
-- temperatures ride with RAM in the same hwmon pass. `configure` has no ref-counting, so the choice
-- is polling always or never.
mantle.sysinfo:invoke("configure", { cpu_interval = 2, ram_interval = 5, temp_interval = 5 })

local function percent_of(sysinfo, field)
    return (sysinfo and sysinfo[field]) or 0
end

-- `SysinfoState` carries no GPU utilization, so the meter plots temperature over an idle-to-
-- throttling span: 30°C empty, 90°C full.
-- ponytail: one fixed span for every card. Take the floor and ceiling from `hwmon`'s own trip
-- points if a card ever idles hot or throttles early.
local GPU_FLOOR = 30
local GPU_CEILING = 90

local function gpu_temp(sysinfo)
    return (sysinfo and sysinfo.temp_gpu) or 0
end

-- One set of bands for the GPU's colour and caption, so the two never disagree.
local function gpu_band(sysinfo)
    local celsius = gpu_temp(sysinfo)
    return celsius >= 85 and 3 or celsius >= 70 and 2 or 1
end
local gpu_color = mantle.sysinfo:map(function(sysinfo)
    return ({ theme.GREEN, theme.PEACH, theme.RED })[gpu_band(sysinfo)]
end)
local has_gpu = util.shown_when(mantle.sysinfo, function(sysinfo)
    return (sysinfo.temp_gpu or -1) > 0
end)

-- Red from 90%, peach from 75%, else `fallback`. `sysinfo` pushes whole percents.
local function tint(field, fallback)
    return mantle.sysinfo:map(function(sysinfo)
        local percent = percent_of(sysinfo, field)
        return percent >= 90 and theme.RED or percent >= 75 and theme.PEACH or fallback
    end)
end

-- `panel_card`'s glass content ground behind a hairline.
local function tile(children, visible)
    return panel_card(children, {
        width = "Fill",
        visible = visible,
        border_width = theme.border_width,
        border_color = theme.GLASS_BORDER,
        padding = theme.spacing.sm,
    })
end

local function readout(read)
    return util.bold(util.label(mantle.sysinfo, read))
end

-- Glyph, label, and the big number; the GPU tile tints its glyph live, the metric tiles do not.
local function tile_header(codepoint, glyph_color, label, value, value_color)
    return row {
        width = "Fill",
        align_v = "Center",
        spacing = theme.spacing.xs,
        children = {
            glyph(codepoint, glyph_color, theme.icon.sm, { align_v = "Center" }),
            cell(util.bold(label), theme.FG, theme.font.sm, { width = "Fill", align_v = "Center" }),
            cell(value, value_color, theme.font.md, { align_v = "Center" }),
        },
    }
end

local function metric_tile(codepoint, label, field, accent, detail)
    local color = tint(field, accent)
    return tile {
        tile_header(codepoint, accent, label, readout(function(sysinfo)
            return string.format("%d%%", percent_of(sysinfo, field))
        end), color),
        -- The meter's fill takes the same tint, so a track turning red is the same warning as its
        -- number turning red.
        meter(mantle.sysinfo, function(sysinfo)
            return percent_of(sysinfo, field)
        end, color, theme.spacing.xs),
        cell(detail, theme.DIM, theme.font.xs, { width = "Fill" }),
    }
end

-- One collapsed readout: `CPU 12%`, bold and tinted.
local function summary_readout(label, field, accent)
    return cell(readout(function(sysinfo)
        return string.format("%s %d%%", label, percent_of(sysinfo, field))
    end), tint(field, accent), theme.font.xs, { align_v = "Center" })
end

---@param id string Names this instance's `expanded` state and its hover slot.
return function(id)
    local expanded = state("sysinfo_expanded_" .. id, false)
    -- The summary fills, right-aligned, so the chevron keeps the far edge either way.
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
            cell(readout(function(sysinfo)
                return gpu_temp(sysinfo) > 0 and string.format("GPU %d°C", gpu_temp(sysinfo)) or ""
            end), gpu_color, theme.font.xs, { align_v = "Center", visible = has_gpu }),
        },
    })

    -- An invisible node takes no size or spacing gap, so the card retracts cleanly without a clip.
    local details = column {
        width = "Fill",
        spacing = theme.spacing.sm,
        visible = expanded,
        children = {
            row {
                width = "Fill",
                spacing = theme.spacing.sm,
                children = {
                    metric_tile(icons.cpu, "CPU", "cpu_percent", theme.ACCENT, util.label(mantle.sysinfo, function(
                        sysinfo)
                        -- One entry per hwmon sensor, not per core; a mean over them, a chipset
                        -- probe included, reads cooler than any core.
                        local celsius = math.max(0, table.unpack(sysinfo.temp_cores or {}))
                        return celsius > 0 and string.format("%d°C", celsius) or "No temperature"
                    end)),
                    -- `sysinfo` pushes percentages only, so swap is the memory detail. It has no
                    -- tile of its own.
                    metric_tile(icons.ram, "Memory", "ram_percent", theme.GREEN, util.label(mantle.sysinfo, function(
                        sysinfo)
                        local swap = percent_of(sysinfo, "swap_percent")
                        return swap > 0 and string.format("Swap %d%%", swap) or "No swap in use"
                    end)),
                },
            },
            -- The GPU tile spans both columns.
            tile({
                tile_header(icons.gpu, gpu_color, "GPU", readout(function(sysinfo)
                    return string.format("%d°C", gpu_temp(sysinfo))
                end), gpu_color),
                meter(mantle.sysinfo, function(sysinfo)
                    local filled = (gpu_temp(sysinfo) - GPU_FLOOR) * 100 // (GPU_CEILING - GPU_FLOOR)
                    return math.min(100, math.max(0, filled))
                end, gpu_color, theme.spacing.xs),
                cell(util.label(mantle.sysinfo, function(sysinfo)
                    return ({ "Nominal temperature", "Heavy thermal load", "Thermal throttle warning" })
                        [gpu_band(sysinfo)]
                end), theme.DIM, theme.font.xs, { width = "Fill" }),
            }, has_gpu),
        },
    }

    return column {
        width = "Fill",
        spacing = theme.spacing.sm,
        children = { head, details },
    }
end
