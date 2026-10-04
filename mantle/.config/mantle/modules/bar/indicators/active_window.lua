-- The focused window's icon and title in the centre zone. `workspaces` carries no window list, but
-- `active_client` is in every snapshot.
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")

-- This node is anchored unconditionally; hiding it moves the midpoint when the last window closed.
local EMPTY_LABEL = "Desktop"

-- The client is `nil` before the first snapshot and whenever nothing holds focus; the supervisor
-- omits the key rather than sending null (`workspaces/controller.rs`). `util.app_entry` maps
-- `active_client.app_id` to a `.desktop` entry.
local function focused(applications, workspaces)
    local client = workspaces and workspaces.active_client
    return client, client and util.app_entry(applications, client.app_id)
end

-- Title, then the desktop entry's name, then the raw `app_id`: a splash or a freshly mapped terminal
-- sets no title and would otherwise caption as nothing while holding focus.
local function label(applications, workspaces)
    local client, entry = focused(applications, workspaces)
    if client == nil then
        return EMPTY_LABEL
    end
    if client.title ~= nil and client.title ~= "" then
        return client.title
    end
    return (entry and entry.name) or client.app_id or EMPTY_LABEL
end

local icon_name = computed({ mantle.applications, mantle.workspaces }, function(applications, workspaces)
    local _, entry = focused(applications, workspaces)
    return (entry and entry.icon) or "applications-system"
end)
local title = computed({ mantle.applications, mantle.workspaces }, function(applications, workspaces)
    return util.truncate(label(applications, workspaces), theme.title_limit)
end)
local app_id = mantle.workspaces:map(function(workspaces)
    local client = workspaces and workspaces.active_client
    return client and client.app_id or ""
end)

local content = geometry("active_window")
local function swap(from) return { duration = theme.animation_fast_ms, easing = "out_cubic", from = from } end

-- Keyed by app: a focus change swaps captions; a title change only resizes the box, which clips both.
return rect {
    width = content:map(function(rect) return rect.width end),
    height = theme.item_height,
    align_h = "center",
    align_v = "center",
    animate = { width = theme.spring_tracking },
    children = app_id:map(function(key)
        return { row {
            id = key,
            geometry = content,
            height = "fill",
            align_v = "center",
            spacing = theme.spacing.xs,
            opacity = 1,
            translate = { y = 0 },
            animate = {
                opacity = swap(0),
                translate = swap({ y = theme.spacing.sm }),
                exit = { duration = theme.animation_fast_ms, easing = "in_quad", opacity = 0, translate = { y = -theme.spacing.sm } },
            },
            children = {
                -- The centre caption is the bar's one piece of prose, so its icon reads as an app.
                icon { name = icon_name, size = theme.control.sm, align_v = "center" },
                cell(util.bold(title), theme.FG, theme.font.sm, { align_v = "center" }),
            },
        } }
    end),
}
