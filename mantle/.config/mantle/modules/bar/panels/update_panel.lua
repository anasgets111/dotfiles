-- Pending updates, download size, and the install button in front of the list. The bar only
-- reports the count; installs happen here.
--
-- This file owns wording, formatting, and thresholds; `mantle.updates` stays unchanged. The
-- Supervisor publishes `install_exit_code` and pacman's output; "failed retrieving file" becomes
-- "could not download; check the connection". Numbers are language-neutral; that sentence is not.
--
-- `modules/bar/indicators/updates.lua` schedules the checks on the cadence
-- declared below and installs from the notification action through `install` here.
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
local dev_tools = require("config.dev_tools")

local KIND = "updates"
-- Check hourly: a badge is read on that scale, and each check is a real `-Sy` against a mirror. The
-- indicator schedules on it and `last_check_line` calls twice this stale.
local CHECK_INTERVAL = 3600
local PACKAGE_SCROLL = scroll("update_packages")
local LOG_SCROLL = scroll("update_log")

-- Close clears this and the next install sets it. "I have read the result" belongs to the panel,
-- not pacman.
local dismissed = state("updates_result_dismissed", false)

-- Stamp the install-start click: `install_finished_at` is published, and the click is the only
-- known start. Config writes are allowed only in input callbacks.
local started_at = state("updates_install_started_at", 0)

-- A failed run shows its log unasked; a successful one hides it behind a button.
local log_open = state("updates_log_open", false)

-- The tick list replaces the body, as every other view here does.
local settings_open = state("updates_settings_open", false)

-- Which `requires` binaries are on `PATH`. Lua cannot stat `PATH`, so this is probed once per
-- process from the first capability push below; `state` is name-keyed, so an in-place reload keeps
-- the answer rather than blanking the list until the probe re-answers.
local tools_present = state("updates_tools_present", {})

-- The dev chain's only state: which `config/dev_tools.lua` entry is running, and its output.
-- `install_log` stays the capability's; the two are concatenated for display.
local dev_running = state("updates_dev_tool", "")
local dev_log = state("updates_dev_log", {})
-- Empty until this run's tools finish, then when they did and which failed. A table seed, since
-- named state refuses a value of another type.
local dev_result = state("updates_dev_result", {})

local function packages(u)
    return (u and u.packages) or {}
end

-- KiB, MiB, GiB use 1024, matching pacman's package sizes.
local function human_bytes(bytes)
    local size = bytes or 0
    if size < 1024 then
        return string.format("%d B", size)
    end
    for _, unit in ipairs({ "KiB", "MiB", "GiB" }) do
        size = size / 1024
        if size < 1024 or unit == "GiB" then
            return string.format("%.1f %s", size, unit)
        end
    end
    return string.format("%d B", bytes or 0)
end

local function download_total(u)
    local total = 0
    for _, package in ipairs(packages(u)) do
        total = total + (package.download_size or 0)
    end
    return total
end

-- A run that ended. `install_finished_at` marks one the manager answered; a spawn failure publishes
-- only `install_error` and never stamps it (`controller.rs` returns early).
local function install_ended(u)
    return u ~= nil and (u.install_finished_at ~= nil or u.install_error ~= nil)
end

-- True while a finished install's result remains on screen. The capability deliberately has no
-- "completed" state, which would end when read.
--
-- A tools-only run has a result too, and the tools after an install are still part of its run.
local result_showing = computed({ mantle.updates, dismissed, dev_running, dev_result },
    function(u, is_dismissed, tool, dev)
        return not is_dismissed and tool == "" and u ~= nil and not u.installing and (install_ended(u) or dev.finished_at ~= nil)
    end)

-- Whether this run included packages: a tools-only run leaves the last install's count and log.
local function ran_packages(u)
    return u ~= nil and (u.install_finished_at or 0) >= (started_at:get() or 0)
end

-- A manager killed by a signal publishes no exit code, so an absent one on a run the manager
-- answered is a failure, not a success.
local function install_failed(u)
    return install_ended(u) and (u.install_error ~= nil or u.install_exit_code ~= 0)
end

local status_tone = computed({ mantle.updates, dismissed, dev_running, dev_result }, function(u, is_dismissed, tool, dev)
    if not is_dismissed and install_failed(u) then
        return "error"
    end
    if (u ~= nil and u.check_error ~= nil) or (not is_dismissed and #(dev.failures or {}) > 0) then
        return "warning"
    end
    if tool == "" and u ~= nil and (u.install_finished_at ~= nil or dev.finished_at) and not install_failed(u) then
        return "active"
    end
    return "standard"
end)

-- Absent means on, so a tool added to `config/dev_tools.lua` runs without a `state.json` edit.
local function tool_enabled(name)
    return (store.updates_dev_tools:get() or {})[name] ~= false
end

-- Present as well as ticked: a run of nothing but `[SKIP]` lines is not worth a button.
local function any_tool_runnable()
    local present = tools_present:get() or {}
    for _, tool in ipairs(dev_tools) do
        if tool_enabled(tool.name) and present[tool.requires] then
            return true
        end
    end
    return false
end

-- `name`'s place among the tools this run will actually start.
local function tool_step(name)
    local present = tools_present:get() or {}
    local step, total = 0, 0
    for _, tool in ipairs(dev_tools) do
        if tool_enabled(tool.name) and present[tool.requires] then
            total = total + 1
            if tool.name == name then
                step = total
            end
        end
    end
    return step, total
end

local NOTIFICATION_ID = "8001"

-- Dismissing closes the card, which also ends a waiting `notify-send --wait`.
local function dismiss_notifications()
    local n = mantle.notifications:get()
    for _, notif in ipairs((n and n.feed) or {}) do
        if notif.app_name == "System Updates" then
            mantle.notifications:invoke("dismiss", notif.id)
        end
    end
end

-- Replaces any pending update offer so completed/failed toasts never pile on top. The action's
-- listener is detached and calls back through `mantle call`: a `process.run` listener died with the
-- generation, so after any reload the button reached nobody.
local function toast(urgency, title, body, action)
    dismiss_notifications()
    local args = {
        "-u", urgency,
        "-a", "System Updates",
        "-i", "system-software-update",
        "--replace-id", NOTIFICATION_ID,
    }
    if not action then
        return process.detach("notify-send", util.concat(args, { title, body }))
    end
    process.detach("sh", util.concat({
        "-c", 'notify-send "$@" | grep -q run-updates && mantle call updates.install', "sh",
    }, util.concat(args, { "--wait", "-A", "run-updates=" .. action, title, body })))
end

-- ponytail: unbounded, unlike the Supervisor's 200-line tail. A dev run prints hundreds of lines,
-- not thousands; cap it here if one ever does.
local function append_dev_log(line)
    dev_log:set(util.concat(dev_log:get(), { line }))
end

-- Stops at the first non-zero exit.
local function run_commands(commands, index, done)
    local command = commands[index]
    if command == nil then
        return done(true)
    end
    process.run(command[1], { table.unpack(command, 2) }, append_dev_log, function(code)
        if code ~= 0 then
            log.error("update:", table.concat(command, " "), "exited", code)
            return done(false)
        end
        run_commands(commands, index + 1, done)
    end)
end

-- Only this file knows when the last tool exited.
local function report_run(u, failures)
    if install_failed(u) then
        return toast("critical", "Update failed", "The updates panel has pacman's output")
    end
    if #failures > 0 then
        return toast("critical", "Update finished with failures", table.concat(failures, ", "))
    end
    local count = ran_packages(u) and u.install_total_steps or 0
    local tools = any_tool_runnable() and " and developer tooling" or ""
    toast("normal", "Update complete", count > 0
        and string.format("%d package%s%s updated", count, count == 1 and "" or "s", tools)
        or "Developer tooling updated")
end

-- Walks `config/dev_tools.lua`, carrying the failures so far. `command -v` takes the name as `$1`
-- rather than interpolated. `[SKIP]`, `▶` and `[ OK ]` are the markers `log_colour` already tints.
local function run_tools(index, failures)
    local tool = dev_tools[index]
    if tool == nil then
        dev_running:set("")
        dev_result:set({ finished_at = os.time(), failures = failures })
        return report_run(mantle.updates:get(), failures)
    end
    if not tool_enabled(tool.name) then
        return run_tools(index + 1, failures)
    end
    process.run("sh", { "-c", 'command -v "$1" >/dev/null', "sh", tool.requires }, function() end, function(code)
        if code ~= 0 then
            append_dev_log(string.format("[SKIP] %s (%s not found)", tool.name, tool.requires))
            return run_tools(index + 1, failures)
        end
        dev_running:set(tool.name)
        append_dev_log("▶ " .. tool.name)
        run_commands(tool.run, 1, function(ok)
            append_dev_log((ok and "[ OK ] " or "[FAIL] ") .. tool.name)
            if not ok then
                failures[#failures + 1] = tool.name
            end
            run_tools(index + 1, failures)
        end)
    end)
end

local function start_dev_tools()
    dev_log:set({})
    run_tools(1, {})
end

-- Exported, and `updates.install` for the notification's detached action listener.
--
-- A retry runs with no pending count: a run that failed partway can leave the count at zero with
-- the system still half-upgraded, and refusing there left the failure card holding a dead button.
local function install()
    local u = mantle.updates:get()
    if u == nil or u.installing or dev_running:get() ~= "" then
        return
    end
    local packages_pending = (u.count or 0) > 0 or install_failed(u)
    if not packages_pending and not any_tool_runnable() then
        return
    end
    dismiss_notifications()
    started_at:set(os.time())
    dismissed:set(false)
    dev_result:set({})
    log_open:set(false)
    settings_open:set(false)
    if packages_pending then
        return mantle.updates:invoke("install")
    end
    start_dev_tools()
end
action("updates.install", install)

-- Pacman's output supplies the reason, and this file turns it into actionable wording. Falls back
-- to the exit code, which is at least true.
local FAILURE_PHRASES = {
    { match = "failed retrieving",            say = "Could not download; check the connection" },
    { match = "could not resolve host",       say = "Could not download; check the connection" },
    { match = "connection refused",           say = "Could not download; check the connection" },
    { match = "not enough free disk space",   say = "Not enough disk space" },
    { match = "invalid or corrupted package", say = "A package failed its signature check" },
    { match = "signature from",               say = "A package failed its signature check" },
    { match = "conflicting files",            say = "Files conflict with another package" },
    { match = "authentication",               say = "Authentication failed" },
}

local function failure_reason(u)
    if u == nil then
        return "The install failed"
    end
    for _, line in ipairs(u.install_log or {}) do
        local lowered = line:lower()
        for _, phrase in ipairs(FAILURE_PHRASES) do
            if lowered:find(phrase.match, 1, true) then
                return phrase.say
            end
        end
    end
    if u.install_error ~= nil then
        return "The updater could not be started"
    end
    if u.install_exit_code == nil then
        return "pacman was killed before it finished"
    end
    return string.format("pacman exited with %d", u.install_exit_code)
end

-- ponytail: `install_log` is the last 200 lines, so a run longer than that undercounts. The
-- Supervisor would have to keep the counter for an exact one.
local function warning_count(u)
    local count = 0
    for _, line in ipairs(u.install_log or {}) do
        if line:lower():find("warning", 1, true) then
            count = count + 1
        end
    end
    return count
end

-- `is_dismissed` is a parameter, not a `dismissed:get()`: a signal read inside a map over
-- `mantle.updates` alone never re-runs on close.
local function status_line(u, is_dismissed, tool, dev)
    if u == nil then
        return "Waiting for the updater"
    end
    if tool ~= "" then
        return "Updating " .. tool
    end
    if u.installing then
        local package = u.install_current_package
        return (package ~= nil and package ~= "") and ("Installing " .. package) or "Preparing update…"
    end
    if not is_dismissed and (install_ended(u) or dev.finished_at) then
        if install_failed(u) then
            return "Update failed"
        end
        return #(dev.failures or {}) > 0 and "Update finished with failures" or "Update complete"
    end
    if u.checking then
        return "Checking…"
    end
    if u.check_error ~= nil then
        return "Check failed"
    end
    if (u.count or 0) > 0 then
        return string.format("%d update%s available", u.count, u.count == 1 and "" or "s")
    end
    return "Up to date"
end

local function detail_line(u, is_dismissed, tool, dev)
    if u == nil then
        return ""
    end
    if tool ~= "" then
        return string.format("Developer tooling · %d of %d", tool_step(tool))
    end
    if u.installing then
        local total = u.install_total_steps or 0
        if total > 0 then
            return string.format("Package %d of %d", u.install_current_step or 0, total)
        end
        -- No step line yet means pacman is downloading, and it prints nothing per package without a
        -- tty. `alpm` already sized the transaction, so say what is being fetched rather than that
        -- we were not told.
        return string.format("Downloading %d package%s · %s", u.count, u.count == 1 and "" or "s",
            human_bytes(download_total(u)))
    end
    if not is_dismissed and (install_ended(u) or dev.finished_at) then
        -- The reason heads the log card, beside the output it came from.
        local start = started_at:get() or 0
        local seconds = (dev.finished_at or u.install_finished_at or os.time()) - start
        local time_str = (start > 0 and seconds >= 0) and (seconds < 60 and string.format("%d sec", seconds)
            or string.format("%d min %d sec", math.floor(seconds / 60), seconds % 60))
        if install_failed(u) then
            return time_str and ("Failed after " .. time_str) or "See the log below"
        end
        local ran = ran_packages(u)
        local warnings = ran and warning_count(u) or 0
        local noted = warnings > 0 and string.format(" · %d warning%s", warnings, warnings == 1 and "" or "s") or ""
        local failed = #(dev.failures or {}) > 0 and (" · " .. table.concat(dev.failures, ", ") .. " failed") or ""
        local count = ran and (u.install_total_steps or 0) or 0
        local count_prefix = count > 0 and string.format("%d package%s · ", count, count == 1 and "" or "s") or ""
        return count_prefix .. (time_str and ("took " .. time_str) or "Finished") .. noted .. failed
    end
    -- A failed check keeps the last good list, so say which list is shown.
    if u.check_error ~= nil then
        local failures = u.consecutive_check_failures or 0
        -- Five consecutive failures is the warning threshold.
        local repeated = failures >= 5 and string.format(" · %d in a row", failures) or ""
        return "Last result kept · " .. u.check_error:match("[^\n]*") .. repeated
    end
    if (u.count or 0) > 0 then
        return string.format("%s to download", human_bytes(download_total(u)))
    end
    return "Nothing pending"
end

-- Include the date when the check is not today. "checked 07:08" in a shell running since Tuesday
-- falsely reads as this morning.
--
-- Past two intervals, say so: a suspended laptop otherwise shows an old count with nothing marking
-- it old. Errors are not handled here; `detail_line` already covers them.
local function last_check_line(u, now)
    if u == nil or u.last_successful_check == nil then
        return "Never checked"
    end
    local at = u.last_successful_check
    local when = os.date("%Y-%m-%d", at) == os.date("%Y-%m-%d") and os.date("%H:%M", at)
        or os.date("%b %d, %H:%M", at)
    return "Checked " .. when .. (now - at > CHECK_INTERVAL * 2 and " · stale" or "")
end

-- Packages whose new version only runs after a reboot, tinted in the list so that is known before
-- installing rather than from the badge after.
local REBOOT_PATTERNS = { "^linux", "^nvidia", "^systemd$", "^glibc$", "^amd%-ucode$", "^intel%-ucode$" }

local function needs_reboot(name)
    for _, pattern in ipairs(REBOOT_PATTERNS) do
        if name:find(pattern) then
            return true
        end
    end
    return false
end

-- Sort by name; `alpm`'s installed-database order has no useful reading order.
local sorted_packages = mantle.updates:map(function(u)
    local list = {}
    for _, package in ipairs(packages(u)) do
        list[#list + 1] = package
    end
    table.sort(list, function(left, right)
        return (left.name or "") < (right.name or "")
    end)
    return list
end)

-- Two owners, one view: the capability clears `install_log` per install, the chain appends after.
local log_lines = computed({ mantle.updates, dev_log }, function(u, lines)
    return util.concat(u and u.install_log, lines)
end)

-- Red failures are findable in two hundred lines of pacman output.
local function log_colour(line)
    local lowered = line:lower()
    if lowered:find("[fail]", 1, true) or lowered:find("error", 1, true) or lowered:find("failed", 1, true) then
        return theme.RED
    end
    if lowered:find("warning", 1, true) or lowered:find("[skip]", 1, true) then
        return theme.PEACH
    end
    if lowered:find("downloading", 1, true) or lowered:find("retrieving", 1, true) or lowered:find("installing", 1, true) or lowered:find("upgrading", 1, true) or lowered:find("%(%s*%d+/%d+%)") then
        return theme.ACCENT
    end
    if lowered:find("[ ok ]", 1, true) or lowered:find("complete", 1, true) or lowered:find("up to date", 1, true) then
        return theme.GREEN
    end
    if line:sub(1, 1) == "▶" or line:sub(1, 2) == "::" or line:sub(1, 3) == "==>" then
        return theme.FG
    end
    return theme.DIM
end

local not_settings = settings_open:map(function(open)
    return not open
end)

-- The tick list takes the whole body, so every other view yields to it.
local function unless_settings(showing)
    return computed({ showing, settings_open }, function(visible, settings)
        return visible and not settings
    end)
end

-- One fixed-height card holds the spinner and then the list, so a check does not resize the panel.
-- With nothing pending the status card alone says so.
local packages_showing = unless_settings(computed({ mantle.updates, result_showing, dev_running },
    function(u, showing, tool)
        return not showing and tool == "" and u ~= nil and not u.installing and (u.checking or #packages(u) > 0)
    end))
-- Nothing pending and nothing to report: the empty state stands in for the status card.
local empty_showing = unless_settings(computed({ mantle.updates, result_showing, dev_running },
    function(u, showing, tool)
        return not showing and tool == "" and u ~= nil and not u.installing and not u.checking
            and u.check_error == nil and (u.count or 0) == 0
    end))
local status_showing = computed({ settings_open, empty_showing }, function(settings, empty)
    return not settings and not empty
end)
local checking = util.shown_when(mantle.updates, function(u)
    return u.checking
end)
local listing = util.shown_when(mantle.updates, function(u)
    return not u.checking
end)

local log_showing = unless_settings(computed({ mantle.updates, result_showing, log_open, dev_running },
    function(u, showing, open, tool)
        return u ~= nil and (u.installing or tool ~= "" or (showing and (install_failed(u) or open)))
    end))

-- Follow the newest line. Every push reveals, not only the lengthening ones: the log is a 200-line
-- tail, so past that the content changes while the length does not.
--
-- Not gated on `installing`: the exit push carries the drained stderr, which is where a failure says
-- why.
--
-- ponytail: scrolling back during an install does not stop the follow, so a user reading an
-- earlier line is dragged to the end by the next one. Pausing on scroll needs detecting
-- user-initiated movement; the offset alone cannot stand in for that, because `reveal` lands in a
-- later layout pass than the read (`lua-meta/signals.lua`), so a recorded offset always trails the
-- real one by a reveal and a scroll back above it is indistinguishable from sitting at the end.
-- Wants an engine-side "the wheel moved this viewport" signal.
mantle.updates:on_change(function(u, previous)
    if previous == nil then
        -- One shell for every tool, not one per tool: this runs on each process start.
        local names = {}
        for _, tool in ipairs(dev_tools) do
            names[#names + 1] = tool.requires
        end
        local found = {}
        process.run("sh", { "-c", 'for n; do command -v "$n" >/dev/null && echo "$n"; done', "sh", table.unpack(names) },
            function(line)
                found[line] = true
            end, function()
                tools_present:set(found)
            end)
    end
    local lines = u ~= nil and #(u.install_log or {}) or 0
    if lines > 0 then
        LOG_SCROLL:reveal(lines)
    end
    -- Keyed on the stamp moving, like `indicators/updates.lua`: pushes coalesce, and a spawn
    -- failure raises and clears `installing` too fast for an edge watcher to see the rise.
    if previous == nil or u == nil or u.installing or not install_ended(u) then
        return
    end
    if u.install_finished_at == previous.install_finished_at and u.install_error == previous.install_error then
        return
    end
    -- Whatever just installed is still in `packages`, and nothing else clears it until the hourly
    -- tick. A half-finished run leaves a stale list too, so re-check on failure as well.
    mantle.updates:invoke("check")
    if install_failed(u) then
        -- A half-upgraded system is the wrong place to rebuild a toolchain against.
        return report_run(u, {})
    end
    start_dev_tools()
end)

-- One row per `config/dev_tools.lua` entry; the subtitle is the binary it needs, so a row ticked on
-- a machine without it reads as the `[SKIP]` it will produce.
local tool_rows = {}
for _, tool in ipairs(dev_tools) do
    tool_rows[#tool_rows + 1] = panel_row {
        title = tool.name,
        subtitle = tool.requires,
        -- Nothing to decide about a tool this machine cannot run.
        visible = tools_present:map(function(present)
            return (present or {})[tool.requires] == true
        end),
        trailing = toggle(store.updates_dev_tools, function(ticked)
            return (ticked or {})[tool.name] ~= false
        end, function(on)
            local ticked = {}
            for key, value in pairs(store.updates_dev_tools:get() or {}) do
                ticked[key] = value
            end
            ticked[tool.name] = on
            store:set("updates_dev_tools", ticked)
        end),
    }
end

-- Busy dims the header's refresh and the install button rather than hiding them, so the row keeps
-- its layout.
local busy = computed({ mantle.updates, dev_running }, function(u, tool)
    return u == nil or u.checking or u.installing or tool ~= ""
end)

-- Percent through this run's packages, then its tools; `false` while there is no count to show.
local progress = computed({ mantle.updates, dev_running }, function(u, tool)
    if tool ~= "" then
        local step, total = tool_step(tool)
        return total > 0 and 100 * step / total or false
    end
    local total = (u and u.installing and u.install_total_steps) or 0
    return total > 0 and 100 * (u.install_current_step or 0) / total or false
end)

-- Config files pacman would not overwrite, from `warning: X installed as X.pacnew`; each wants a
-- merge by hand, which a warning count alone does not say.
local pacnew = computed({ mantle.updates, result_showing }, function(u, showing)
    local files = {}
    if not (showing and ran_packages(u)) then
        return files
    end
    for _, line in ipairs(u.install_log or {}) do
        local path = line:match("installed as (%S+%.pacnew)") or line:match("saved as (%S+%.pacsave)")
        if path then
            files[#files + 1] = path
        end
    end
    return files
end)

-- "Working…": installing before pacman has counted the packages.
local working = util.shown_when(mantle.updates, function(u)
    return u.installing and (u.install_total_steps or 0) == 0
end)

local body = {
    panel_header {
        title = "Updates",
        icon = mantle.updates:map(function(u)
            if u ~= nil and u.installing then
                return icons.updating
            end
            if u ~= nil and u.checking then
                return icons.checking
            end
            return ((u and u.count) or 0) > 0 and icons.updates or icons.up_to_date
        end),
        active = mantle.updates:map(function(u)
            return ((u and u.count) or 0) > 0 or (u ~= nil and (u.installing or u.checking))
        end),
        subtitle = computed({ mantle.updates, mantle.system }, function(u, clock)
            return last_check_line(u, (clock and clock.time) or os.time())
        end),
        trailing = {
            info_badge("Reboot required", theme.PEACH, {
                visible = util.shown_when(mantle.updates, function(u)
                    return u.reboot_required == true
                end),
            }),
            panel_action_icon(icons.settings, function()
                settings_open:set(not settings_open:get())
            end, { slot = "updates-settings" }),
            panel_action_icon(icons.refresh, function()
                mantle.updates:invoke("check")
            end, { slot = "updates-refresh", disabled = busy }),
        },
    },
    panel_card({
        cell(computed({ mantle.updates, dismissed, dev_running, dev_result }, function(u, is_dismissed, tool, dev)
            return { { text = status_line(u, is_dismissed, tool, dev), bold = true } }
        end), theme.FG, theme.font.md),
        cell(computed({ mantle.updates, dismissed, dev_running, dev_result }, detail_line), theme.DIM, theme.font.xs),
        row {
            width = "Fill",
            visible = progress:map(function(percent)
                return percent ~= false
            end),
            children = {
                meter(progress, function(percent)
                    return percent or 0
                end, theme.ACCENT, "Fill"),
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
                cell({ { text = "Package", bold = true } }, theme.DIM, theme.font.xs, { width = "Fill" }),
                cell({ { text = "Current", bold = true } }, theme.DIM, theme.font.xs, {
                    width = theme.update_version_width,
                    align = "End",
                }),
                cell({ { text = "New", bold = true } }, theme.DIM, theme.font.xs, { width = theme.update_version_width }),
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
            visible = listing,
            scroll = PACKAGE_SCROLL,
            spacing = theme.spacing.xs,
            source = sorted_packages,
            itemfn = function(package)
                return row {
                    width = "Fill",
                    height = theme.control.sm,
                    align_v = "Center",
                    spacing = theme.spacing.sm,
                    children = {
                        cell(package.name or "?", needs_reboot(package.name or "") and theme.PEACH or theme.FG, theme.font.sm, { width = "Fill", align_v = "Center" }),
                        cell(package.old_version or "", theme.DIM, theme.font.xs, {
                            width = theme.update_version_width,
                            align = "End",
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
                return package.name or "?"
            end,
        },
    }, { background = theme.GLASS_CONTENT, width = "Fill", visible = packages_showing }),
    panel_card({
        row {
            width = "Fill",
            align_v = "Center",
            children = {
                cell(mantle.updates:map(function(u)
                    return { { text = install_failed(u) and failure_reason(u) or "Install log", bold = true } }
                end), mantle.updates:map(function(u)
                    return install_failed(u) and theme.RED or theme.DIM
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
                return cell(line, log_colour(line), theme.font.xs, {
                    width = "Fill",
                    wrap = "Word",
                    max_lines = 3,
                    font = theme.mono_font,
                })
            end,
        },
    }, {
        tone = mantle.updates:map(function(u)
            return u ~= nil and install_failed(u) and "error" or "standard"
        end),
        width = "Fill",
        visible = log_showing,
    }),
    panel_card({ section_header("run with package updates"), column {
        width = "Fill",
        children = tool_rows,
    } }, { background = theme.GLASS_CONTENT, width = "Fill", visible = settings_open }),
    action_button("Done", function()
        settings_open:set(false)
    end, "updates-settings-done", { tone = "quiet", width = "Fill", visible = settings_open }),
    row {
        width = "Fill",
        spacing = theme.spacing.sm,
        visible = not_settings,
        children = {
            action_button(
                computed({ mantle.updates, result_showing, dev_running }, function(u, showing, tool)
                    if u ~= nil and (u.installing or tool ~= "") then
                        return "Updating…"
                    end
                    if showing and install_failed(u) then
                        return "Retry"
                    end
                    return ((u and u.count) or 0) > 0 and "Update" or "Update dev tools"
                end),
                install,
                "updates-install",
                {
                    tone = "solid",
                    width = "Fill",
                    disabled = busy,
                    visible = computed({ mantle.updates, result_showing, dev_running }, function(u, showing, tool)
                        if u == nil or (showing and not install_failed(u)) then
                            return false
                        end
                        return u.installing or tool ~= "" or (u.count or 0) > 0 or showing or any_tool_runnable()
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
                    visible = computed({ result_showing, mantle.updates }, function(showing, u)
                        return showing and not install_failed(u)
                    end),
                }
            ),
            action_button("Close", function()
                dismiss_notifications()
                dismissed:set(true)
                log_open:set(false)
                ui.close_panel()
            end, "updates-dismiss", { tone = "quiet", width = "Fill", visible = result_showing }),
        },
    },
}

return {
    kind = KIND,
    body = body,
    install = install,
    install_failed = install_failed,
    install_ended = install_ended,
    dismiss_notifications = dismiss_notifications,
    toast = toast,
    result_showing = result_showing,
    CHECK_INTERVAL = CHECK_INTERVAL,
}
