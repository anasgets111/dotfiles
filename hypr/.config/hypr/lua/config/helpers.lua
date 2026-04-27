local M = {}

M.context = {
  mainMod = "SUPER",
  fileManager = "nautilus",
  browser = "zen-browser",
  menu = "quickshell ipc call launcher toggle",
  lockCmd = "quickshell ipc call lock lock",
}

function M.shell_output(command)
  local handle = io.popen(command)
  if handle == nil then
    return nil
  end

  local output = handle:read("*a")
  handle:close()

  return output and output:gsub("%s+$", "") or nil
end

function M.bind(keys, dispatcher, flags)
  return hl.bind(keys, dispatcher, flags)
end

function M.exec_bind(keys, command, flags)
  return M.bind(keys, hl.dsp.exec_cmd(command), flags)
end

function M.move_workspace_bind(keys, workspace, flags)
  return M.bind(keys, hl.dsp.window.move({ workspace = workspace }), flags)
end

function M.focus_workspace_bind(keys, workspace, flags)
  return M.bind(keys, hl.dsp.focus({ workspace = workspace }), flags)
end

return M
