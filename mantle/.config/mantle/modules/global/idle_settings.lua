-- A modal, not a bar panel: the three-action AC/battery matrix needs both profiles visible, which
-- the panel host's 340px card cannot fit.
local theme = require("config.theme")
local icons = require("config.icons")
local cell = require("components.cell")
local glyph = require("components.glyph")
local toggle = require("components.toggle")
local panel_card = require("components.panel_card")
local panel_header = require("components.panel_header")
local panel_row = require("components.panel_row")
local divider = require("components.divider")
local panel_action_icon = require("components.panel_action_icon")
local ui_state = require("lib.ui_state")
local modal = require("components.modal")
local dropdown = require("components.dropdown")
local idle = require("lib.idle")
local store = require("lib.store")
local timeline_section = require("modules.global.idle_settings.timeline")
local util = require("lib.util")

local settings = store.idle:map(idle.read)
local running = computed({ settings, idle.inhibited }, function(resolved, held)
    return resolved.enabled and not held
end)

-- Shared by the flow card and each section.
local CARD_PADDING = {
    top = theme.spacing.md,
    right = theme.spacing.lg,
    bottom = theme.spacing.md,
    left = theme.spacing
        .lg
}

-- Whether UPower reports a battery. `present` is false on desktops, so no battery column.
local has_battery = mantle.battery:map(function(battery)
    return battery ~= nil and battery.present
end)

-- Between section rows, inset past the leading glyph.
local row_rule = divider { margin = { left = theme.icon.md + theme.spacing.sm * 2 } }

local header = panel_header {
    title = "Idle & power",
    subtitle = computed(
        { settings, idle.active_profile, idle.schedule, idle.elapsed, idle.reasons, idle.arming },
        function(resolved, profile, plan, elapsed, reasons, arming)
            if #reasons > 0 then
                return "Held awake · " .. table.concat(reasons, ", ")
            end
            if not resolved.enabled then
                return "Automatic actions are paused"
            end
            if plan.total == 0 then
                return "No actions enabled on this profile"
            end
            local where = profile == "battery" and "On battery" or "On AC power"
            if elapsed == 0 then
                local first = plan.list[1]
                return string.format("%s · %s after %s", where, first.title, idle.format(first.at))
            end
            -- The armed stage's own delay, not the running total: it answers "how long have I got".
            for _, entry in ipairs(plan.list) do
                if entry.key == arming.key then
                    return string.format("Idle %s · %s in %s", idle.clock(elapsed), entry.title,
                        idle.clock(math.max(0, entry.delay - arming.elapsed)))
                end
            end
            return string.format("Idle %s · every stage has run", idle.clock(elapsed))
        end
    ),
    -- The bar circle's glyph, so opener and modal read as one control.
    icon = idle.manual:map(function(manual)
        return manual and icons.awake or icons.idle
    end),
    -- A bar panel's half-sized default looks lost on an 820px-wide window.
    title_size = theme.font.xxl,
    plate = theme.control.xl,
    subtitle_size = theme.font.md,
    active = running,
    on_close = function()
        ui_state.close_modal("idle_settings")
    end,
}

-- Accent while `on` holds, else dim.
local function ink(on)
    return on:map(function(lit)
        return lit and theme.ACCENT or theme.DIM
    end)
end

-- One per profile and stage, built here because a popup is a surface and `stage_row` is rebuilt
-- on every reorder. A hand-edited stored value joins the options so the list still marks it.
local durations = {}
local popups = {}
for _, profile in ipairs({ "ac", "battery" }) do
    durations[profile] = {}
    for _, stage in ipairs(idle.STAGES) do
        local field = stage.key .. "_sec"
        local value = settings:map(function(resolved)
            return resolved[profile][field]
        end)
        local picker = dropdown {
            id = "idle-" .. profile .. "-" .. stage.key,
            parent = "modal_host",
            value = value,
            options = value:map(function(current)
                for _, sec in ipairs(stage.options) do
                    if sec == current then
                        return stage.options
                    end
                end
                local options = util.concat(stage.options, { current })
                table.sort(options)
                return options
            end),
            format = idle.format,
            on_select = function(sec)
                idle.write(profile, field, sec)
            end,
        }
        durations[profile][stage.key] = picker.trigger
        popups[#popups + 1] = picker.popup
    end
end

local function profile_control(profile, stage)
    return row {
        width = theme.idle_profile_column,
        align_v = "Center",
        spacing = theme.spacing.sm,
        visible = profile == "battery" and has_battery or nil,
        children = {
            durations[profile][stage.key](),
            toggle(settings, function(resolved)
                return resolved[profile][stage.key .. "_on"]
            end, function(enabled)
                idle.write(profile, stage.key .. "_on", enabled)
            end),
        },
    }
end

-- Marks the running profile's column.
local function column_heading(profile, label)
    return cell(
        util.bold(idle.active_profile:map(function(active)
            return active == profile and label .. " · live" or label
        end)),
        idle.active_profile:map(function(active)
            return active == profile and theme.ACCENT or theme.DIM
        end),
        theme.font.xs,
        { width = theme.idle_profile_column, align = "Center", visible = profile == "battery" and has_battery or nil }
    )
end

local matrix_heading = row {
    width = "Fill",
    align_v = "Center",
    spacing = theme.spacing.sm,
    padding = { left = theme.spacing.sm, right = theme.spacing.sm },
    children = {
        cell(util.bold("Action · in order"), theme.DIM, theme.font.xs, { width = "Fill" }),
        column_heading("ac", "AC power"),
        column_heading("battery", "Battery"),
    },
}

-- Chevrons move a stage through `order`. Hide them at the ends instead of showing no-op disabled
-- controls; `idle.move` already treats out-of-range moves as no-ops.
local function reorder(item)
    return column {
        align_v = "Center",
        children = {
            panel_action_icon(icons.chevron_up, function()
                idle.move(item.key, -1)
            end, { slot = "idle-up-" .. item.key, visible = not item.first }),
            panel_action_icon(icons.chevron_down, function()
                idle.move(item.key, 1)
            end, { slot = "idle-down-" .. item.key, visible = not item.last }),
        },
    }
end

local function stage_row(item)
    local stage = item.stage
    -- Accent while either profile enables this stage; dim in both columns means the stage never
    -- runs.
    local any = settings:map(function(resolved)
        for _, profile in ipairs({ "ac", "battery" }) do
            if resolved[profile][item.key .. "_on"] and resolved[profile][item.key .. "_sec"] > 0 then
                return true
            end
        end
        return false
    end)
    local body = panel_row {
        title = util.bold_when(any, stage.title),
        -- The stage's own description, not "after <the row above>": that row may be off in one
        -- profile.
        subtitle = stage.detail,
        height = theme.idle_row_height,
        leading = row {
            align_v = "Center",
            spacing = theme.spacing.xs,
            children = { reorder(item), glyph(stage.icon, ink(any), theme.icon.md, { align_v = "Center" }) },
        },
        trailing = row {
            spacing = theme.spacing.sm,
            align_v = "Center",
            children = { profile_control("ac", stage), profile_control("battery", stage) },
        },
    }
    return item.last and body or column { width = "Fill", children = { body, row_rule } }
end

-- One row per stage in stored `order`, as a `list` because declared children cannot be reordered.
-- Descriptors rebuild only when stored settings change: a reorder rebuilds rows, a tick none.
local stage_list = list {
    width = "Fill",
    source = settings:map(function(resolved)
        local items = {}
        for index, key in ipairs(resolved.order) do
            -- `idle.read` resolved `order` to known stages only.
            items[#items + 1] = {
                key = key,
                stage = idle.stage(key),
                first = index == 1,
                last = index == #resolved
                    .order
            }
        end
        return items
    end),
    key = function(item)
        return item.key
    end,
    itemfn = stage_row,
}

-- Non-timeout reasons the session stays up, neither of them per-profile.
local capture_hold = settings:map(function(resolved)
    return resolved.privacy_auto_inhibit
end)
local behaviour_rows = {
    panel_row {
        icon = icons.play,
        title = util.bold_when(capture_hold, "Keep awake while capturing"),
        -- Not video: a player asks for that itself and the engine honours it either way.
        subtitle = "Camera, microphone, screen capture",
        height = theme.idle_row_height,
        icon_color = ink(capture_hold),
        trailing = toggle(settings, function(resolved)
            return resolved.privacy_auto_inhibit
        end, function(on)
            idle.write(nil, "privacy_auto_inhibit", on)
        end),
    },
    row_rule,
    panel_row {
        icon = icons.awake,
        title = util.bold_when(idle.manual, "Keep awake now"),
        subtitle = "The same hold the bar circle takes",
        height = theme.idle_row_height,
        icon_color = ink(idle.manual),
        trailing = toggle(idle.manual, function(manual)
            return manual
        end, idle.set_manual),
    },
}

-- One compact line, not `panel_header`: the masthead already has a plate and bold title.
local flow_strip = row {
    width = "Fill",
    align_v = "Center",
    spacing = theme.spacing.sm,
    children = {
        glyph(icons.play, ink(running), theme.icon.sm, { align_v = "Center" }),
        cell(
            computed({ settings, idle.active_profile }, function(resolved, profile)
                if not resolved.enabled then
                    return "Automation paused"
                end
                return "Current flow · " .. (profile == "battery" and "battery" or "AC power")
            end),
            theme.FG,
            theme.font.sm,
            { width = "Fill", align_v = "Center" }
        ),
        toggle(settings, function(resolved)
            return resolved.enabled
        end, function(on)
            idle.write(nil, "enabled", on)
        end),
    },
}

local flow_card = panel_card(util.concat({ flow_strip }, timeline_section(settings)), {
    width = "Fill",
    spacing = theme.spacing.md,
    padding = CARD_PADDING,
    tone = running:map(function(on)
        return on and "active" or "standard"
    end),
})

-- `panel_header` already has the glyph-on-plate shape, so a section is a header plus rows.
local function section(codepoint, title, description, children)
    local heading = panel_header { title = title, subtitle = description, icon = codepoint, title_size = theme.font.xl }
    return panel_card(util.concat({ heading }, children), {
        width = "Fill",
        spacing = theme.spacing.sm,
        padding = CARD_PADDING,
        outlined = true,
    })
end

local idle_modal = modal({
    kind = "idle_settings",
    card = panel_card({
        header,
        -- Rule under the masthead: header is state, below is settings.
        divider(),
        flow_card,
        section(icons.sleep, "Automation", "Each stage waits for the one above it", { matrix_heading, stage_list }),
        section(icons.settings, "Behaviour", "What may keep the session awake", behaviour_rows),
    }, {
        width = theme.idle_modal_width,
        align_h = "Center",
        align_v = "Center",
        spacing = theme.spacing.lg,
        padding = theme.spacing.xl,
        tone = "dialog",
    }),
})
idle_modal.popups = popups
return idle_modal
