-- The update panel: one prebuilt view per `service.view`, switched through `children`.
-- `lib/update_model.lua` words the state; `lib/updates.lua` runs it.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local checkbox = require("components.checkbox")
local callout = require("components.callout")
local meter = require("components.meter")
local panel_card = require("components.panel_card")
local panel_empty_state = require("components.panel_empty_state")
local panel_header = require("components.panel_header")
local action_button = require("components.action_button")
local panel_action_icon = require("components.panel_action_icon")
local panel_row = require("components.panel_row")
local section_header = require("components.section_header")
local store = require("lib.store")
local ui = require("lib.ui_state")
local disclosure = require("lib.disclosure")
local service = require("lib.updates")
local model = require("lib.update_model")
local dev_tools = require("config.dev_tools")

local look, run, log_lines = service.look, service.run, service.log_lines
local LOG_SCROLL = scroll("update_log")
-- Disclosed rows start under their parent's title.
local INDENT = { left = theme.icon.md + theme.spacing.sm }

local settings_open = disclosure.state("updates_settings_expanded", false)
local pacnew_open = disclosure.state("updates_pacnew_open", false)

local checking = mantle.updates:map(function(updates) return updates.checking end, false)
local reboot = mantle.updates:map(function(updates) return updates.reboot_required end, false)
local has_pacnew = service.pacnew:map(function(files) return #files > 0 end)
local has_log = log_lines:map(function(lines) return #lines > 0 end)
local warning = look:map(function(current) return current.warning end)
local tools_runnable = computed({ store.updates_dev_tools, service.tools_present }, service.runnable_names, {})

local function check()
    mantle.updates:check()
end

-- Packages whose new version only runs after a reboot; tinted in the list.
local REBOOT = { systemd = true, glibc = true, ["amd-ucode"] = true, ["intel-ucode"] = true }

local function needs_reboot(name)
    return REBOOT[name] == true or name:find("^linux") ~= nil or name:find("^nvidia") ~= nil
end

-- Every install log line re-pushes `mantle.updates`, and past 256 entries the engine cannot see the
-- list is unchanged, so the check's stamp and count key the sort: a scalar the engine compares.
local sorted_packages = mantle.updates:map(function(updates)
    return string.format("%s:%d", updates.last_successful_check, #updates.packages)
end, ""):map(function()
    local list = util.concat((mantle.updates:get() or {}).packages)
    table.sort(list, function(left, right) return (left.name or "") < (right.name or "") end)
    return list
end)
local has_packages = sorted_packages:map(function(list) return #list > 0 end)

-- Versions wrap after their separators to a second line rather than hide their tail.
local function package_line(name, current, new, name_color, new_color, name_size)
    local function version(text, color)
        return cell((text:gsub("[.+:-]", "%0\u{200B}")), color, theme.font.xs,
            { width = theme.update_version_width, align = "end", align_v = "center", wrap = "word", max_lines = 2 })
    end
    return row {
        width = "fill",
        min_height = theme.control.sm,
        align_v = "center",
        spacing = theme.spacing.md,
        children = {
            cell(name, name_color, name_size or theme.font.sm, { width = "fill", align_v = "center" }),
            version(current, theme.DIM),
            version(new, new_color),
        },
    }
end

local package_card = panel_card({
    package_line("Package", "Installed", "Available", theme.TEXT_MUTED, theme.TEXT_MUTED, theme.font.xs),
    list {
        width = "fill",
        -- The capability keeps packages through a refresh, so this height holds until results arrive.
        height = sorted_packages:map(function(list)
            return util.fit_height(list, theme.update_list_height, theme.spacing.xs,
                function() return theme.control.sm end)
        end),
        scroll = scroll("update_packages"),
        animate = { scroll = theme.scroll_ease },
        spacing = theme.spacing.xs,
        items = sorted_packages,
        each = function(package)
            return package_line(package.name or "?", package.old_version or "", package.new_version or "",
                needs_reboot(package.name or "") and theme.PEACH or theme.FG, theme.ACCENT)
        end,
        key = function(package) return package.name or "?" end,
    },
}, { width = "fill", visible = has_packages })

-- Failures stand out in two hundred lines of pacman output.
local function log_colour(line)
    local lowered = line:lower()
    return (lowered:find("error", 1, true) or lowered:find("fail", 1, true)) and theme.RED
        or lowered:find("warning", 1, true) and theme.PEACH
        or (line:find("^▶") or line:find("^%[ OK %]") or line:find("^::")) and theme.FG or theme.DIM
end

-- ponytail: the log follows its newest line even after a scroll back. The offset trails `reveal` by a
-- layout pass, so user scrolls are undetectable; needs an engine "wheel moved this viewport" signal.
log_lines:on_change(function(lines)
    if #lines > 0 then
        LOG_SCROLL:reveal(#lines)
    end
end)

-- `height` fixes the running view's box; a result's grows with its lines up to the same height.
local function output(height)
    local label = section_header("Output")
    label.width = "fill"
    return column {
        width = "fill",
        spacing = theme.spacing.xs,
        visible = height ~= nil or has_log,
        children = {
            row {
                width = "fill",
                align_v = "center",
                children = {
                    label,
                    panel_action_icon(icons.copy, function()
                        process.detach("wl-copy", { table.concat(log_lines:get(), "\n") })
                    end, { slot = "updates-copy-log", visible = has_log }),
                },
            },
            panel_card({
                list {
                    width = "fill",
                    height = height and "fill",
                    max_height = height == nil and theme.update_log_height or nil,
                    visible = has_log,
                    scroll = LOG_SCROLL,
                    items = log_lines,
                    spacing = theme.spacing.xs,
                    each = function(line)
                        return cell(line, log_colour(line), theme.font.xs, {
                            width = "fill", wrap = "word", max_lines = 3, font = theme.mono_font,
                        })
                    end,
                },
                panel_empty_state("No output yet", log_lines:map(function(lines) return #lines == 0 end)),
            }, { width = "fill", height = height }),
        },
    }
end

-- The whole row toggles inclusion; the checkbox is its readback. Locked while a run reads them.
local function include_row(on, opts)
    local toggle = opts.on_activate
    opts.height = theme.control.md
    opts.opacity = util.choose(service.busy, theme.opacity.disabled, 1)
    opts.on_activate = function()
        if toggle and not service.busy:get() then
            toggle()
        end
    end
    opts.trailing = checkbox(on)
    return panel_row(opts)
end

local function settings_row()
    local rows = {
        include_row(store.updates_aur, {
            title = "AUR packages",
            subtitle = mantle.updates:map(function(updates)
                return updates.aur_helper and ("Through " .. updates.aur_helper) or "No AUR helper found"
            end, ""),
            on_activate = function()
                local on = not store.updates_aur:get()
                store:set("updates_aur", on)
                mantle.updates:configure({ interval = service.CHECK_INTERVAL, aur = on })
                check()
            end,
        }),
    }
    for _, tool in ipairs(dev_tools) do
        local included = store.updates_dev_tools:map(function(ticked) return ticked[tool.name] ~= false end)
        rows[#rows + 1] = include_row(included, {
            title = tool.name,
            visible = service.tools_present:map(function(present) return present[tool.requires] == true end),
            on_activate = function()
                store:set("updates_dev_tools", util.with(store.updates_dev_tools:get(), tool.name, not included:get()))
            end,
        })
    end
    return panel_row {
        icon = icons.settings,
        title = "Include in updates",
        subtitle = computed({ store.updates_aur, tools_runnable }, function(aur, names)
            return (aur and "AUR and " or "Repositories and ") .. model.plural(#names, "developer tool")
        end),
        expanded = settings_open,
        details = column { width = "fill", padding = INDENT, children = rows },
    }
end

local function pacnew_row()
    return panel_row {
        icon = icons.warning,
        icon_color = theme.PEACH,
        title = service.pacnew:map(function(files) return model.plural(#files, "config file") .. " to merge" end),
        subtitle = "Pacman left new or saved copies beside your configs",
        visible = has_pacnew,
        expanded = pacnew_open,
        details = column {
            width = "fill",
            padding = INDENT,
            children = service.pacnew:map(function(files)
                local rows = {}
                for index, path in ipairs(files) do
                    rows[index] = panel_row { title = path:match("[^/]+$"), subtitle = path:match("^(.*)/") or "/" }
                end
                return rows
            end),
        },
    }
end

-- A result's body states its detail, so its header keeps to the title.
local function header(trailing, title_only)
    return panel_header {
        title = "Updates",
        icon = look:map(function(current) return current.icon end),
        accent = look:map(function(current) return current.color end),
        subtitle = look:map(function(current)
            return (current.detail == "" or title_only) and current.title or (current.title .. " · " .. current.detail)
        end),
        trailing = trailing,
    }
end

local function primary(label, on_activate, slot, opts)
    opts.tone, opts.width = opts.tone or "accent", "fill"
    return action_button(label, on_activate, slot, opts)
end

local function quiet(label, on_activate, slot, glyph, opts)
    opts = opts or {}
    opts.tone, opts.glyph, opts.width = "quiet", glyph, "fill"
    return action_button(label, on_activate, slot, opts)
end

-- Merge configs and Restart… when they apply, then `extra` while `extra_shown`; Restart… asks first.
local function followups(extra, extra_shown)
    local merge = quiet("Merge configs", function()
        process.detach("xdg-terminal-exec", { "pacdiff", "--sudo" })
        ui.close_panel()
    end, "updates-merge", icons.command)
    local restart = quiet("Restart…", function() service.restart_asked:set(true) end, "updates-restart", icons.power)
    local confirm = {
        quiet("Cancel", function() service.restart_asked:set(false) end, "updates-restart-cancel"),
        primary("Restart now", function() process.detach("systemctl", { "reboot" }) end, "updates-restart-confirm",
            { tone = "danger", glyph = icons.power }),
    }
    local nodes = computed(
        { has_pacnew, reboot, service.restart_asked, extra_shown or reboot:map(function() return false end) },
        function(files, restart_on, asked, more)
            if restart_on and asked then
                return confirm
            end
            local list = {}
            if files then list[#list + 1] = merge end
            if restart_on then list[#list + 1] = restart end
            if more then list[#list + 1] = extra end
            return list
        end, {})
    return row {
        width = "fill",
        spacing = theme.spacing.sm,
        visible = nodes:map(function(list) return #list > 0 end),
        children = nodes,
    }
end

local function view(name, children)
    return column { id = "updates-" .. name, width = "fill", spacing = theme.spacing.md, children = children }
end

-- Idle and pending: Check now until there are packages, then Update all with a refresh beside the title.
local idle = view("idle", {
    header({ panel_action_icon(icons.refresh, check, {
        slot = "updates-refresh", spinning = checking, disabled = service.busy, visible = has_packages,
    }) }),
    primary(checking:map(function(on) return on and "Checking…" or "Check now" end), check, "updates-check", {
        glyph = checking:map(function(on) return on and "" or icons.refresh end),
        spinning = checking,
        disabled = service.busy,
        visible = has_packages:map(function(on) return not on end),
    }),
    primary("Update all", service.install, "updates-install",
        { glyph = icons.updates, disabled = service.busy, visible = has_packages }),
    callout(icons.warning, warning, { tone = "neutral", visible = warning:map(function(text) return text ~= "" end) }),
    package_card,
    pacnew_row(),
    settings_row(),
    followups(quiet(tools_runnable:map(function(names) return "Update " .. model.plural(#names, "developer tool") end),
        function() service.update_tools(tools_runnable:get()) end, "updates-tools-only", icons.updates,
        { disabled = service.busy }), computed({ tools_runnable, has_packages }, function(names, pending)
        return #names > 0 and not pending
    end, false)),
})

local running = view("running", {
    header(),
    panel_card({
        meter(service.progress, function(progress)
            return progress.total > 0 and 100 * progress.done / progress.total or 0
        end, theme.ACCENT, nil, {
            indeterminate = service.progress:map(function(progress) return progress.count == "" end),
        }),
    }, { width = "fill" }),
    output(theme.update_log_height),
})

local outcome = run:map(model.outcome)
local ACTIONS = {
    failed = { primary("Retry update", service.install, "updates-retry", { glyph = icons.refresh, disabled = service.busy }) },
    issues = {
        primary(run:map(function(current) return "Retry " .. model.plural(#(current.failures or {}), "tool") end),
            service.retry_tools, "updates-retry-tools", { glyph = icons.refresh, disabled = service.busy }),
        primary("Update all", service.install, "updates-install-pending",
            { glyph = icons.updates, disabled = service.busy, visible = has_packages }),
    },
    done = { primary("Done", ui.close_panel, "updates-done", { glyph = icons.check }) },
}
local summary = run:map(function(current) return model.summary(current) or "" end)

local result = view("result", {
    header(nil, true),
    callout(icons.update_err, run:map(function(current) return current.reason or "" end), {
        visible = outcome:map(function(name) return name == "failed" end),
    }),
    row { width = "fill", spacing = theme.spacing.sm, children = outcome:map(function(name) return ACTIONS[name] end) },
    list {
        width = "fill",
        visible = run:map(function(current) return #(current.failures or {}) > 0 end),
        items = run:map(function(current) return current.failures or {} end),
        key = function(failure) return failure.name end,
        each = function(failure)
            return panel_row { icon = icons.warning, icon_color = theme.PEACH, title = failure.name, subtitle = failure.reason }
        end,
    },
    panel_row {
        icon = icons.check,
        icon_color = theme.GREEN,
        title = summary,
        subtitle = run:map(function(current) return current.finished_at and ("Took " .. model.took(current)) or "" end),
        visible = summary:map(function(text) return text ~= "" end),
    },
    panel_row {
        icon = icons.updates,
        icon_color = theme.ACCENT,
        title = mantle.updates:map(function(updates) return model.plural(#updates.packages, "update") .. " available" end, ""),
        visible = has_packages,
    },
    pacnew_row(),
    output(),
    followups(quiet("Dismiss", service.dismiss, "updates-dismiss"), outcome:map(function(name) return name ~= "done" end)),
})

local VIEWS = { idle = idle, running = running, result = result }

return {
    kind = service.KIND,
    width = theme.update_panel_width,
    body = service.view:map(function(name) return { VIEWS[name] } end),
}
