local icon_button = require("components.icon_button")
local tooltip = require("components.tooltip")
local util = require("lib.util")
local ui_state = require("lib.ui_state")
local service = require("lib.updates")

-- Left click checks when there is nothing to see, and opens the panel otherwise.
local quiet = computed({ service.phase, service.look }, function(phase, look)
    return phase == "idle" and look.tone == "dim"
end, false)

local indicator = icon_button(service.look:map(function(look) return look.icon end), nil, {
    -- Right click always opens the panel: at idle it is otherwise unreachable, and with it the settings.
    on_buttons = {
        right = function(rect) ui_state.toggle_panel(service.KIND, rect) end,
        left = function(rect)
            if quiet:get() then
                mantle.updates:check()
            else
                ui_state.toggle_panel(service.KIND, rect)
            end
        end,
    },
    slot = service.KIND,
    selected = ui_state.panel_showing(service.KIND),
    -- No supported package manager leaves `package_manager` nil; an indicator that can only report
    -- its own failure is worse than none.
    visible = mantle.updates:map(function(updates) return updates.package_manager ~= nil end, false),
    foreground = service.look:map(function(look) return look.color end),
})

local update_tooltip = tooltip({
    slot = service.KIND,
    text = service.look:map(function(look) return look.title end),
    detail = computed({ service.look, quiet }, function(look, is_quiet)
        local lines = util.filter({ look.detail, look.warning, table.unpack(look.extras) }, function(line)
            return line ~= ""
        end)
        lines[#lines + 1] = is_quiet and "Click to check · right-click for details" or "Click for details"
        return table.concat(lines, "\n")
    end, ""),
})

return { indicator = indicator, tooltips = { update_tooltip } }
