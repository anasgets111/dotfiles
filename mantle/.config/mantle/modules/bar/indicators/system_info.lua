-- A full-width "System" button that collapses to readouts and opens one details card. It lives
-- under `indicators/` but is used from `modules/bar/panels/notification_history.lua`.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local ui_state = require("lib.ui_state")
local disclosure = require("lib.disclosure")
local cell = require("components.cell")
local glyph = require("components.glyph")
local meter = require("components.meter")
local panel_card = require("components.panel_card")
local panel_row = require("components.panel_row")

-- This is the only module reading `sysinfo`, so its pollers run only while the notifications panel
-- shows: CPU every 2s, RAM and temperature every 5s, GPU every 2s, disks every 30s, network every 1s.
local function sync_polling()
    local on = ui_state.panel_is("notifications")
    local function every(seconds) return on and seconds or 0 end
    mantle.sysinfo:configure({
        cpu_interval = every(2),
        ram_interval = every(5),
        temp_interval = every(5),
        gpu_interval = every(2),
        disk_interval = every(30),
        net_interval = every(1),
    })
end
ui_state.panel_open:on_change(sync_polling)
ui_state.panel_kind:on_change(sync_polling)
sync_polling()

local disks = mantle.sysinfo:map(function(sysinfo)
    return sysinfo and sysinfo.disks or {}
end)

local boot = state("sysinfo_boot", { started = 0, duration = "" })
if boot:get().started == 0 then
    util.capture("cat", { "/proc/uptime" }, function(text)
        local seconds = tonumber(text:match("^([%d.]+)"))
        if seconds then boot:set(util.with(boot:get(), "started", os.time() - math.floor(seconds))) end
    end)
end
if boot:get().duration == "" then
    util.capture("systemd-analyze", { "time" }, function(text)
        local duration = text:match("=%s*([^%s]+)")
        if duration then boot:set(util.with(boot:get(), "duration", duration)) end
    end)
end

local function percent_of(sysinfo, field)
    return (sysinfo and sysinfo[field]) or 0
end

local function gpu_of(sysinfo, field)
    local gpu = sysinfo and sysinfo.gpu
    return gpu and gpu[field]
end

local function gpu_usage(sysinfo)
    return gpu_of(sysinfo, "util_percent") or 0
end

local has_gpu = util.shown_when(mantle.sysinfo, function(sysinfo)
    return sysinfo.gpu ~= nil
end)

local size = util.bytes

local function rate(bytes)
    return util.bytes(bytes) .. "/s"
end

local function uptime(seconds)
    local minutes = math.floor(math.max(0, seconds) / 60)
    local days, hours = minutes // 1440, minutes // 60 % 24
    return days > 0 and string.format("%dd %dh", days, hours) or
        hours > 0 and string.format("%dh %dm", hours, minutes % 60) or string.format("%dm", minutes)
end

-- Red from 90%, peach from 75%; ordinary readings stay neutral.
local function tint_of(percent)
    return percent >= 90 and theme.RED or percent >= 75 and theme.PEACH or theme.DIM
end

local gpu_color = mantle.sysinfo:map(function(sysinfo)
    local usage = gpu_of(sysinfo, "util_percent")
    return usage and tint_of(usage) or theme.DIM
end)

local function tint(field)
    return mantle.sysinfo:map(function(sysinfo)
        return tint_of(percent_of(sysinfo, field))
    end)
end

local function group(children, visible)
    return column { width = "fill", spacing = theme.spacing.xs, visible = visible, children = children }
end

local function readout(read)
    return util.bold(util.label(mantle.sysinfo, read))
end

local function tile_header(codepoint, glyph_color, label, value, value_color)
    return row {
        width = "fill",
        align_v = "center",
        spacing = theme.spacing.xs,
        children = {
            glyph(codepoint, glyph_color, theme.icon.sm, { align_v = "center" }),
            cell(util.bold(label), theme.FG, theme.font.sm, { width = "fill", align_v = "center" }),
            cell(value, value_color, theme.font.md, { align_v = "center" }),
        },
    }
end

local function metric_tile(codepoint, label, field, detail)
    local color = tint(field)
    return group({
        tile_header(codepoint, color, label, readout(function(sysinfo)
            return string.format("%d%%", percent_of(sysinfo, field))
        end), color),
        meter(mantle.sysinfo, function(sysinfo)
            return percent_of(sysinfo, field)
        end, color, theme.spacing.xs),
        cell(detail, theme.DIM, theme.font.xs, { width = "fill" }),
    })
end

local function labeled_meter(label, read, color, value, visible)
    return row {
        width = "fill",
        align_v = "center",
        spacing = theme.spacing.sm,
        visible = visible,
        children = {
            cell(label, theme.DIM, theme.font.xs, { width = theme.item_width }),
            meter(mantle.sysinfo, read, color, theme.spacing.xs),
            cell(value, color, theme.font.sm, { align = "end" }),
        },
    }
end

local SUMMARY = {
    { "CPU", "cpu_percent" },
    { "RAM", "ram_percent" },
}

local summary = mantle.sysinfo:map(function(sysinfo)
    local runs = {}
    for _, metric in ipairs(SUMMARY) do
        local label, field = table.unpack(metric)
        local percent = percent_of(sysinfo, field)
        runs[#runs + 1] = { text = #runs > 0 and " · " or "" }
        runs[#runs + 1] = { text = string.format("%s %d%%", label, percent), color = tint_of(percent) }
    end
    if sysinfo and sysinfo.gpu then
        local usage = gpu_of(sysinfo, "util_percent")
        runs[#runs + 1] = { text = " · " }
        runs[#runs + 1] = {
            text = usage and string.format("GPU %d%%", usage) or "GPU --",
            color = usage and tint_of(usage) or theme.DIM,
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

local id = "notifications"
local expanded = disclosure.state("sysinfo_expanded_" .. id, false)
local details = panel_card({
    row {
        width = "fill",
        spacing = theme.spacing.sm,
        children = {
            metric_tile(icons.cpu, "CPU", "cpu_percent", util.label(mantle.sysinfo, function(sysinfo)
                local celsius = math.max(0, table.unpack(sysinfo.temp_cores or {}))
                return celsius > 0 and string.format("%d°C", celsius) or "No temperature"
            end)),
            metric_tile(icons.ram, "Memory", "ram_percent", util.label(mantle.sysinfo, function(sysinfo)
                local swap = percent_of(sysinfo, "swap_percent")
                return swap > 0 and string.format("Swap %d%%", swap) or "No swap in use"
            end)),
        },
    },
    row {
        width = "fill",
        spacing = theme.spacing.sm,
        children = {
            group({
                cell(util.bold("Network"), theme.FG, theme.font.sm, { width = "fill" }),
                cell(readout(function(sysinfo)
                    return "↓ " .. rate(sysinfo and sysinfo.net_rx_bytes_sec or 0)
                end), theme.DIM, theme.font.sm, { width = "fill" }),
                cell(readout(function(sysinfo)
                    return "↑ " .. rate(sysinfo and sysinfo.net_tx_bytes_sec or 0)
                end), theme.DIM, theme.font.sm, { width = "fill" }),
            }),
            group({
                cell(util.bold("Uptime"), theme.FG, theme.font.sm, { width = "fill" }),
                cell(computed({ mantle.system, boot }, function(system, info)
                    return system and info and info.started > 0 and
                        uptime(system.time - info.started) or "--"
                end), theme.DIM, theme.font.sm, { width = "fill" }),
                cell(boot:map(function(info)
                    return info.duration ~= "" and "Boot " .. info.duration or "Boot --"
                end), theme.DIM, theme.font.xs, { width = "fill" }),
            }),
        },
    },
    group({
        tile_header(icons.gpu, gpu_color, "GPU", "", gpu_color),
        cell(util.label(mantle.sysinfo, function(sysinfo)
            return gpu_of(sysinfo, "name") or ""
        end), theme.DIM, theme.font.xs, { width = "fill" }),
        labeled_meter("Usage", gpu_usage, gpu_color, readout(function(sysinfo)
            local usage = gpu_of(sysinfo, "util_percent")
            return usage and string.format("%d%%", usage) or "--"
        end)),
        labeled_meter("VRAM", function(sysinfo)
            local used, total = gpu_of(sysinfo, "mem_used"), gpu_of(sysinfo, "mem_total")
            return used and total and total > 0 and used * 100 / total or 0
        end, theme.DIM, readout(function(sysinfo)
            local used, total = gpu_of(sysinfo, "mem_used"), gpu_of(sysinfo, "mem_total")
            return used and total and string.format("%s / %s", size(used), size(total)) or ""
        end), util.shown_when(mantle.sysinfo, function(sysinfo)
            local total = gpu_of(sysinfo, "mem_total")
            return gpu_of(sysinfo, "mem_used") and total and total > 0
        end)),
        cell(util.label(mantle.sysinfo, function(sysinfo)
            if not sysinfo.gpu then return "" end
            local temp = gpu_of(sysinfo, "temp")
            return temp and string.format("%d°C", temp) or "No temperature sensor"
        end), theme.DIM, theme.font.xs, { width = "fill" }),
    }, has_gpu),
    group({
        cell(util.bold("Disks"), theme.FG, theme.font.sm, { width = "fill" }),
        list {
            width = "fill",
            spacing = theme.spacing.sm,
            source = disks,
            key = function(disk) return disk.name end,
            itemfn = function(disk)
                local partitions = {
                    tile_header(icons.disk, tint_of(disk.percent), disk.name,
                        string.format("%d%%", disk.percent), tint_of(disk.percent)),
                    meter(disks, function() return disk.percent end,
                        tint_of(disk.percent), theme.spacing.xs),
                    cell(size(disk.used_bytes) .. " / " .. size(disk.total_bytes),
                        theme.DIM, theme.font.xs, { width = "fill" }),
                }
                for _, partition in ipairs(disk.partitions) do
                    partitions[#partitions + 1] = group({
                        row {
                            width = "fill",
                            spacing = theme.spacing.sm,
                            children = {
                                cell(partition.mount_point == "/" and "Root" or partition.mount_point,
                                    theme.FG, theme.font.xs, { width = "fill" }),
                                cell(string.format("%s / %s · %d%%", size(partition.used_bytes),
                                        size(partition.total_bytes), partition.percent),
                                    theme.DIM, theme.font.xs),
                            },
                        },
                        meter(disks, function() return partition.percent end,
                            tint_of(partition.percent), theme.spacing.xs),
                    })
                end
                return group(partitions)
            end,
        },
    }, util.shown_when(disks, function(current)
        return #current > 0
    end)),
}, { width = "fill", outlined = true, padding = theme.spacing.md, spacing = theme.spacing.md })

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
