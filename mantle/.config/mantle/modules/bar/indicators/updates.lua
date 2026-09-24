local theme = require("config.theme")
local icons = require("config.icons")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")
local ui_state = require("lib.ui_state")
local update_panel = require("modules.bar.panels.update_panel")
local service = require("lib.updates")

local SLOT = "updates"

-- In order: installing, a failed run, a failed check, a running check, then a count. A failed
-- install owns the glyph until the result is read.
local function state_of(updates, is_dismissed)
    if updates == nil then
        return "idle"
    elseif updates.installing then
        return "installing"
    elseif not is_dismissed and service.install_failed(updates) then
        return "install_failed"
    elseif updates.check_error and updates.check_error ~= "" then
        return "error"
    elseif updates.checking then
        return "checking"
    elseif (updates.count or 0) > 0 then
        return "pending"
    end
    return "idle"
end

local status = computed({ mantle.updates, service.dismissed }, state_of)

-- Glyph, colour and tooltip per state; the glyph and colour leave five states sharing two grounds,
-- so the tooltip names which. `pending`'s text carries the count, so it is built below.
local LOOKS = {
    installing = { icons.updating, theme.ACCENT, "Updating system and developer tooling…" },
    install_failed = { icons.update_err, theme.RED, "Update failed · Click for details" },
    error = { icons.update_err, theme.RED, "Update check failed · Click for details" },
    checking = { icons.checking, theme.ACCENT, "Checking for updates…" },
    pending = { icons.updates, theme.ACCENT },
    idle = { icons.up_to_date, theme.DIM, "Up to date · Click to check, right-click to open" },
}

local indicator = icon_button(status:map(function(current)
    return LOOKS[current][1]
end), nil, {
    -- Right-click always opens the panel: at idle it is otherwise unreachable, and with it the
    -- reboot badge, the last check time, and the empty state.
    on_button = function(rect, mouse_button)
        if mouse_button ~= "left" and mouse_button ~= "right" then
            return
        end
        if mouse_button == "right" or status:get() ~= "idle" then
            ui_state.toggle_panel(update_panel.kind, rect)
            return
        end
        -- The Supervisor refuses `check` while one is running, so no guard is needed.
        mantle.updates:invoke("check")
    end,
    slot = SLOT,
    selected = ui_state.panel_showing(update_panel.kind),
    -- No supported package manager leaves `package_manager` nil; an indicator that can only report
    -- its own failure is worse than none.
    visible = mantle.updates:map(function(updates)
        return updates ~= nil and updates.package_manager ~= nil
    end),
    foreground = status:map(function(current)
        return LOOKS[current][2]
    end),
})

local update_tooltip = tooltip({
    id = "updates_tooltip",
    slot = SLOT,
    text = computed({ mantle.updates, status }, function(updates, current)
        if updates == nil then
            return "--"
        elseif current == "pending" then
            return updates.count == 1 and "One package can be upgraded"
                or string.format("%d packages can be upgraded", updates.count)
        end
        return LOOKS[current][3]
    end),
})

return { indicator = indicator, tooltip = update_tooltip }
