-- The focused window's icon and title in the centre zone. `workspaces` carries no window list, but
-- `active_client` is in every snapshot.
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")

-- `nil` before the first snapshot and whenever nothing holds focus; the supervisor omits the key
-- rather than sending null (`workspaces/controller.rs`).
local function focused(workspaces)
    return workspaces and workspaces.active_client
end

-- This node is anchored unconditionally; hiding it moves the midpoint when the last window closed.
local EMPTY_LABEL = "Desktop"

-- Fallback icon name when nothing is focused.
local EMPTY_ICON = "applications-system"

-- Title, then the desktop entry's name, then the raw `app_id`: a splash or a freshly mapped terminal
-- sets no title and would otherwise caption as nothing while holding focus.
local function label(applications, workspaces)
    local client = focused(workspaces)
    if client == nil then
        return EMPTY_LABEL
    end
    local title = client.title
    if title ~= nil and title ~= "" then
        return title
    end
    local entry = util.app_entry(applications, client.class)
    return (entry and entry.name) or client.class or EMPTY_LABEL
end

-- `active_client.class` is the toplevel `app_id`, which `util.app_entry` maps to a `.desktop` entry.
local focused_icon = icon {
    name = computed({ mantle.applications, mantle.workspaces }, function(applications, workspaces)
        local client = focused(workspaces)
        if client == nil then
            return EMPTY_ICON
        end
        local entry = util.app_entry(applications, client.class)
        return (entry and entry.icon) or EMPTY_ICON
    end),
    -- The centre caption is the bar's one piece of prose, so its icon reads as an app.
    size = theme.control.sm,
    align_v = "Center",
}

return row {
    height = theme.item_height,
    align_v = "Center",
    spacing = theme.spacing.xs,
    children = {
        focused_icon,
        cell(util.bold(computed({ mantle.applications, mantle.workspaces }, function(applications, workspaces)
            return util.truncate(label(applications, workspaces), theme.title_limit)
        end)), theme.FG, theme.font.sm, { align_v = "Center" }),
    },
}
