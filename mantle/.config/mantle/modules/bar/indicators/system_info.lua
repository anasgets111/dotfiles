-- A full-width "System" button that collapses to readouts and opens one details card. It lives
-- under `indicators/` but is used from `modules/bar/panels/notification_history.lua`.
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
local panel_row = require("components.panel_row")

-- `sysinfo`'s pollers stay dormant until configured, and this is the only module reading them. CPU
-- every 2s, RAM and temperature every 5s, GPU every 2s, disks every 30s, and network every 1s.
-- `configure` has no ref-counting, so polling continues while the widget is collapsed.
mantle.sysinfo:configure({ cpu_interval = 2, ram_interval = 5, temp_interval = 5, gpu_interval = 2, disk_interval = 30, net_interval = 1 })

local disks = mantle.sysinfo:map(function(sysinfo)
    return sysinfo and sysinfo.disks or {}
end)

local boot = state("sysinfo_boot", { started = 0, duration = "" })
if boot:get().started == 0 then
    process.run("cat", { "/proc/uptime" }, function(line, stream)
        local seconds = stream == "stdout" and tonumber(line:match("^([%d.]+)"))
        if seconds then boot:set(util.with(boot:get(), "started", os.time() - math.floor(seconds))) end
    end, function() end)
end
if boot:get().duration == "" then
    process.run("systemd-analyze", { "time" }, function(line, stream)
        local duration = stream == "stdout" and line:match("=%s*([^%s]+)")
        if duration then boot:set(util.with(boot:get(), "duration", duration)) end
    end, function() end)
end

local function percent_of(sysinfo, field)
    return (sysinfo and sysinfo[field]) or 0
end

local function gpu_usage(sysinfo)
    return (sysinfo and sysinfo.gpu and sysinfo.gpu.util_percent) or 0
end

local has_gpu = util.shown_when(mantle.sysinfo, function(sysinfo)
    return sysinfo.gpu ~= nil
end)

local function size(bytes)
    if bytes < 1024 ^ 3 then
        return string.format("%.0f MiB", bytes / 1024 ^ 2)
    end
    return string.format("%.1f GiB", bytes / 1024 ^ 3)
end

local function rate(bytes)
    if bytes >= 1024 ^ 2 then
        return string.format("%.1f MiB/s", bytes / 1024 ^ 2)
    end
    return string.format("%.0f KiB/s", bytes / 1024)
end

local function uptime(seconds)
    local minutes = math.floor(math.max(0, seconds) / 60)
    local days, hours = minutes // 1440, minutes // 60 % 24
    return days > 0 and string.format("%dd %dh", days, hours) or
        hours > 0 and string.format("%dh %dm", hours, minutes % 60) or string.format("%dm", minutes)
end

-- Red from 90%, peach from 75%, else `fallback`.
local function tint_of(percent, fallback)
    return percent >= 90 and theme.RED or percent >= 75 and theme.PEACH or fallback
end

local gpu_color = mantle.sysinfo:map(function(sysinfo)
    local usage = sysinfo and sysinfo.gpu and sysinfo.gpu.util_percent
    return usage and tint_of(usage, theme.GREEN) or theme.DIM
end)

local function tint(field, fallback)
    return mantle.sysinfo:map(function(sysinfo)
        return tint_of(percent_of(sysinfo, field), fallback)
    end)
end

local function group(children, visible)
    return column { width = "Fill", spacing = theme.spacing.xs, visible = visible, children = children }
end

local function readout(read)
    return util.bold(util.label(mantle.sysinfo, read))
end

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
    return panel_card({
        tile_header(codepoint, accent, label, readout(function(sysinfo)
            return string.format("%d%%", percent_of(sysinfo, field))
        end), color),
        meter(mantle.sysinfo, function(sysinfo)
            return percent_of(sysinfo, field)
        end, color, theme.spacing.xs),
        cell(detail, theme.DIM, theme.font.xs, { width = "Fill" }),
    }, { width = "Fill", padding = theme.spacing.sm })
end

local function labeled_meter(label, read, color, value, visible)
    return row {
        width = "Fill",
        align_v = "Center",
        spacing = theme.spacing.sm,
        visible = visible,
        children = {
            cell(label, theme.DIM, theme.font.xs, { width = theme.item_width }),
            meter(mantle.sysinfo, read, color, theme.spacing.xs),
            cell(value, color, theme.font.sm, { align = "End" }),
        },
    }
end

local SUMMARY = {
    { "CPU", "cpu_percent", theme.ACCENT },
    { "RAM", "ram_percent", theme.GREEN },
}

local summary = mantle.sysinfo:map(function(sysinfo)
    local runs = {}
    for _, metric in ipairs(SUMMARY) do
        local label, field, accent = table.unpack(metric)
        local percent = percent_of(sysinfo, field)
        runs[#runs + 1] = { text = #runs > 0 and " · " or "" }
        runs[#runs + 1] = { text = string.format("%s %d%%", label, percent), color = tint_of(percent, accent) }
    end
    if sysinfo and sysinfo.gpu then
        local usage = sysinfo.gpu.util_percent
        runs[#runs + 1] = { text = " · " }
        runs[#runs + 1] = {
            text = usage and string.format("GPU %d%%", usage) or "GPU --",
            color = usage and tint_of(usage, theme.GREEN) or theme.DIM,
        }
    end
    local fullest_disk = 0
    for _, disk in ipairs(sysinfo and sysinfo.disks or {}) do
        fullest_disk = math.max(fullest_disk, disk.percent)
    end
    if fullest_disk >= 90 then
        runs[#runs + 1] = { text = " · " }
        runs[#runs + 1] = { text = string.format("DISK %d%%", fullest_disk), color = theme.RED }
    end
    runs[#runs + 1] = { text = " · " }
    runs[#runs + 1] = {
        text = "↓" .. rate(sysinfo and sysinfo.net_rx_bytes_sec or 0) ..
            " ↑" .. rate(sysinfo and sysinfo.net_tx_bytes_sec or 0),
        color = theme.DIM,
    }
    return runs
end)

---@param id string Names this instance's `expanded` state and its hover slot.
return function(id)
    local expanded = state("sysinfo_expanded_" .. id, false)
    local details = panel_card({
        row {
            width = "Fill",
            spacing = theme.spacing.sm,
            children = {
                metric_tile(icons.cpu, "CPU", "cpu_percent", theme.ACCENT, util.label(mantle.sysinfo, function(sysinfo)
                    local celsius = math.max(0, table.unpack(sysinfo.temp_cores or {}))
                    return celsius > 0 and string.format("%d°C", celsius) or "No temperature"
                end)),
                metric_tile(icons.ram, "Memory", "ram_percent", theme.GREEN, util.label(mantle.sysinfo, function(sysinfo)
                    local swap = percent_of(sysinfo, "swap_percent")
                    return swap > 0 and string.format("Swap %d%%", swap) or "No swap in use"
                end)),
            },
        },
        row {
            width = "Fill",
            spacing = theme.spacing.sm,
            children = {
                panel_card({
                    cell(util.bold("Network"), theme.FG, theme.font.sm, { width = "Fill" }),
                    cell(readout(function(sysinfo)
                        return "↓ " .. rate(sysinfo and sysinfo.net_rx_bytes_sec or 0)
                    end), theme.ACCENT, theme.font.sm, { width = "Fill" }),
                    cell(readout(function(sysinfo)
                        return "↑ " .. rate(sysinfo and sysinfo.net_tx_bytes_sec or 0)
                    end), theme.GREEN, theme.font.sm, { width = "Fill" }),
                }, { width = "Fill", padding = theme.spacing.sm }),
                panel_card({
                    cell(util.bold("Uptime"), theme.FG, theme.font.sm, { width = "Fill" }),
                    cell(computed({ mantle.system, boot }, function(system, info)
                        return system and info and info.started > 0 and
                            uptime(system.time - info.started) or "--"
                    end), theme.ACCENT, theme.font.sm, { width = "Fill" }),
                    cell(boot:map(function(info)
                        return info.duration ~= "" and "Boot " .. info.duration or "Boot --"
                    end), theme.DIM, theme.font.xs, { width = "Fill" }),
                }, { width = "Fill", padding = theme.spacing.sm }),
            },
        },
        group({
            tile_header(icons.gpu, gpu_color, "GPU", "", gpu_color),
            cell(util.label(mantle.sysinfo, function(sysinfo)
                return sysinfo and sysinfo.gpu and sysinfo.gpu.name or ""
            end), theme.DIM, theme.font.xs, { width = "Fill" }),
            labeled_meter("Usage", gpu_usage, gpu_color, readout(function(sysinfo)
                local usage = sysinfo and sysinfo.gpu and sysinfo.gpu.util_percent
                return usage and string.format("%d%%", usage) or "--"
            end)),
            labeled_meter("VRAM", function(sysinfo)
                local gpu = sysinfo and sysinfo.gpu
                return gpu and gpu.mem_used and gpu.mem_total and gpu.mem_total > 0 and
                    gpu.mem_used * 100 / gpu.mem_total or 0
            end, theme.ACCENT, readout(function(sysinfo)
                local gpu = sysinfo and sysinfo.gpu
                return gpu and gpu.mem_used and gpu.mem_total and
                    string.format("%s / %s", size(gpu.mem_used), size(gpu.mem_total)) or ""
            end), util.shown_when(mantle.sysinfo, function(sysinfo)
                return sysinfo.gpu and sysinfo.gpu.mem_used and sysinfo.gpu.mem_total and sysinfo.gpu.mem_total > 0
            end)),
            cell(util.label(mantle.sysinfo, function(sysinfo)
                local gpu = sysinfo and sysinfo.gpu
                if not gpu then return "" end
                return gpu.temp and string.format("%d°C", gpu.temp) or "No temperature sensor"
            end), theme.DIM, theme.font.xs, { width = "Fill" }),
        }, has_gpu),
        group({
            cell(util.bold("Disks"), theme.FG, theme.font.sm, { width = "Fill" }),
            list {
                width = "Fill",
                spacing = theme.spacing.sm,
                source = disks,
                key = function(disk) return disk.name end,
                itemfn = function(disk)
                    local partitions = {
                        tile_header(icons.disk, theme.PEACH, disk.name,
                            string.format("%d%%", disk.percent), tint_of(disk.percent, theme.PEACH)),
                        meter(disks, function() return disk.percent end,
                            tint_of(disk.percent, theme.PEACH), theme.spacing.xs),
                        cell(size(disk.used_bytes) .. " / " .. size(disk.total_bytes),
                            theme.DIM, theme.font.xs, { width = "Fill" }),
                    }
                    for _, partition in ipairs(disk.partitions) do
                        partitions[#partitions + 1] = group({
                            row {
                                width = "Fill",
                                spacing = theme.spacing.sm,
                                children = {
                                    cell(partition.mount_point == "/" and "Root" or partition.mount_point,
                                        theme.FG, theme.font.xs, { width = "Fill" }),
                                    cell(string.format("%s / %s · %d%%", size(partition.used_bytes),
                                            size(partition.total_bytes), partition.percent),
                                        theme.DIM, theme.font.xs),
                                },
                            },
                            meter(disks, function() return partition.percent end,
                                tint_of(partition.percent, theme.PEACH), theme.spacing.xs),
                        })
                    end
                    return group(partitions)
                end,
            },
        }, util.shown_when(disks, function(current)
            return #current > 0
        end)),
    }, { width = "Fill", outlined = true, padding = theme.spacing.md, spacing = theme.spacing.md })

    return panel_row {
        slot = "sysinfo-" .. id,
        icon = icons.cpu,
        title = "System",
        subtitle = summary,
        expanded = expanded,
        animate_details = true,
        details_spacing = theme.spacing.sm,
        details = details,
    }
end
