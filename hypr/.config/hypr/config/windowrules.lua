local function size(width, height)
    return { width, height }
end

local sizes = {
    xlarge = size("(monitor_w*0.85)", "(monitor_h*0.85)"),
    large = size("(monitor_w*0.60)", "(monitor_h*0.60)"),
    medium = size("(monitor_w*0.45)", "(monitor_h*0.45)"),
    small = size("(monitor_w*0.30)", "(monitor_h*0.30)"),
    tiny = size("(monitor_w*0.15)", "(monitor_h*0.15)"),
}

local function float_center(match, window_size)
    hl.window_rule({ match = match, float = true, center = true, size = window_size })
end

-- Global behavior
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })
hl.window_rule({ match = { fullscreen = true }, no_blur = true, no_anim = true })
hl.window_rule({ match = { class = "^steam_app_" }, fullscreen = true, immediate = true })

-- Lazy workspace apps
hl.workspace_rule({ workspace = "1", on_created_empty = "zen-browser" })
hl.workspace_rule({ workspace = "2", on_created_empty = "chromium" })
hl.workspace_rule({ workspace = "3", on_created_empty = "zeditor" })
hl.workspace_rule({ workspace = "special:vesktop", on_created_empty = "vesktop" })
hl.workspace_rule({ workspace = "special:telegram", on_created_empty = "Telegram" })
hl.workspace_rule({ workspace = "special:slack", on_created_empty = "slack" })
hl.workspace_rule({ workspace = "special:terminal", on_created_empty = "xdg-terminal-exec" })

-- Smart gaps
hl.workspace_rule({ workspace = "w[tv1]s[false]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]s[false]", gaps_out = 0, gaps_in = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]s[false]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]s[false]" }, rounding = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]s[false]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]s[false]" }, rounding = 0 })

-- App workspace routing
hl.window_rule({ match = { class = [[^(zen-browser|zen)$]] }, workspace = "1" })
hl.window_rule({ match = { class = [[^chromium$]] }, workspace = "2" })
hl.window_rule({ match = { class = [[(?i)^(code|cursor|antigravity)(-url-handler)?$]] }, workspace = "3" })
hl.window_rule({ match = { class = [[^dev\.zed\.Zed$]] }, workspace = "3" })
hl.window_rule({ match = { class = [[^(qbittorrent|steam_app_)]] }, workspace = "5" })
hl.window_rule({ match = { class = [[(?i)^(thunderbird|org\.mozilla\.thunderbird)$]] }, workspace = "7" })
hl.window_rule({
    match = { class = [[(?i)^(org\.telegram\.desktop|telegram(-desktop)?)$]] },
    workspace = "special:telegram",
})
hl.window_rule({ match = { class = [[^vesktop$]] }, workspace = "special:vesktop" })
hl.window_rule({ match = { class = [[(?i)^slack(-desktop)?$]] }, workspace = "special:slack" })

-- Floating dialogs
local small_editor_dialog_titles = [[^(Do you want to retry your last request\?|Authentication Required)$]]

float_center({ class = [[(?i)^(gnome-calculator|org\.gnome\.calculator)$]] }, sizes.tiny)
float_center({ class = [[^org\.kde\.kdeconnect\.handler$]] }, sizes.small)
float_center({ class = [[(?i)^(code|cursor|antigravity)$]], title = small_editor_dialog_titles }, sizes.small)
float_center({ class = [[^dev\.zed\.Zed$]], title = small_editor_dialog_titles }, sizes.small)
float_center({
    title =
    [[^(Install from VSIX|Downloading Certificate|Open File|Save File|Save As|Open Folder|File Upload|Enter name of file to save to\.\.|About Zen Browser|Steam - Self Updater|Steam Settings|Select File containing CA certificate)$]],
}, sizes.medium)
float_center({
    class =
    [[^(com\.saivert\.pwvucontrol|org\.pulseaudio\.pavucontrol|pavucontrol|gtk-pipe-viewer|blueman-manager|nm-connection-editor|org\.gnome\.DiskUtility|xdg-desktop-portal.*|polkit.*|zenity|waypaper|io\.missioncenter\.MissionCenter|mpv|com\.gabm\.satty)$]],
}, sizes.large)
float_center({
    title = [[^(OpenRGB|Network Connections|imv|nemo|ncmpcpp|Create or select new Steam library folder)$]],
}, sizes.large)
float_center({ title = ".*Global Updates.*" }, sizes.xlarge)

-- Special cases
hl.window_rule({
    match = { class = "^blender$", initial_title = [[^Blender$]] },
    float = true,
    size = sizes.large,
})
hl.window_rule({
    match = { title = [[(?i)^picture.?in.?picture]] },
    float = true,
    pin = true,
    size = sizes.large,
    move = size("monitor_w-window_w-(monitor_w*0.02)", "monitor_h-window_h-(monitor_h*0.02)"),
})
