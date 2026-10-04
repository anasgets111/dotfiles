-- One circle per workspace, collapsing to the active one and re-narrowing `theme.animation_ms + 200`
-- after the pointer leaves (`components/expanding_pill.lua`). Ground: accent when active, glass when
-- populated, an empty ring when empty. A circle draws the standing window's icon when
-- `applications` knows its `app_id`, else `idx`. Never `name`, which elides to three dots, while the
-- number is the keybind's target.
--
-- It collapses to the first output's `active_workspace`, not the focused one: every output has an
-- active workspace but only one has focus, so another monitor would collapse to nothing.
--
-- Hyprland lists no empty workspaces and creates a numbered one on focus, so this pads to ten dimmed
-- slots; Niri keeps a trailing empty workspace and needs none.
local theme = require("config.theme")
local util = require("lib.util")
local icon_button = require("components.icon_button")
local expanding_pill = require("components.expanding_pill")

local PADDED_SLOTS = 10

local function output_of(workspaces)
    return workspaces and (workspaces.outputs or {})[1]
end

-- Pad up to `PADDED_SLOTS` or the highest number in use. On a compositor where `id` is the number,
-- focusing a missing one creates it, so a padded entry carries the same `id` a real one would.
local function workspaces_of(workspaces)
    local out = output_of(workspaces)
    local listed = out and (out.workspaces or {}) or {}
    if not (workspaces and workspaces.compositor == "hyprland") then
        return listed
    end
    local by_idx, highest = {}, PADDED_SLOTS
    for _, workspace in ipairs(listed) do
        by_idx[workspace.idx] = workspace
        highest = math.max(highest, workspace.idx)
    end
    local padded = {}
    for number = 1, highest do
        padded[number] = by_idx[number] or { id = number, idx = number, populated = false }
    end
    return padded
end

local dragging_from = state("workspace_drag_from", nil)
local drag_target = state("workspace_drag_target", nil)
local drag_pos = state("workspace_drag_pos", { x = -200, y = -200 })
local drag_icon = state("workspace_drag_icon", "")
local drag_glyph = state("workspace_drag_glyph", "")
local is_dragging = dragging_from:map(function(from)
    return from ~= nil
end)

local hold_timer = nil
local hold_ready = false
local drag_armed = false
local start_cx, start_cy = 0, 0

local function cancel_hold()
    if hold_timer then
        hold_timer:cancel()
        hold_timer = nil
    end
end

local function arm_drag(ws, cx, cy)
    if drag_armed then return end
    drag_armed = true
    dragging_from:set(ws.id)
    drag_target:set(ws.id)
    drag_pos:set({ x = cx - theme.item_width / 2, y = cy - theme.item_height / 2 })
    local app = util.app_entry(mantle.applications:get(), ws.app_id)
    drag_icon:set((app and app.icon) or "")
    drag_glyph:set(tostring(ws.idx))
end

local function reset_drag()
    dragging_from:set(nil)
    drag_target:set(nil)
    drag_icon:set("")
    drag_glyph:set("")
    drag_pos:set({ x = -200, y = -200 })
    drag_armed = false
end

local listed = mantle.workspaces:map(workspaces_of)
local pill = expanding_pill.new({
    slot = "workspace-pill",
    hold_open = is_dragging,
    collapse_ms = theme.animation_ms + 200,
    count = listed:map(function(entries)
        return #entries
    end),
})

local function workspace_button(workspace)
    local id = workspace.id
    local is_active = mantle.workspaces:map(function(workspaces)
        local out = output_of(workspaces)
        return out ~= nil and out.active_workspace == id
    end)
    local is_drop_target = computed({ dragging_from, drag_target }, function(from, target)
        return target == id and from ~= nil and from ~= id
    end)
    local slot_hovered = hover("workspace-" .. tostring(id))
    local ground = computed({ is_active, slot_hovered, is_drop_target }, function(active, is_hovered, drop)
        if active then
            return drop and theme.ACCENT_HOVER or theme.ACCENT
        elseif drop or is_hovered then
            return theme.GLASS_CONTROL_HOVER
        end
        return workspace.populated and theme.GLASS_CONTROL or theme.CLEAR
    end)
    local border_color = computed({ is_drop_target, slot_hovered }, function(drop, is_hovered)
        return drop and theme.ACCENT or (is_hovered and theme.GLASS_BORDER_HOVER or theme.GLASS_BORDER)
    end)
    local opacity = dragging_from:map(function(from)
        if from == id then return 0.4 end
        return workspace.populated and 1 or theme.opacity.muted
    end)
    local cursor = workspace.populated and util.choose(is_dragging, "grabbing", "pointer") or nil
    local function focus_workspace()
        if not is_active:get() then
            mantle.workspaces:focus(id)
        end
    end

    local on_drag = nil
    if workspace.populated and workspace.window_id ~= nil then
        on_drag = function(rect, pointer, phase)
            local cx, cy = rect.x + pointer.x, rect.y + pointer.y

            if phase == "start" then
                drag_armed = false
                hold_ready = false
                start_cx, start_cy = cx, cy
                cancel_hold()
                hold_timer = timer(200, function()
                    hold_timer = nil
                    hold_ready = true
                end)
            elseif phase == "move" then
                if hold_ready and not drag_armed and (math.abs(cx - start_cx) > 10 or math.abs(cy - start_cy) > 10) then
                    arm_drag(workspace, cx, cy)
                end
                if drag_armed then
                    drag_pos:set({ x = cx - theme.item_width / 2, y = cy - theme.item_height / 2 })
                    local best_id, best_dist = nil, math.huge
                    for _, ws in ipairs(listed:get() or {}) do
                        local geom = geometry("workspace-btn-" .. tostring(ws.id)):get()
                        if geom and geom.width and geom.width > 0 then
                            local center_x = geom.x + geom.width / 2
                            local center_y = geom.y + geom.height / 2
                            local dist = math.abs(cx - center_x)
                            if math.abs(cy - center_y) < 40 and dist < best_dist then
                                best_dist, best_id = dist, ws.id
                            end
                        end
                    end
                    drag_target:set(best_dist < 40 and best_id or nil)
                end
            elseif phase == "end" then
                local released_on_source = cx >= rect.x and cx < rect.x + rect.width
                    and cy >= rect.y and cy < rect.y + rect.height
                cancel_hold()
                hold_ready = false
                if not drag_armed then
                    if released_on_source then focus_workspace() end
                else
                    local from, target = dragging_from:get(), drag_target:get()
                    reset_drag()
                    if from and target and from ~= target then
                        mantle.windows:move_to_workspace(workspace.window_id, target)
                    elseif from and (released_on_source or target == from) then
                        focus_workspace()
                    end
                end
            end
        end
    end

    -- `ground` already folds the pointer in, so it is both states; the ring and the contrast ink
    -- come from `icon_button`'s defaults.
    -- Populated cells focus on drag end; adding on_click would send the same focus twice.
    local on_activate
    if not on_drag then on_activate = focus_workspace end
    return pill.cell(icon_button(tostring(workspace.idx), on_activate, {
        geometry = geometry("workspace-btn-" .. tostring(id)),
        cursor = cursor,
        on_drag = on_drag,
        slot = "workspace-" .. tostring(id),
        art = util.app_icon(workspace),
        icon_size = theme.font.sm,
        radius = theme.item_radius,
        background = ground,
        background_hover = ground,
        border_color = border_color,
        opacity = opacity,
    }), is_active)
end

-- No ground of its own; the circles sit directly on the bar.
local strip = pill.row({
    list {
        direction = "horizontal",
        align_v = "center",
        spacing = pill.spacing,
        animate = pill.animate,
        source = listed,
        itemfn = workspace_button,
        key = function(workspace)
            return tostring(workspace.id)
        end,
    },
})

local drag_ghost = rect {
    width = theme.item_width,
    height = theme.item_height,
    visible = is_dragging,
    cursor = "grabbing",
    translate = drag_pos,
    children = computed({ drag_icon, drag_glyph }, function(name, glyph)
        local child = (name and name ~= "") and icon {
            name = name,
            size = theme.icon.lg,
            align_h = "center",
            align_v = "center",
            shadows = { { color = theme.workspace_drag_shadow, blur = theme.workspace_drag_icon_blur, offset = { x = 0, y = theme.workspace_drag_shadow_y } } },
        } or text {
            content = glyph or "",
            font_size = theme.font.md,
            foreground = theme.FG,
            align_h = "center",
            align_v = "center",
            shadows = { { color = theme.workspace_drag_shadow, blur = theme.workspace_drag_text_blur, offset = { x = 0, y = theme.workspace_drag_shadow_y } } },
        }
        return { child }
    end),
}

return { pill = pill, indicator = strip, drag_ghost = drag_ghost }
