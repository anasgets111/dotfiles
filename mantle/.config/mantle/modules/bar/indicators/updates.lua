local theme = require("config.theme")
local icons = require("config.icons")
local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")
local ui_state = require("lib.ui_state")
local update_panel = require("modules.bar.panels.update_panel")
local service = require("lib.updates")

local SLOT = "updates"

-- Glyph, colour and tooltip follow the run through developer tooling and its unread result.
-- `pending`'s text carries the count, so it is built below.
local LOOKS = {
    running = { icons.updating, theme.ACCENT, "Updating system and developer tooling…" },
    failed = { icons.update_err, theme.RED, "Update failed · Click for details" },
    check_failed = { icons.update_err, theme.RED, "Update check failed · Click for details" },
    checking = { icons.checking, theme.ACCENT, "Checking for updates…" },
    pending = { icons.updates, theme.ACCENT },
    idle = { icons.up_to_date, theme.DIM, "Up to date · Click to check, right-click to open" },
}

local status = service.phase:map(function(phase)
    return LOOKS[phase] and phase or "idle"
end)

local indicator = icon_button(status:map(function(current)
    return LOOKS[current][1]
end), nil, {
    -- Right-click always opens the panel: at idle it is otherwise unreachable, and with it the
    -- reboot badge, the last check time, and the empty state.
    on_buttons = {
        right = function(rect) ui_state.toggle_panel(update_panel.kind, rect) end,
        left = function(rect)
            if status:get() == "idle" then
                -- The Supervisor refuses a second check while one is running.
                mantle.updates:check()
            else
                ui_state.toggle_panel(update_panel.kind, rect)
            end
        end,
    },
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
    slot = SLOT,
    text = computed({ mantle.updates, status }, function(updates, current)
        if updates == nil then
            return "--"
        elseif current == "pending" then
            return #updates.packages == 1 and "One package can be upgraded"
                or string.format("%d packages can be upgraded", #updates.packages)
        end
        return LOOKS[current][3]
    end),
})

return { indicator = indicator, tooltips = { update_tooltip } }
