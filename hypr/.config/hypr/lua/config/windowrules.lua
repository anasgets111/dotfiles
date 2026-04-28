local M = {}

local sizes = {
  xlarge = "(monitor_w*0.85) (monitor_h*0.85)",
  large = "(monitor_w*0.60) (monitor_h*0.60)",
  medium = "(monitor_w*0.45) (monitor_h*0.45)",
  small = "(monitor_w*0.30) (monitor_h*0.30)",
  tiny = "(monitor_w*0.15) (monitor_h*0.15)",
}

local patterns = {
  tiny_class = "(?i)^(gnome-calculator|org\\.gnome\\.calculator)$",
  small_class = "^org\\.kde\\.kdeconnect\\.handler$",
  large_class = "^(com\\.saivert\\.pwvucontrol|org\\.pulseaudio\\.pavucontrol|pavucontrol|gtk-pipe-viewer|blueman-manager|nm-connection-editor|org\\.gnome\\.DiskUtility|xdg-desktop-portal.*|polkit.*|zenity|waypaper|io\\.missioncenter\\.MissionCenter|mpv|com\\.gabm\\.satty)$",
  small_title = "^(Do you want to retry your last request\\?|Authentication Required)$",
  medium_title = "^(Install from VSIX|Downloading Certificate|Open File|Save File|Save As|Open Folder|File Upload|Enter name of file to save to\\.\\.|About Zen Browser|Steam - Self Updater|Steam Settings|Select File containing CA certificate)$",
  large_title = "^(OpenRGB|Network Connections|imv|nemo|ncmpcpp|Create or select new Steam library folder)$",
  pip_title = "(?i)^picture.?in.?picture",
  blender_splash = "^Blender$",
}

function M.apply()
  hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })
  hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })
  hl.window_rule({ match = { float = false }, no_shadow = true })
  hl.window_rule({ match = { fullscreen = true }, no_blur = true, no_anim = true })
  hl.window_rule({ match = { class = "^steam_app_" }, fullscreen = true, immediate = true })

  hl.workspace_rule({ workspace = "1", on_created_empty = "zen-browser" })
  hl.workspace_rule({ workspace = "2", on_created_empty = "chromium" })
  hl.workspace_rule({ workspace = "3", on_created_empty = "zeditor" })
  hl.workspace_rule({ workspace = "special:vesktop", on_created_empty = "vesktop" })
  hl.workspace_rule({ workspace = "special:telegram", on_created_empty = "Telegram" })
  hl.workspace_rule({ workspace = "special:slack", on_created_empty = "slack" })
  hl.workspace_rule({ workspace = "special:terminal", on_created_empty = "xdg-terminal-exec" })

  hl.workspace_rule({ workspace = "w[tv1]s[false]", gaps_out = 0, gaps_in = 0 })
  hl.workspace_rule({ workspace = "f[1]s[false]", gaps_out = 0, gaps_in = 0 })
  hl.window_rule({ match = { float = false, workspace = "w[tv1]s[false]" }, border_size = 0 })
  hl.window_rule({ match = { float = false, workspace = "w[tv1]s[false]" }, rounding = 0 })
  hl.window_rule({ match = { float = false, workspace = "f[1]s[false]" }, border_size = 0 })
  hl.window_rule({ match = { float = false, workspace = "f[1]s[false]" }, rounding = 0 })

  hl.window_rule({ match = { class = "^(zen-browser|zen)$" }, workspace = "1" })
  hl.window_rule({ match = { class = "^chromium$" }, workspace = "2" })
  hl.window_rule({ match = { class = "(?i)^(code|cursor|antigravity)(-url-handler)?$" }, workspace = "3" })
  hl.window_rule({ match = { class = "^(qbittorrent|steam_app_)" }, workspace = "5" })
  hl.window_rule({ match = { class = "^thunderbird$" }, workspace = "7" })
  hl.window_rule({ match = { class = "(?i)^(org\\.telegram\\.desktop|telegram(-desktop)?)$" }, workspace = "special:telegram" })
  hl.window_rule({ match = { class = "^vesktop$" }, workspace = "special:vesktop" })
  hl.window_rule({ match = { class = "(?i)^slack(-desktop)?$" }, workspace = "special:slack" })

  hl.window_rule({ match = { class = patterns.tiny_class }, float = true, center = true, size = sizes.tiny })
  hl.window_rule({ match = { class = patterns.small_class }, float = true, center = true, size = sizes.small })
  hl.window_rule({
    match = { class = "(?i)^(code|cursor|antigravity)$", title = patterns.small_title },
    float = true,
    center = true,
    size = sizes.small,
  })

  hl.window_rule({ match = { title = patterns.medium_title }, float = true, center = true, size = sizes.medium })
  hl.window_rule({ match = { class = patterns.large_class }, float = true, center = true, size = sizes.large })
  hl.window_rule({ match = { title = patterns.large_title }, float = true, center = true, size = sizes.large })

  hl.window_rule({ match = { title = ".*Global Updates.*" }, float = true, center = true, size = sizes.xlarge })

  hl.window_rule({
    match = { class = "^blender$", initial_title = patterns.blender_splash },
    float = true,
    size = sizes.large,
  })

  hl.window_rule({
    match = { title = patterns.pip_title },
    float = true,
    pin = true,
    size = sizes.large,
    move = "(monitor_w-window_w-(monitor_w*0.02)) (monitor_h-window_h-(monitor_h*0.02))",
  })
end

return M
