local theme = require("config.theme")
local icons = require("config.icons")
local toggle = require("components.toggle")
local panel_card = require("components.panel_card")
local panel_header = require("components.panel_header")
local panel_row = require("components.panel_row")
local section_header = require("components.section_header")
local ui_state = require("lib.ui_state")
local modal = require("components.modal")
local segmented = require("components.segmented")
local idle = require("lib.idle")
local store = require("lib.store")
local timeline_section = require("modules.global.idle_settings.timeline")
local util = require("lib.util")

local settings = idle.settings
local running = computed({ settings, idle.inhibited }, function(resolved, held)
    return resolved.enabled and not held
end)

-- Offer the battery profile only when UPower reports a battery.
local has_battery = mantle.battery:map(function(battery)
    return battery ~= nil and battery.present
end)

local header = panel_header {
    title = "Idle & power",
    subtitle = computed(
        { settings, idle.schedule, idle.elapsed, idle.reasons, idle.stale, idle.inhibited },
        function(resolved, plan, elapsed, reasons, stale, held)
            if held or stale then
                return idle.held_text(reasons, held, stale)
            end
            if not resolved.enabled then
                return "Automatic actions are paused"
            end
            if plan.total == 0 then
                return "No actions enabled on this profile"
            end
            return elapsed > 0 and "Idle " .. idle.clock(elapsed) or "Waiting for inactivity"
        end
    ),
    -- The bar circle's glyph, so opener and modal read as one control.
    icon = util.choose(idle.manual, icons.awake, icons.idle),
    -- A modal's masthead: one step up from a bar panel's.
    title_size = theme.font.xl,
    subtitle_size = theme.font.sm,
    active = running,
    on_close = function()
        ui_state.close_modal("idle_settings")
    end,
}

-- Which profile the bars edit: the live one unless the picker chose another since the modal
-- opened. A desktop has no battery, so no picker, and the bars are AC.
local PROFILES = { "ac", "battery" }
local picked = state("idle_profile_picked", "")
local dragging = state("idle_stage_drag", {})
local stage_bounds = geometry("idle-settings-stages")
ui_state.on_modal_close("idle_settings", function()
    picked:set("")
    dragging:set({})
end)
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
    font_size = theme.font.sm,
    tone = "subtle",
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
    local bar = segmented {
        slot = "idle-" .. stage.key,
        options = options,
        value = computed({ settings, shown_profile }, function(resolved, profile)
            local held = resolved[profile]
            return held[on_key] and held[sec_key] or 0
        end),
        format = idle.format,
        on_select = function(sec)
            -- Off keeps the stored seconds.
            local profile = shown_profile:get()
            local held = idle.read(store.idle:get())[profile]
            held[on_key] = sec > 0
            if sec > 0 then held[sec_key] = sec end
            idle.write({ [profile] = held })
        end,
        width = theme.idle_bar_width,
        font_size = theme.font.sm,
        tone = "subtle",
    }
    -- Duration clicks stay separate from the row's drag gesture.
    bar.on_drag = function() end
    return bar
end

local function stage_row(item)
    local stage = assert(idle.stage(item.key))
    local enabled = computed({ settings, shown_profile }, function(resolved, profile)
        local held = resolved[profile]
        return held[item.key .. "_on"] and held[item.key .. "_sec"] > 0
    end)
    local node = panel_row {
        title = util.bold_when(enabled, stage.title),
        -- The stage's own description, not "after <the row above>": that row may be off in one
        -- profile.
        subtitle = stage.detail,
        title_size = theme.font.md,
        subtitle_size = theme.font.sm,
        height = theme.idle_row_height,
        icon = stage.icon,
        icon_color = util.choose(enabled, theme.ACCENT, theme.DIM),
        trailing = duration_bar(stage),
    }
    node.cursor = dragging:map(function(drag) return drag.key == item.key and "grabbing" or "grab" end)
    node.z = dragging:map(function(drag) return drag.key == item.key and 1 or 0 end)
    node.background = dragging:map(function(drag) return drag.key == item.key and theme.ACCENT_SUBTLE or nil end)
    node.translate = dragging:map(function(drag)
        if not drag.key then return { y = 0 } end
        local y = 0
        if drag.key == item.key then
            y = drag.offset
        elseif item.index > drag.index and item.index <= drag.target then
            y = -theme.idle_row_height
        elseif item.index < drag.index and item.index >= drag.target then
            y = theme.idle_row_height
        end
        return { y = y }
    end)
    node.on_drag = function(rect, pointer, phase)
        if phase == "start" then
            dragging:set({ key = item.key, index = item.index, target = item.index, offset = 0, grab_y = pointer.y })
            return
        end
        local drag = dragging:get()
        if drag.key ~= item.key then return end
        local bounds = stage_bounds:get()
        local count = #settings:get().order
        local offset = rect.y + pointer.y - drag.grab_y - bounds.y - (drag.index - 1) * theme.idle_row_height
        offset = math.max((1 - drag.index) * theme.idle_row_height,
            math.min((count - drag.index) * theme.idle_row_height, offset))
        local target = drag.index + math.floor(offset / theme.idle_row_height + 0.5)
        if phase == "end" then
            dragging:set({})
            local y = rect.y + pointer.y
            if ui_state.active_modal:get() == "idle_settings" and pointer.x >= 0 and pointer.x < rect.width
                and y >= bounds.y and y < bounds.y + bounds.height then
                idle.move(item.key, target - drag.index)
            end
        else
            dragging:set({ key = drag.key, index = drag.index, target = target, offset = offset, grab_y = drag.grab_y })
        end
    end
    return node
end

-- One row per stage in stored `order`, as a `list` because declared children cannot be reordered.
-- Descriptors rebuild only when stored settings change: a reorder rebuilds rows, a tick none.
local stage_list = list {
    width = "Fill",
    geometry = stage_bounds,
    source = settings:map(function(resolved)
        local items = {}
        for index, key in ipairs(resolved.order) do
            -- `idle.read` resolved `order` to known stages only.
            items[index] = { key = key, index = index }
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
        icon = icons.camera,
        title = util.bold_when(capture_hold, "Keep awake while capturing"),
        -- Not video: a player asks for that itself and the engine honours it either way.
        subtitle = "Camera, microphone, screen capture",
        title_size = theme.font.md,
        subtitle_size = theme.font.sm,
        height = theme.idle_row_height,
        icon_color = util.choose(capture_hold, theme.ACCENT, theme.DIM),
        trailing = toggle(settings, function(resolved)
            return resolved.privacy_auto_inhibit
        end, function(on)
            idle.write({ privacy_auto_inhibit = on })
        end, "idle-capture-hold"),
    },
    panel_row {
        icon = icons.awake,
        title = util.bold_when(idle.manual, "Keep awake now"),
        subtitle = "Same as clicking the idle button in the bar",
        title_size = theme.font.md,
        subtitle_size = theme.font.sm,
        height = theme.idle_row_height,
        icon_color = util.choose(idle.manual, theme.ACCENT, theme.DIM),
        trailing = toggle(idle.manual, function(manual)
            return manual
        end, idle.set_manual, "idle-manual"),
    },
}

local automatic = panel_row {
    icon = icons.power,
    icon_color = util.choose(running, theme.ACCENT, theme.DIM),
    title = "Automatic actions",
    subtitle = idle.active_profile:map(function(profile)
        return profile == "battery" and "On battery" or "On AC power"
    end),
    title_size = theme.font.md,
    subtitle_size = theme.font.sm,
    trailing = toggle(settings, function(resolved)
        return resolved.enabled
    end, function(on)
        idle.write({ enabled = on })
    end, "idle-enabled"),
}

local body_scroll = scroll("idle_settings_body")
local body = panel_card(util.concat({
    automatic,
    timeline_section(settings),
    row {
        width = "Fill",
        align_v = "Center",
        children = { section_header("automation"), rect { width = "Fill" }, profile_picker },
    },
    stage_list,
    section_header("behaviour"),
}, behaviour_rows), {
    width = "Fill",
    background = theme.CLEAR,
    outlined = true,
    border_color = theme.BORDER_SUBTLE,
    spacing = theme.spacing.sm,
})
body.max_height = theme.idle_body_height
body.scroll = body_scroll

return modal({
    kind = "idle_settings",
    reset_on_close = { body_scroll },
    card = panel_card({ header, body }, {
        width = theme.idle_modal_width,
        tone = "dialog",
    }),
})
