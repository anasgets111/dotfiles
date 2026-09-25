-- A modal, not a bar panel: each stage shows every duration for AC and battery at once, which the
-- panel host's 340px card cannot fit.
local theme = require("config.theme")
local icons = require("config.icons")
local glyph = require("components.glyph")
local toggle = require("components.toggle")
local panel_card = require("components.panel_card")
local panel_header = require("components.panel_header")
local panel_row = require("components.panel_row")
local section_header = require("components.section_header")
local panel_action_icon = require("components.panel_action_icon")
local ui_state = require("lib.ui_state")
local modal = require("components.modal")
local segmented = require("components.segmented")
local idle = require("lib.idle")
local store = require("lib.store")
local timeline_section = require("modules.global.idle_settings.timeline")
local util = require("lib.util")

local settings = store.idle:map(idle.read)
local running = computed({ settings, idle.inhibited }, function(resolved, held)
    return resolved.enabled and not held
end)

-- Whether UPower reports a battery. `present` is false on desktops, so no battery column.
local has_battery = mantle.battery:map(function(battery)
    return battery ~= nil and battery.present
end)

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
    -- A modal's masthead: one step up from a bar panel's.
    title_size = theme.font.xl,
    subtitle_size = theme.font.sm,
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

-- Which profile the bars edit: the live one until a click on the picker says otherwise. A desktop
-- has no battery, so no picker, and the bars are AC.
local PROFILES = { "ac", "battery" }
local picked = state("idle_profile_picked", "")
local shown_profile = computed({ picked, idle.active_profile, has_battery }, function(chosen, active, battery)
    if not battery then
        return "ac"
    end
    return chosen ~= "" and chosen or active
end)

local profile_picker = segmented {
    slot = "idle-profile",
    -- A fresh list per profile change, so the segments rebuild and `format`'s "· live" moves with it.
    options = idle.active_profile:map(function()
        return { table.unpack(PROFILES) }
    end),
    value = shown_profile,
    format = function(profile)
        local label = profile == "battery" and "Battery" or "AC power"
        return idle.active_profile:get() == profile and label .. " · live" or label
    end,
    on_select = function(profile)
        picked:set(profile)
    end,
    width = theme.idle_picker_width,
    visible = has_battery,
}

-- One bar per stage, "Off" first: the bar is both the switch and the timeout. The stage's options
-- plus whatever either profile stores, so a value from an older list still lights a segment.
local function duration_bar(stage)
    local on_key, sec_key = stage.key .. "_on", stage.key .. "_sec"
    local options = settings:map(function(resolved)
        local seen, out = {}, {}
        local function add(sec)
            if not seen[sec] then
                seen[sec] = true
                out[#out + 1] = sec
            end
        end
        add(0)
        for _, sec in ipairs(stage.options) do
            add(sec)
        end
        for _, profile in ipairs(PROFILES) do
            add(resolved[profile][sec_key])
        end
        table.sort(out)
        return out
    end)
    return segmented {
        slot = "idle-" .. stage.key,
        options = options,
        value = computed({ settings, shown_profile }, function(resolved, profile)
            local held = resolved[profile]
            return held[on_key] and held[sec_key] or 0
        end),
        format = idle.format,
        on_select = function(sec)
            local profile = shown_profile:get()
            local held = idle.read(store.idle:get())[profile]
            idle.write(nil, profile, util.with(util.with(held, on_key, sec > 0), sec_key,
                sec > 0 and sec or held[sec_key]))
        end,
        width = theme.idle_bar_width,
    }
end

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
    -- Accent while either profile enables this stage; dim in both means the stage never runs.
    local any = settings:map(function(resolved)
        for _, profile in ipairs(PROFILES) do
            if resolved[profile][item.key .. "_on"] and resolved[profile][item.key .. "_sec"] > 0 then
                return true
            end
        end
        return false
    end)
    return panel_row {
        title = util.bold_when(any, stage.title),
        -- The stage's own description, not "after <the row above>": that row may be off in one
        -- profile.
        subtitle = stage.detail,
        title_size = theme.font.md,
        subtitle_size = theme.font.sm,
        height = theme.idle_row_height,
        leading = row {
            align_v = "Center",
            spacing = theme.spacing.xs,
            children = { reorder(item), glyph(stage.icon, ink(any), theme.icon.md, { align_v = "Center" }) },
        },
        trailing = duration_bar(stage),
    }
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
        title_size = theme.font.md,
        subtitle_size = theme.font.sm,
        height = theme.idle_row_height,
        icon_color = ink(capture_hold),
        trailing = toggle(settings, function(resolved)
            return resolved.privacy_auto_inhibit
        end, function(on)
            idle.write(nil, "privacy_auto_inhibit", on)
        end, "idle-capture-hold"),
    },
    panel_row {
        icon = icons.awake,
        title = util.bold_when(idle.manual, "Keep awake now"),
        subtitle = "Same as clicking the idle button in the bar",
        title_size = theme.font.md,
        subtitle_size = theme.font.sm,
        height = theme.idle_row_height,
        icon_color = ink(idle.manual),
        trailing = toggle(idle.manual, function(manual)
            return manual
        end, idle.set_manual, "idle-manual"),
    },
}

-- The master switch and its timeline share a card: a composite control, like an audio slider's.
local flow_card = panel_card(util.concat({ panel_row {
    icon = icons.play,
    icon_color = ink(running),
    title = "Automatic actions",
    subtitle = idle.active_profile:map(function(profile)
        return profile == "battery" and "On battery" or "On AC power"
    end),
    title_size = theme.font.md,
    subtitle_size = theme.font.sm,
    trailing = toggle(settings, function(resolved)
        return resolved.enabled
    end, function(on)
        idle.write(nil, "enabled", on)
    end, "idle-enabled"),
} }, timeline_section(settings)), {
    width = "Fill",
    spacing = theme.spacing.sm,
    tone = running:map(function(on)
        return on and "active" or "standard"
    end),
})

return modal({
    kind = "idle_settings",
    card = panel_card(util.concat({
        header,
        flow_card,
        -- The label and the picker share a line; the picker names which profile the bars edit.
        row {
            width = "Fill",
            align_v = "Center",
            children = { section_header("automation"), rect { width = "Fill" }, profile_picker },
        },
        stage_list,
        section_header("behaviour"),
    }, behaviour_rows), {
        width = theme.idle_modal_width,
        align_h = "Center",
        align_v = "Center",
        spacing = theme.spacing.md,
        padding = theme.spacing.lg,
        tone = "dialog",
    }),
})
