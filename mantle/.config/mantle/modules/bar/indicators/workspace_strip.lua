-- One circle per workspace, collapsing to the active one and re-narrowing `theme.animation_ms + 200`
-- after the pointer leaves (`components/expanding_pill.lua`). Ground: accent when active, glass when
-- populated, `DISABLED` at half opacity when empty. A circle draws the standing window's icon when
-- `applications` knows its `app_id`, else `idx` -- never `name`, which elides to three dots while
-- the number is the keybind's target.
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

local function output_of(w)
    return w and (w.outputs or {})[1]
end

-- Pad up to `PADDED_SLOTS` or the highest number in use. On a compositor where `id` is the number,
-- focusing a missing one creates it, so a padded entry carries the same `id` a real one would.
local function workspaces_of(w)
    local out = output_of(w)
    local listed = out and (out.workspaces or {}) or {}
    if not (w and w.compositor == "hyprland") then
        return listed
    end
    local by_idx, highest = {}, PADDED_SLOTS
    for _, ws in ipairs(listed) do
        by_idx[ws.idx] = ws
        highest = math.max(highest, ws.idx)
    end
    local padded = {}
    for n = 1, highest do
        padded[n] = by_idx[n] or { id = n, idx = n, populated = false }
    end
    return padded
end

local pill = expanding_pill.new({ slot = "workspace-pill", collapse_ms = theme.animation_ms + 200 })

local function workspace_button(ws)
    local id = ws.id
    -- Read the current snapshot, not the build-time `ws`. Key reconciliation keeps the button while
    -- its windows change.
    local entry = mantle.workspaces:map(function(w)
        for _, candidate in ipairs(workspaces_of(w)) do
            if candidate.id == id then
                return candidate
            end
        end
        return ws
    end)
    local is_active = mantle.workspaces:map(function(w)
        local out = output_of(w)
        return out ~= nil and out.active_workspace == id
    end)
    local slot_hovered = hover("workspace-" .. tostring(id))
    local ground = computed({ is_active, slot_hovered, entry }, function(active, is_hovered, current)
        if active then
            return theme.ACCENT
        elseif is_hovered then
            return theme.GLASS_CONTROL_HOVER
        end
        return current.populated and theme.GLASS_CONTROL or theme.DISABLED
    end)
    local icon_name = computed({ mantle.applications, entry }, function(applications, current)
        local app = util.app_entry(applications, current.app_id)
        return (app and app.icon) or ""
    end)
    -- `ground` already folds the pointer in, so it is both states; the ring and the contrast ink
    -- come from `icon_button`'s defaults.
    return pill.cell(icon_button(tostring(ws.idx), function()
        if not is_active:get() then
            mantle.workspaces:invoke("focus", id)
        end
    end, {
        slot = "workspace-" .. tostring(id),
        art = icon_name,
        art_size = theme.icon.md,
        icon_size = theme.font.sm,
        radius = theme.item_radius,
        background = ground,
        background_hover = ground,
        opacity = entry:map(function(current)
            return current.populated and 1 or theme.opacity.disabled
        end),
    }), is_active)
end

-- No ground of its own; the circles sit directly on the bar.
return pill.row({
    list {
        direction = "Horizontal",
        align_v = "Center",
        source = mantle.workspaces:map(workspaces_of),
        itemfn = workspace_button,
        key = function(ws)
            return tostring(ws.id)
        end,
    },
})
