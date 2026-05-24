local sizes = {
    xlarge = { "(monitor_w*0.85)", "(monitor_h*0.85)" },
    large  = { "(monitor_w*0.60)", "(monitor_h*0.60)" },
    medium = { "(monitor_w*0.45)", "(monitor_h*0.45)" },
    small  = { "(monitor_w*0.30)", "(monitor_h*0.30)" },
    tiny   = { "(monitor_w*0.10)", "(monitor_h*0.15)" },
}

-- 1. Globals
for _, rule in ipairs({
    { match = { class = ".*" },             suppress_event = "maximize", idle_inhibit = "fullscreen" },
    { match = { fullscreen = true },        no_blur = true,              no_anim = true },
    { match = { class = "^steam_app_.*$" }, fullscreen = true,           immediate = true },
}) do
    hl.window_rule(rule)
end

-- 2. Lazy Workspaces
for workspace, app in pairs({
    ["1"]                = "zen-browser",
    ["2"]                = "chromium",
    ["3"]                = "zeditor",
    ["special:vesktop"]  = "vesktop",
    ["special:telegram"] = "Telegram",
    ["special:slack"]    = "slack",
    ["special:terminal"] = "xdg-terminal-exec",
}) do
    hl.workspace_rule({ workspace = workspace, on_created_empty = app })
end

-- 3. Smart Gaps
for _, workspace in ipairs({ "w[tv1]s[false]", "f[1]s[false]" }) do
    hl.workspace_rule({ workspace = workspace, gaps_out = 0, gaps_in = 0 })
    hl.window_rule({ match = { float = false, workspace = workspace }, border_size = 0, rounding = 0 })
end

-- 4. App Routing
for workspace, patterns in pairs({
    ["1"]                       = { [[^(zen-browser|zen)$]] },
    ["2 silent"]                = { [[^chromium$]] },
    ["3 silent"]                = { [[(?i)^(code|cursor|antigravity)(-url-handler)?$]], [[^dev\.zed\.Zed$]] },
    ["5 silent"]                = { [[^qbittorrent$]], [[^steam_app_.*$]] },
    ["7 silent"]                = { [[(?i)^(thunderbird|org\.mozilla\.thunderbird)$]] },
    ["special:telegram silent"] = { [[(?i)^(org\.telegram\.desktop|telegram(-desktop)?)$]] },
    ["special:vesktop silent"]  = { [[^vesktop$]] },
    ["special:slack silent"]    = { [[(?i)^slack(-desktop)?$]] },
}) do
    for _, pattern in ipairs(patterns) do
        hl.window_rule({ match = { class = pattern }, workspace = workspace })
    end
end

-- 5. Floating Dialogs & Special Cases
for _, rule in ipairs({
    { match = { class = [[(?i)^(gnome-calculator|org\.gnome\.calculator)$]] },                                                                                                                                                                                                         size = sizes.tiny },
    { match = { class = [[^org\.kde\.kdeconnect\.handler$]] },                                                                                                                                                                                                                         size = sizes.small },
    { match = { class = [[(?i)^(code|cursor|antigravity)$]], modal = true },                                                                                                                                                                                                           size = sizes.small },
    { match = { class = [[^dev\.zed\.Zed$]], modal = true },                                                                                                                                                                                                                           size = sizes.small },
    { match = { title = [[^(Install from VSIX|Downloading Certificate|Open File|Save File|Save As|Open Folder|File Upload|Enter name of file to save to\.\.|About Zen Browser|Steam - Self Updater|Steam Settings|Select File containing CA certificate)$]] },                         size = sizes.medium },
    { match = { class = [[^(com\.saivert\.pwvucontrol|org\.pulseaudio\.pavucontrol|pavucontrol|gtk-pipe-viewer|blueman-manager|nm-connection-editor|org\.gnome\.DiskUtility|xdg-desktop-portal.*|polkit.*|zenity|waypaper|io\.missioncenter\.MissionCenter|mpv|com\.gabm\.satty)$]] }, size = sizes.large },
    { match = { title = [[^(OpenRGB|Network Connections|imv|nemo|ncmpcpp|Create or select new Steam library folder)$]] },                                                                                                                                                              size = sizes.large },
    { match = { title = ".*Global Updates.*" },                                                                                                                                                                                                                                        size = sizes.xlarge },
    { match = { class = "^blender$", initial_title = [[^Blender$]] },                                                                                                                                                                                                                  size = sizes.large },
    {
        match = { title = [[(?i)^picture.?in.?picture]] },
        pin   = true,
        size  = sizes.large,
        move  = { "monitor_w-window_w-(monitor_w*0.02)", "monitor_h-window_h-(monitor_h*0.02)" }
    },
}) do
    local floater = {}
    for k, v in pairs(rule) do floater[k] = v end
    floater.float = true
    if not floater.move then floater.center = true end
    hl.window_rule(floater)
end
