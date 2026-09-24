-- Pending updates and the install run, in words. `lib/updates.lua` runs everything; this file owns
-- the wording and layout.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local panel_card = require("components.panel_card")
local panel_header = require("components.panel_header")
local panel_empty_state = require("components.panel_empty_state")
local spinner = require("components.spinner")
local action_button = require("components.action_button")
local panel_action_icon = require("components.panel_action_icon")
local panel_row = require("components.panel_row")
local section_header = require("components.section_header")
local toggle = require("components.toggle")
local meter = require("components.meter")
local info_badge = require("components.info_badge")
local store = require("lib.store")
local ui = require("lib.ui_state")
local service = require("lib.updates")
local dev_tools = require("config.dev_tools")

local KIND = "updates"
local LOG_SCROLL = scroll("update_log")

local log_open = ui.updates_log_open
local settings_open = ui.updates_settings_open

-- KiB, MiB, GiB use 1024, matching pacman's package sizes.
local BYTE_UNITS = { "B", "KiB", "MiB", "GiB" }
local function human_bytes(bytes)
    local size, unit = bytes, 1
    while size >= 1024 and unit < #BYTE_UNITS do
        size, unit = size / 1024, unit + 1
    end
    return string.format(unit == 1 and "%d %s" or "%.1f %s", size, BYTE_UNITS[unit])
end

local function download_total(updates)
    local total = 0
    for _, package in ipairs(service.packages(updates)) do
        total = total + (package.download_size or 0)
    end
    return total
end

local function aur_count(updates)
    local count = 0
    for _, package in ipairs(service.packages(updates)) do
        count = count + (package.repository == "aur" and 1 or 0)
    end
    return count
end

local status_tone = computed({ mantle.updates, service.result_showing, service.dev_result },
    function(updates, showing, dev)
        if showing and service.install_failed(updates) then
            return "error"
        end
        if (updates ~= nil and (updates.check_error ~= nil or updates.aur_error ~= nil)) or
            (showing and #(dev.failures or {}) > 0) then
            return "warning"
        end
        return showing and "active" or "standard"
    end)

-- ponytail: `install_log` is a 200-line tail, so long runs undercount. Exact needs a Supervisor counter.
local function warning_count(updates)
    local count = 0
    for _, line in ipairs(updates.install_log or {}) do
        if line:lower():find("warning", 1, true) then
            count = count + 1
        end
    end
    return count
end

-- `showing` is `service.result_showing`, passed in, because a signal read inside a map never re-runs it.
local function status_line(updates, showing, tool, dev)
    if updates == nil then
        return "Waiting for the updater"
    end
    if tool ~= "" then
        return "Updating " .. tool
    end
    if updates.installing then
        local package = updates.install_current_package
        return (package ~= nil and package ~= "") and ("Installing " .. package) or "Preparing update…"
    end
    if showing then
        if service.install_failed(updates) then
            return "Update failed"
        end
        return #(dev.failures or {}) > 0 and "Update finished with failures" or "Update complete"
    end
    if updates.checking then
        return "Checking…"
    end
    if updates.check_error ~= nil then
        return "Check failed"
    end
    if (updates.count or 0) > 0 then
        return service.plural(updates.count, "update") .. " available"
    end
    return "Up to date"
end

local function detail_line(updates, showing, tool, dev)
    if updates == nil then
        return ""
    end
    if tool ~= "" then
        return string.format("Developer tooling · %d of %d", service.tool_step(tool))
    end
    if updates.installing then
        local total = updates.install_total_steps or 0
        if total > 0 then
            return string.format("Package %d of %d", updates.install_current_step or 0, total)
        end
        -- No step line yet. Without a tty pacman downloads silently, so show what `alpm` sized.
        return string.format("Downloading %s · %s", service.plural(updates.count, "package"),
            human_bytes(download_total(updates)))
    end
    if showing then
        -- The reason heads the log card, beside the output it came from.
        local start = service.started_at:get()
        local seconds = (dev.finished_at or updates.install_finished_at or os.time()) - start
        local time_str = (start > 0 and seconds >= 0) and (seconds < 60 and string.format("%d sec", seconds)
            or string.format("%d min %d sec", math.floor(seconds / 60), seconds % 60))
        if service.install_failed(updates) then
            return time_str and ("Failed after " .. time_str) or "See the log below"
        end
        local ran = service.ran_packages(updates)
        local warnings = ran and warning_count(updates) or 0
        local noted = warnings > 0 and (" · " .. service.plural(warnings, "warning")) or ""
        local failed = #(dev.failures or {}) > 0 and (" · " .. table.concat(dev.failures, ", ") .. " failed") or ""
        local count = ran and (updates.install_total_steps or 0) or 0
        local count_prefix = count > 0 and (service.plural(count, "package") .. " · ") or ""
        local took = time_str and ((count > 0 and "took " or "Took ") .. time_str) or "Finished"
        return count_prefix .. took .. noted .. failed
    end
    -- A failed check keeps the last good list, so say which list is shown.
    if updates.check_error ~= nil then
        local failures = updates.consecutive_check_failures or 0
        -- Five consecutive failures is the warning threshold.
        local repeated = failures >= 5 and string.format(" · %d in a row", failures) or ""
        return "Last result kept · " .. updates.check_error:match("[^\n]*") .. repeated
    end
    if updates.aur_error ~= nil then
        return "AUR not checked · " .. updates.aur_error:match("[^\n]*")
    end
    if (updates.count or 0) > 0 then
        return string.format("%s to download", human_bytes(download_total(updates)))
    end
    return "Nothing pending"
end

-- Dated unless today, and marked stale past two intervals (a suspended laptop). `detail_line` covers
-- errors.
local function last_check_line(updates, now)
    if updates == nil or updates.last_successful_check == nil then
        return "Never checked"
    end
    local at = updates.last_successful_check
    local when = os.date("%Y-%m-%d", at) == os.date("%Y-%m-%d") and os.date("%H:%M", at)
        or os.date("%b %d, %H:%M", at)
    return "Checked " .. when .. (now - at > service.CHECK_INTERVAL * 2 and " · stale" or "")
end

-- Packages whose new version only runs after a reboot; tinted in the list.
local REBOOT_PATTERNS = { "^linux", "^nvidia", "^systemd$", "^glibc$", "^amd%-ucode$", "^intel%-ucode$" }

local function needs_reboot(name)
    for _, pattern in ipairs(REBOOT_PATTERNS) do
        if name:find(pattern) then
            return true
        end
    end
    return false
end

-- Repo packages, then AUR builds under a header, each by name; `alpm`'s installed-database order has
-- no useful reading order.
local sorted_packages = mantle.updates:map(function(updates)
    local list = util.concat(service.packages(updates))
    table.sort(list, function(left, right)
        local left_aur, right_aur = left.repository == "aur", right.repository == "aur"
        if left_aur ~= right_aur then
            return right_aur
        end
        return (left.name or "") < (right.name or "")
    end)
    for index, package in ipairs(list) do
        if package.repository == "aur" then
            table.insert(list, index, { header = "AUR" })
            break
        end
    end
    return list
end)

local log_lines = computed({ mantle.updates, service.dev_log }, function(updates, lines)
    return util.concat(updates and updates.install_log, lines)
end)

-- Strongest first, so red failures are findable in two hundred lines of pacman output.
local LOG_COLOURS = {
    { theme.RED, "%[fail%]", "error", "failed" },
    { theme.PEACH, "warning", "%[skip%]" },
    { theme.ACCENT, "downloading", "retrieving", "installing", "upgrading", "%(%s*%d+/%d+%)" },
    { theme.GREEN, "%[ ok %]", "complete", "up to date" },
    { theme.FG, "^▶", "^::", "^==>" },
}

-- The settings list takes the whole body.
local function unless_settings(showing)
    return computed({ showing, settings_open }, function(visible, settings)
        return visible and not settings
    end)
end

-- One fixed-height card holds the spinner, then the list, so a check does not resize the panel.
local packages_showing = unless_settings(computed({ mantle.updates, service.result_showing, service.dev_running },
    function(updates, showing, tool)
        return not showing and tool == "" and updates ~= nil and not updates.installing and
            (updates.checking or #service.packages(updates) > 0)
    end))
-- With nothing pending or to report, the empty state replaces the status card.
local empty_showing = unless_settings(computed({ mantle.updates, service.result_showing, service.dev_running },
    function(updates, showing, tool)
        return not showing and tool == "" and updates ~= nil and not updates.installing and not updates.checking
            and updates.check_error == nil and (updates.count or 0) == 0
    end))
local status_showing = computed({ settings_open, empty_showing }, function(settings, empty)
    return not settings and not empty
end)
local checking = util.shown_when(mantle.updates, function(updates)
    return updates.checking
end)

local log_showing = unless_settings(computed({ mantle.updates, service.result_showing, log_open, service.dev_running },
    function(updates, showing, open, tool)
        return updates ~= nil and
            (updates.installing or tool ~= "" or (showing and (service.install_failed(updates) or open)))
    end))

-- Follow the newest line on every push. Past 200 lines the tail changes but its length does not,
-- and the exit push carries the failure's stderr.
--
-- ponytail: scrolling back does not pause the follow. The offset trails `reveal` by a layout pass,
-- so user scrolls are undetectable; needs an engine "wheel moved this viewport" signal.
mantle.updates:on_change(function(updates)
    local lines = updates ~= nil and #(updates.install_log or {}) or 0
    if lines > 0 then
        LOG_SCROLL:reveal(lines)
    end
end)

-- One row per `config/dev_tools.lua` entry, subtitled with the binary it needs.
local tool_rows = {}
for _, tool in ipairs(dev_tools) do
    tool_rows[#tool_rows + 1] = panel_row {
        title = tool.name,
        subtitle = tool.requires,
        -- Nothing to decide about a tool this machine cannot run.
        visible = service.tools_present:map(function(present)
            return present[tool.requires] == true
        end),
        trailing = toggle(store.updates_dev_tools, function(ticked)
            return (ticked or {})[tool.name] ~= false
        end, function(on)
            store:set("updates_dev_tools", util.with(store.updates_dev_tools:get(), tool.name, on))
        end),
    }
end

-- The capability learns the switch through `configure`; the check then adds or drops AUR rows.
local aur_row = panel_row {
    title = "AUR packages",
    subtitle = mantle.updates:map(function(updates)
        local helper = updates and updates.aur_helper
        return helper and ("Builds with " .. helper) or "No helper found (paru, yay)"
    end),
    trailing = toggle(store.updates_aur, function(on)
        return on
    end, function(on)
        store:set("updates_aur", on)
        mantle.updates:invoke("configure", { interval = service.CHECK_INTERVAL, aur = on })
        mantle.updates:invoke("check")
    end),
}

-- Dims rather than hides, so the row keeps its layout.
local busy = computed({ mantle.updates, service.dev_running }, function(updates, tool)
    return updates == nil or updates.checking or updates.installing or tool ~= ""
end)

-- Percent through this run's packages, then its tools; `false` while there is no count to show.
local progress = computed({ mantle.updates, service.dev_running }, function(updates, tool)
    if tool ~= "" then
        local step, total = service.tool_step(tool)
        return total > 0 and 100 * step / total or false
    end
    local total = (updates and updates.installing and updates.install_total_steps) or 0
    return total > 0 and 100 * (updates.install_current_step or 0) / total or false
end)

-- `.pacnew` and `.pacsave` files from this run, each wanting a manual merge.
local pacnew = computed({ mantle.updates, service.result_showing }, function(updates, showing)
    local files = {}
    if not (showing and service.ran_packages(updates)) then
        return files
    end
    for _, line in ipairs(updates.install_log or {}) do
        local path = line:match("installed as (%S+%.pacnew)") or line:match("saved as (%S+%.pacsave)")
        if path then
            files[#files + 1] = path
        end
    end
    return files
end)

-- Installing before pacman has counted the packages.
local working = util.shown_when(mantle.updates, function(updates)
    return updates.installing and (updates.install_total_steps or 0) == 0
end)

local body = {
    panel_header {
        title = "Updates",
        icon = mantle.updates:map(function(updates)
            updates = updates or {}
            return updates.installing and icons.updating or updates.checking and icons.checking
                or (updates.count or 0) > 0 and icons.updates or icons.up_to_date
        end),
        active = mantle.updates:map(function(updates)
            return ((updates and updates.count) or 0) > 0 or
                (updates ~= nil and (updates.installing or updates.checking))
        end),
        subtitle = computed({ mantle.updates, mantle.system }, function(updates, clock)
            return last_check_line(updates, (clock and clock.time) or os.time())
        end),
        trailing = {
            info_badge("Reboot required", theme.PEACH, {
                visible = util.shown_when(mantle.updates, function(updates)
                    return updates.reboot_required == true
                end),
            }),
            panel_action_icon(icons.settings, function()
                settings_open:set(not settings_open:get())
            end, { slot = "updates-settings" }),
            panel_action_icon(icons.refresh, function()
                mantle.updates:invoke("check")
            end, { slot = "updates-refresh", disabled = busy, spinning = checking }),
        },
    },
    panel_card({
        cell(
            util.bold(computed({ mantle.updates, service.result_showing, service.dev_running, service.dev_result },
                status_line)), theme.FG,
            theme.font.md),
        cell(computed({ mantle.updates, service.result_showing, service.dev_running, service.dev_result }, detail_line),
            theme.DIM, theme.font
            .xs),
        row {
            width = "Fill",
            visible = progress:map(function(percent)
                return percent ~= false
            end),
            children = {
                meter(progress, function(percent)
                    return percent or 0
                end, theme.ACCENT),
            },
        },
        row {
            spacing = theme.spacing.sm,
            align_v = "Center",
            visible = working,
            children = { spinner(working, theme.control.xs), cell("Working…", theme.DIM, theme.font.xs) },
        },
    }, { tone = status_tone, width = "Fill", spacing = theme.spacing.xs, visible = status_showing }),
    panel_empty_state("Nothing to update", empty_showing, { icon = icons.up_to_date }),
    panel_card({
        section_header("config files to merge"),
        column {
            width = "Fill",
            spacing = theme.spacing.xs,
            children = pacnew:map(function(files)
                local rows = {}
                for _, path in ipairs(files) do
                    rows[#rows + 1] = cell(path, theme.PEACH, theme.font.xs, { width = "Fill", font = theme.mono_font })
                end
                return rows
            end),
        },
    }, {
        tone = "warning",
        width = "Fill",
        visible = unless_settings(pacnew:map(function(files)
            return #files > 0
        end)),
    }),
    panel_card({
        -- Shown over the spinner too, so the table's frame is already there when the list lands.
        row {
            width = "Fill",
            spacing = theme.spacing.sm,
            children = {
                cell(util.bold("Package"), theme.DIM, theme.font.xs, { width = "Fill" }),
                cell(util.bold("Current"), theme.DIM, theme.font.xs, { width = theme.update_version_width }),
                cell(util.bold("New"), theme.DIM, theme.font.xs, { width = theme.update_version_width }),
            },
        },
        column {
            width = "Fill",
            height = theme.update_list_height,
            align_v = "Center",
            visible = checking,
            children = { spinner(checking, theme.control.sm) },
        },
        list {
            width = "Fill",
            height = theme.update_list_height,
            visible = util.shown_when(mantle.updates, function(updates)
                return not updates.checking
            end),
            scroll = scroll("update_packages"),
            spacing = theme.spacing.xs,
            source = sorted_packages,
            itemfn = function(package)
                if package.header then
                    return section_header(package.header)
                end
                return row {
                    width = "Fill",
                    height = theme.control.sm,
                    align_v = "Center",
                    spacing = theme.spacing.sm,
                    children = {
                        cell(package.name or "?", needs_reboot(package.name or "") and theme.PEACH or theme.FG, theme.font.sm, { width = "Fill", align_v = "Center" }),
                        cell(package.repository ~= "aur" and package.repository or "", theme.DIM, theme.font.xs, {
                            align_v = "Center",
                        }),
                        cell(package.old_version or "", theme.DIM, theme.font.xs, {
                            width = theme.update_version_width,
                            align_v = "Center",
                        }),
                        cell(package.new_version or "", theme.ACCENT, theme.font.xs, {
                            width = theme.update_version_width,
                            align_v = "Center",
                        }),
                    },
                }
            end,
            key = function(package)
                return package.header or package.name or "?"
            end,
        },
    }, { width = "Fill", visible = packages_showing }),
    panel_card({
        row {
            width = "Fill",
            align_v = "Center",
            children = {
                cell(util.bold(mantle.updates:map(function(updates)
                    return service.install_failed(updates) and service.failure_reason(updates) or "Install log"
                end)), mantle.updates:map(function(updates)
                    return service.install_failed(updates) and theme.RED or theme.DIM
                end), theme.font.xs, { width = "Fill" }),
                panel_action_icon(icons.copy, function()
                    local lines = log_lines:get() or {}
                    if #lines > 0 then
                        process.detach("wl-copy", { table.concat(lines, "\n") })
                    end
                end, { slot = "updates-copy-log" }),
            },
        },
        list {
            width = "Fill",
            height = theme.update_log_height,
            scroll = LOG_SCROLL,
            source = log_lines,
            spacing = theme.spacing.xs,
            itemfn = function(line)
                return cell(line, service.first_match(line:lower(), LOG_COLOURS) or theme.DIM, theme.font.xs, {
                    width = "Fill",
                    wrap = "Word",
                    max_lines = 3,
                    font = theme.mono_font,
                })
            end,
        },
    }, {
        tone = mantle.updates:map(function(updates)
            return service.install_failed(updates) and "error" or "standard"
        end),
        width = "Fill",
        visible = log_showing,
    }),
    panel_card({ section_header("aur"), aur_row }, { width = "Fill", visible = settings_open }),
    panel_card({ section_header("run with package updates"), column {
        width = "Fill",
        children = tool_rows,
    } }, { width = "Fill", visible = settings_open }),
    action_button("Done", function()
        settings_open:set(false)
    end, "updates-settings-done", { tone = "quiet", width = "Fill", visible = settings_open }),
    row {
        width = "Fill",
        spacing = theme.spacing.sm,
        visible = settings_open:map(function(open)
            return not open
        end),
        children = {
            action_button(
                computed({ mantle.updates, service.result_showing, service.dev_running }, function(updates, showing, tool)
                    if updates ~= nil and (updates.installing or tool ~= "") then
                        return "Updating…"
                    end
                    if showing and service.install_failed(updates) then
                        return "Retry"
                    end
                    if ((updates and updates.count) or 0) == 0 then
                        return "Update dev tools"
                    end
                    local builds = aur_count(updates)
                    return builds > 0 and string.format("Update · builds %d from AUR", builds) or "Update"
                end),
                service.install,
                "updates-install",
                {
                    tone = "solid",
                    width = "Fill",
                    disabled = busy,
                    visible = computed({ mantle.updates, service.result_showing, service.dev_running }, function(updates,
                                                                                                                 showing,
                                                                                                                 tool)
                        if updates == nil or (showing and not service.install_failed(updates)) then
                            return false
                        end
                        return updates.installing or tool ~= "" or (updates.count or 0) > 0 or showing or
                            service.any_tool_runnable()
                    end),
                }
            ),
            action_button(
                log_open:map(function(open)
                    return open and "Hide log" or "View log"
                end),
                function()
                    log_open:set(not log_open:get())
                end,
                "updates-log",
                {
                    tone = "quiet",
                    width = "Fill",
                    visible = computed({ service.result_showing, mantle.updates }, function(showing, updates)
                        return showing and not service.install_failed(updates)
                    end),
                }
            ),
            action_button("Close", function()
                service.dismiss_notifications()
                service.dismissed:set(true)
                ui.close_panel()
            end, "updates-dismiss", { tone = "quiet", width = "Fill", visible = service.result_showing }),
        },
    },
}

return { kind = KIND, body = body }
