local helpers = require("config.helpers")

local M = {}

local function apply_workspace_rules(main_monitor)
  hl.workspace_rule({ workspace = "1", monitor = main_monitor, default = true })
  hl.workspace_rule({ workspace = "2", monitor = main_monitor, layout = "scrolling" })

  for workspace = 3, 10 do
    hl.workspace_rule({ workspace = tostring(workspace), monitor = main_monitor })
  end
end

local function apply_desktop()
  local main_monitor = "DP-1"

  hl.monitor({
    output = main_monitor,
    mode = "3440x1440@165",
    position = "0x0",
    scale = 1,
    bitdepth = 10,
    vrr = 2,
  })

  apply_workspace_rules(main_monitor)

  hl.config({
    cursor = {
      default_monitor = main_monitor,
    },
  })
end

local function apply_laptop()
  local main_monitor = "eDP-1"

  hl.monitor({
    output = main_monitor,
    mode = "1920x1200@60",
    position = "0x0",
  })

  apply_workspace_rules(main_monitor)
end

function M.apply(ctx)
  local hostname = helpers.shell_output("uname -n") or ""
  ctx.hostname = hostname
  ctx.monitorProfile = hostname == "Wolverine" and "desktop" or "laptop"

  if ctx.monitorProfile == "desktop" then
    apply_desktop()
  else
    apply_laptop()
  end
end

return M
