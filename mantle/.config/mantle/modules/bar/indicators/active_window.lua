-- The focused window's icon and title in the centre zone. `workspaces` carries no window list, but
-- `active_client` is in every snapshot.
local theme = require("config.theme")
local util = require("lib.util")
local cell = require("components.cell")

-- This node is anchored unconditionally; hiding it moves the midpoint when the last window closed.
local EMPTY_LABEL = "Desktop"

-- The client is `nil` before the first snapshot and whenever nothing holds focus; the supervisor
-- omits the key rather than sending null (`workspaces/controller.rs`). `active_client.class` is the
-- toplevel `app_id`, which `util.app_entry` maps to a `.desktop` entry.
local function focused(applications, workspaces)
    local client = workspaces and workspaces.active_client
    return client, client and util.app_entry(applications, client.class)
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
    return (entry and entry.name) or client.class or EMPTY_LABEL
end

local focused_icon = icon {
    name = computed({ mantle.applications, mantle.workspaces }, function(applications, workspaces)
        local _, entry = focused(applications, workspaces)
        return (entry and entry.icon) or "applications-system"
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
