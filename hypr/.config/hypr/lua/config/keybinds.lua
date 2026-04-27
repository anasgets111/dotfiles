local helpers = require("config.helpers")

local M = {}

local function bind_workspace_keys(main_mod)
  local number_keys = {
    { key = "1", workspace = 1 },
    { key = "2", workspace = 2 },
    { key = "3", workspace = 3 },
    { key = "4", workspace = 4 },
    { key = "5", workspace = 5 },
    { key = "6", workspace = 6 },
    { key = "7", workspace = 7 },
    { key = "8", workspace = 8 },
    { key = "9", workspace = 9 },
    { key = "0", workspace = 10 },
  }

  local numpad_keys = {
    { key = "KP_End", workspace = 1 },
    { key = "KP_Down", workspace = 2 },
    { key = "KP_Next", workspace = 3 },
    { key = "KP_Left", workspace = 4 },
    { key = "KP_Begin", workspace = 5 },
    { key = "KP_Right", workspace = 6 },
    { key = "KP_Home", workspace = 7 },
    { key = "KP_Up", workspace = 8 },
    { key = "KP_Prior", workspace = 9 },
    { key = "KP_Insert", workspace = 10 },
  }

  for _, item in ipairs(number_keys) do
    helpers.focus_workspace_bind(main_mod .. " + " .. item.key, item.workspace)
    helpers.move_workspace_bind(main_mod .. " + SHIFT + " .. item.key, item.workspace)
  end

  for _, item in ipairs(numpad_keys) do
    helpers.focus_workspace_bind(main_mod .. " + " .. item.key, item.workspace)
    helpers.move_workspace_bind(main_mod .. " + SHIFT + " .. item.key, item.workspace)
  end
end

function M.apply(ctx)
  local main_mod = ctx.mainMod

  bind_workspace_keys(main_mod)

  helpers.focus_workspace_bind(main_mod .. " + tab", "e+1")
  helpers.focus_workspace_bind(main_mod .. " + SHIFT + TAB", "e-1")
  helpers.focus_workspace_bind(main_mod .. " + mouse_down", "e+1")
  helpers.focus_workspace_bind(main_mod .. " + mouse_up", "e-1")

  helpers.bind(main_mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }), { description = "Move active window to the left" })
  helpers.bind(main_mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }), { description = "Move active window to the right" })
  helpers.bind(main_mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }), { description = "Move active window upwards" })
  helpers.bind(main_mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }), { description = "Move active window downwards" })

  helpers.bind(main_mod .. " + left", hl.dsp.focus({ direction = "left" }), { description = "Move focus to the left" })
  helpers.bind(main_mod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Move focus to the right" })
  helpers.bind(main_mod .. " + up", hl.dsp.focus({ direction = "up" }), { description = "Move focus upwards" })
  helpers.bind(main_mod .. " + down", hl.dsp.focus({ direction = "down" }), { description = "Move focus downwards" })

  helpers.bind(main_mod .. " + Q", hl.dsp.window.close())
  helpers.bind(main_mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
  helpers.bind(main_mod .. " + F", hl.dsp.window.fullscreen())
  helpers.bind(main_mod .. " + P", hl.dsp.window.pseudo())
  helpers.bind(main_mod .. " + J", hl.dsp.layout("togglesplit"))

  helpers.bind(main_mod .. " + CTRL + SHIFT + right", hl.dsp.window.resize({ x = 15, y = 0, relative = true }), { description = "Resize to the right" })
  helpers.bind(main_mod .. " + CTRL + SHIFT + left", hl.dsp.window.resize({ x = -15, y = 0, relative = true }), { description = "Resize to the left" })
  helpers.bind(main_mod .. " + CTRL + SHIFT + up", hl.dsp.window.resize({ x = 0, y = -15, relative = true }), { description = "Resize upwards" })
  helpers.bind(main_mod .. " + CTRL + SHIFT + down", hl.dsp.window.resize({ x = 0, y = 15, relative = true }), { description = "Resize downwards" })

  helpers.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
  helpers.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

  helpers.bind(main_mod .. " + RETURN", hl.dsp.workspace.toggle_special("terminal"))
  helpers.bind(main_mod .. " + KP_Enter", hl.dsp.workspace.toggle_special("terminal"))
  helpers.move_workspace_bind(main_mod .. " + SHIFT + S", "special:terminal")

  helpers.bind(main_mod .. " + D", hl.dsp.workspace.toggle_special("vesktop"))
  helpers.bind(main_mod .. " + T", hl.dsp.workspace.toggle_special("telegram"))
  helpers.bind(main_mod .. " + S", hl.dsp.workspace.toggle_special("slack"))

  helpers.exec_bind(main_mod .. " + E", ctx.fileManager)
  helpers.bind(main_mod .. " + B", hl.dsp.exec_cmd({ cmd = ctx.browser, rules = { workspace = "2" } }))
  helpers.exec_bind("control + alt + delete", "missioncenter")

  helpers.exec_bind(main_mod .. " + SPACE", ctx.menu)
  helpers.exec_bind(main_mod .. " + C", "cursor")
  helpers.exec_bind(main_mod .. " + A", "antigravity.sh")
  helpers.exec_bind(main_mod .. " + Z", "WAYLAND_DISPLAY='' zeditor")
  helpers.bind(main_mod .. " + H", hl.dsp.exec_cmd({ cmd = "heroic", rules = { workspace = "6" } }))
  helpers.bind(main_mod .. " + G", hl.dsp.exec_cmd({ cmd = "steam", rules = { workspace = "6" } }))
  helpers.exec_bind(main_mod .. " + n", "say --clipboard")

  helpers.exec_bind(main_mod .. " + L", ctx.lockCmd)
  helpers.bind(main_mod .. " + SHIFT + L", hl.dsp.exit())

  helpers.exec_bind("switch:on:Lid Switch", ctx.lockCmd, { locked = true })
  helpers.exec_bind("XF86AudioRaiseVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+", { locked = true, repeating = true })
  helpers.exec_bind("XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", { locked = true, repeating = true })
  helpers.exec_bind("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", { locked = true, repeating = true })
  helpers.exec_bind("XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", { locked = true, repeating = true })
  helpers.exec_bind("XF86MonBrightnessUp", "brightnessctl -q set 5%+", { locked = true, repeating = true })
  helpers.exec_bind("XF86MonBrightnessDown", "brightnessctl -q set 5%-", { locked = true, repeating = true })

  helpers.exec_bind("XF86AudioNext", "playerctl next", { locked = true })
  helpers.exec_bind("XF86AudioPause", "playerctl play-pause", { locked = true })
  helpers.exec_bind("XF86AudioPlay", "playerctl play-pause", { locked = true })
  helpers.exec_bind("XF86AudioPrev", "playerctl previous", { locked = true })

  helpers.exec_bind(main_mod .. " + CTRL + S", "voxtype record toggle")
  helpers.exec_bind(main_mod .. " + M", "quickshell ipc call mic mute")
  helpers.exec_bind("XF86Calculator", "gnome-calculator", { locked = true })

  helpers.exec_bind("PRINT", "hdrshot region")
  helpers.exec_bind("CONTROL + PRINT", "hdrshot output")
  helpers.exec_bind("SHIFT + PRINT", "quickshell ipc call rec toggle")
end

return M
