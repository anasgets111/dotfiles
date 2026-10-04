-- Update actions, repository groups and run output. `lib/updates.lua` owns execution.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local checkbox = require("components.checkbox")
local panel_header = require("components.panel_header")
local spinner = require("components.spinner")
local action_button = require("components.action_button")
local panel_action_icon = require("components.panel_action_icon")
local panel_row = require("components.panel_row")
local section_header = require("components.section_header")
local meter = require("components.meter")
local info_badge = require("components.info_badge")
local store = require("lib.store")
local ui = require("lib.ui_state")
local disclosure = require("lib.disclosure")
local service = require("lib.updates")
local dev_tools = require("config.dev_tools")

local LOG_SCROLL = scroll("update_log")

local log_open = service.log_open
local settings_expanded = disclosure.state("updates_settings_expanded", false)
local phase = service.phase

local function download_total(updates)
    local total = 0
    for _, package in ipairs(service.packages(updates)) do
        total = total + (package.download_size or 0)
    end
    return total
end

local status_color = computed({ phase, mantle.updates, service.dev_result }, function(current, updates, dev)
    if current == "failed" or current == "check_failed" then
        return theme.RED
    elseif (updates ~= nil and (updates.check_error ~= nil or updates.aur_error ~= nil)) or
        (current == "done" and #(dev.failures or {}) > 0) then
        return theme.PEACH
    end
    return current == "done" and theme.GREEN or theme.DIM
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

local function status_line(updates, current, tool, dev)
    if current == "loading" then
        return "Waiting for the updater"
    elseif tool ~= "" then
        return "Updating " .. tool
    elseif current == "running" then
        local package = updates.install_current_package
        return (package ~= nil and package ~= "") and ("Installing " .. package) or "Preparing update…"
    elseif current == "failed" then
        return "Update failed"
    elseif current == "done" then
        return #(dev.failures or {}) > 0 and "Update finished with failures" or "Update complete"
    elseif current == "checking" then
        return "Checking…"
    elseif current == "pending" then
        return service.plural(#updates.packages, "update") .. " available"
    elseif current == "check_failed" then
        return "Check failed"
    end
    return "Up to date"
end

local function detail_line(updates, current, tool, dev)
    if current == "loading" then
        return ""
    elseif tool ~= "" then
        return string.format("Developer tooling · %d of %d", service.tool_step(tool))
    elseif current == "running" then
        local total = updates.install_total_steps or 0
        if total > 0 then
            return string.format("Package %d of %d", updates.install_current_step or 0, total)
        end
        -- No step line yet. Without a tty pacman downloads silently, so show what `alpm` sized.
        return string.format("Downloading %s · %s", service.plural(#updates.packages, "package"),
            util.bytes(download_total(updates)))
    end
    if current == "done" or current == "failed" then
        -- The reason heads the log, beside the output it came from.
        local start = service.started_at:get()
        local seconds = (dev.finished_at or updates.install_finished_at or os.time()) - start
        local time_str = (start > 0 and seconds >= 0) and (seconds < 60 and string.format("%d sec", seconds)
            or string.format("%d min %d sec", math.floor(seconds / 60), seconds % 60))
        if current == "failed" then
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
        return "Showing the last list · " .. updates.check_error:match("[^\n]*") .. repeated
    end
    if updates.aur_error ~= nil then
        return "AUR not checked · " .. updates.aur_error:match("[^\n]*")
    end
    if #updates.packages > 0 then
        return string.format("%s to download", util.bytes(download_total(updates)))
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
    return "Checked " .. util.stamp(at, now) .. (now - at > service.CHECK_INTERVAL * 2 and " · stale" or "")
end

-- Packages whose new version only runs after a reboot; tinted in the list.
local REBOOT = { systemd = true, glibc = true, ["amd-ucode"] = true, ["intel-ucode"] = true }
local REPO_COLORS = { core = theme.GREEN, extra = theme.YELLOW, multilib = theme.ACCENT, aur = theme.PEACH }

local function needs_reboot(name)
    return REBOOT[name] == true or name:find("^linux") ~= nil or name:find("^nvidia") ~= nil
end

-- Group by repository, with AUR builds last; names sort within each group.
local sorted_packages = mantle.updates:map(function(updates)
    local list = util.concat(service.packages(updates))
    table.sort(list, function(left, right)
        local left_repo, right_repo = left.repository or "", right.repository or ""
        if left_repo ~= right_repo then
            if left_repo == "aur" or right_repo == "aur" then
                return right_repo == "aur"
            end
            return left_repo < right_repo
        end
        return (left.name or "") < (right.name or "")
    end)
    local rows, group = {}, nil
    for _, package in ipairs(list) do
        local repo = package.repository or ""
        if group == nil or repo ~= group.repository then
            group = {
                repository = repo,
                header = repo == "aur" and "AUR builds" or repo == "" and "Repositories" or repo,
                count = 0
            }
            rows[#rows + 1] = group
        end
        group.count = group.count + 1
        rows[#rows + 1] = package
    end
    return rows
end)

-- The capability retains packages during a refresh, keeping this height until results arrive.
local package_height = sorted_packages:map(function(packages)
    return math.max(theme.control.sm, util.fit_height(packages, theme.update_list_height, theme.spacing.xs,
        function(package)
            return package.header and theme.section_header_height or theme.control.md
        end))
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

-- A finished run's re-check keeps its result on screen while the Check button is busy.
local checking = util.shown_when(mantle.updates, function(updates)
    return updates.checking
end)

local log_showing = computed({ phase, log_open }, function(current, open)
    return current == "running" or current == "failed" or (current == "done" and open)
end)

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

-- The whole row toggles inclusion; the checkbox is its readback.
---@param on Signal<boolean>
---@param opts PanelRowOpts
local function include_row(on, opts)
    local mark = checkbox(on)
    opts.height = theme.control.md
    opts.trailing = opts.trailing and row {
        spacing = theme.spacing.sm, align_v = "center", children = { opts.trailing, mark },
    } or mark
    return panel_row(opts)
end

local tools_heading = section_header("also update")
tools_heading.margin = { left = theme.spacing.sm }
local tool_rows = {}
for _, tool in ipairs(dev_tools) do
    local included = store.updates_dev_tools:map(function(ticked)
        return service.tool_enabled(tool.name, ticked)
    end)
    tool_rows[#tool_rows + 1] = include_row(included, {
        title = tool.name == "node" and "Node.js" or tool.name:gsub("^%l", string.upper),
        slot = "updates-tool-" .. tool.name,
        -- Nothing to decide about a tool this machine cannot run.
        visible = service.tools_present:map(function(present)
            return present[tool.requires] == true
        end),
        on_activate = function()
            store:set("updates_dev_tools", util.with(store.updates_dev_tools:get(), tool.name, not included:get()))
        end,
    })
end

-- The capability learns the switch through `configure`; the check then adds or drops AUR rows.
local aur_row = include_row(store.updates_aur, {
    title = "AUR packages",
    slot = "updates-aur",
    trailing = cell(mantle.updates:map(function(updates)
        local helper = updates and updates.aur_helper
        return helper or "No helper found"
    end), theme.DIM, theme.font.xs),
    on_activate = function()
        local on = not store.updates_aur:get()
        store:set("updates_aur", on)
        mantle.updates:configure({ interval = service.CHECK_INTERVAL, aur = on })
        mantle.updates:check()
    end,
})

local settings_summary = computed({ store.updates_aur, store.updates_dev_tools, service.tools_present },
    function(aur, ticked, present)
        local words, count = aur and { "AUR" } or {}, 0
        for _, tool in ipairs(dev_tools) do
            if present[tool.requires] == true and service.tool_enabled(tool.name, ticked) then
                count = count + 1
            end
        end
        if count > 0 then
            words[#words + 1] = service.plural(count, "developer tool")
        end
        return #words > 0 and table.concat(words, " · ") or "Repositories only"
    end)

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

local function package_columns(name, current, new, name_color, new_color, name_size)
    return {
        cell(name, name_color, name_size or theme.font.sm, { width = "fill", align_v = "center" }),
        cell(current, theme.DIM, theme.font.xs, { width = theme.update_version_width, align = "end", align_v = "center" }),
        cell(new, new_color, theme.font.xs, { width = theme.update_version_width, align = "end", align_v = "center" }),
    }
end

local body = {
    panel_header {
        title = "Updates",
        icon = phase:map(function(current)
            if current == "running" then
                return icons.updating
            elseif current == "checking" then
                return icons.checking
            elseif current == "failed" or current == "check_failed" then
                return icons.update_err
            end
            return current == "pending" and icons.updates or icons.up_to_date
        end),
        accent = computed({ phase, status_color }, function(current, color)
            return (current == "pending" or current == "running" or current == "checking") and theme.ACCENT or color
        end),
        subtitle = computed({ mantle.updates, phase, service.dev_running, service.dev_result }, status_line),
        trailing = {
            info_badge("Reboot required", theme.PEACH, {
                visible = util.shown_when(mantle.updates, function(updates)
                    return updates.reboot_required == true
                end),
            }),
        },
    },
    row {
        width = "fill",
        spacing = theme.spacing.sm,
        children = {
            action_button(
                computed({ phase, mantle.updates }, function(current, updates)
                    if current == "running" then
                        return "Updating…"
                    elseif current == "failed" then
                        return "Retry update"
                    elseif (updates and #updates.packages or 0) == 0 then
                        return "Update developer tools"
                    end
                    return "Update all"
                end),
                service.install,
                "updates-install",
                {
                    tone = "accent",
                    glyph = icons.updates,
                    width = "fill",
                    disabled = busy,
                    visible = computed({ phase, mantle.updates, store.updates_dev_tools, service.tools_present },
                        function(current, updates)
                            if current == "running" or current == "failed" then
                                return true
                            elseif current == "loading" or current == "done" then
                                return false
                            end
                            return #updates.packages > 0 or service.any_tool_runnable()
                        end),
                }
            ),
            action_button(util.choose(checking, "Checking…", "Check"), function()
                mantle.updates:check()
            end, "updates-refresh", {
                tone = "quiet",
                glyph = icons.refresh,
                width = theme.update_version_width + theme.spacing.lg,
                disabled = busy,
            }),
        },
    },
    column {
        width = "fill",
        spacing = theme.spacing.sm,
        padding = { left = theme.spacing.sm, right = theme.spacing.sm },
        children = {
            row {
                width = "fill",
                spacing = theme.spacing.sm,
                align_v = "center",
                children = {
                    cell(computed({ mantle.updates, phase, service.dev_running, service.dev_result }, detail_line),
                        status_color, theme.font.xs, { width = "fill", wrap = "word" }),
                    cell(computed({ mantle.updates, mantle.system }, function(updates, clock)
                        return last_check_line(updates, (clock and clock.time) or os.time())
                    end), theme.TEXT_MUTED, theme.font.xs, {
                        align = "end",
                        visible = phase:map(function(current)
                            return current ~= "running" and current ~= "done" and current ~= "failed"
                        end),
                    }),
                },
            },
            row {
                width = "fill",
                visible = progress:map(function(percent)
                    return percent ~= false
                end),
                children = { meter(progress, function(percent) return percent or 0 end, theme.ACCENT) },
            },
            row {
                spacing = theme.spacing.sm,
                align_v = "center",
                visible = working,
                children = { spinner(working, theme.control.xs), cell("Working…", theme.DIM, theme.font.xs) },
            },
        },
    },
    column {
        width = "fill",
        visible = pacnew:map(function(files) return #files > 0 end),
        spacing = theme.spacing.xs,
        children = {
            section_header("config files to merge"),
            column {
                width = "fill",
                padding = { left = theme.spacing.sm, right = theme.spacing.sm },
                spacing = theme.spacing.xs,
                children = pacnew:map(function(files)
                    local rows = {}
                    for _, path in ipairs(files) do
                        rows[#rows + 1] = cell(path, theme.PEACH, theme.font.xs, {
                            width = "fill", wrap = "word", font = theme.mono_font,
                        })
                    end
                    return rows
                end),
            },
        },
    },
    column {
        width = "fill",
        spacing = theme.spacing.xs,
        padding = { left = theme.spacing.sm, right = theme.spacing.sm },
        visible = phase:map(function(current)
            return current == "checking" or current == "pending"
        end),
        children = {
            row {
                width = "fill",
                spacing = theme.spacing.md,
                children = package_columns("Package", "Installed", "Available", theme.TEXT_MUTED, theme.TEXT_MUTED,
                    theme.font.xs),
            },
            list {
                width = "fill",
                height = package_height,
                scroll = scroll("update_packages"),
                animate = { scroll = theme.scroll_ease },
                spacing = theme.spacing.xs,
                source = sorted_packages,
                itemfn = function(package)
                    if package.header then
                        local heading = section_header(string.format("%s · %d", package.header, package.count))
                        heading.foreground = theme.with_opacity(REPO_COLORS[package.repository] or theme.DIM,
                            theme.opacity.strong)
                        return heading
                    end
                    return row {
                        width = "fill",
                        height = theme.control.md,
                        align_v = "center",
                        spacing = theme.spacing.md,
                        children = package_columns(
                            package.name or "?",
                            package.old_version or "",
                            package.new_version or "",
                            needs_reboot(package.name or "") and theme.PEACH or theme.FG,
                            theme.ACCENT),
                    }
                end,
                key = function(package)
                    return package.header and ("repo:" .. package.repository) or package.name or "?"
                end,
            },
        },
    },
    column {
        width = "fill",
        visible = log_showing,
        spacing = theme.spacing.xs,
        children = {
            row {
                width = "fill",
                align_v = "center",
                children = {
                    cell(util.bold(mantle.updates:map(function(updates)
                        return service.install_failed(updates) and service.failure_reason(updates) or "Install log"
                    end)), mantle.updates:map(function(updates)
                        return service.install_failed(updates) and theme.RED or theme.DIM
                    end), theme.font.xs, { width = "fill", wrap = "word" }),
                    panel_action_icon(icons.copy, function()
                        local lines = log_lines:get() or {}
                        if #lines > 0 then
                            process.detach("wl-copy", { table.concat(lines, "\n") })
                        end
                    end, { slot = "updates-copy-log" }),
                },
            },
            list {
                width = "fill",
                height = theme.update_log_height,
                scroll = LOG_SCROLL,
                source = log_lines,
                spacing = theme.spacing.xs,
                itemfn = function(line)
                    return cell(line, service.first_match(line:lower(), LOG_COLOURS) or theme.DIM, theme.font.xs, {
                        width = "fill", wrap = "word", max_lines = 3, font = theme.mono_font,
                    })
                end,
            },
        },
    },
    panel_row {
        slot = "updates-settings",
        icon = icons.settings,
        title = "Include in updates",
        subtitle = settings_summary,
        expanded = settings_expanded,
        details = column {
            width = "fill",
            children = {
                aur_row,
                column {
                    width = "fill",
                    visible = service.tools_present:map(function(present)
                        return util.find(dev_tools, function(tool) return present[tool.requires] == true end) ~= nil
                    end),
                    children = util.concat({ tools_heading }, tool_rows),
                },
            },
        },
    },
    row {
        width = "fill",
        spacing = theme.spacing.sm,
        visible = service.result_showing,
        children = {
            action_button(util.choose(log_open, "Hide log", "View log"), function()
                log_open:set(not log_open:get())
            end, "updates-log", {
                tone = "quiet",
                width = "fill",
                visible = phase:map(function(current) return current == "done" end),
            }),
            action_button("Close", function()
                service.dismiss_notifications()
                service.dismissed:set(true)
                ui.close_panel()
            end, "updates-dismiss", { tone = "quiet", width = "fill" }),
        },
    },
}

return { kind = "updates", body = body }
