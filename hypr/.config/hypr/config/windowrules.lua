local sizes = {
    large  = { "(monitor_w*0.60)", "(monitor_h*0.60)" },
    medium = { "(monitor_w*0.45)", "(monitor_h*0.45)" },
    small  = { "(monitor_w*0.30)", "(monitor_h*0.30)" },
    tiny   = { "(monitor_w*0.10)", "(monitor_h*0.15)" },
}

-- Globals
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ match = { fullscreen = true }, no_blur = true, no_anim = true })
hl.window_rule({ match = { class = "steam_app_.*" }, fullscreen = true, immediate = true })

-- Lazy Workspaces
for workspace, app in pairs({
    ["1"]                = "zen-browser",
    ["3"]                = "zeditor",
    ["special:vesktop"]  = "vesktop",
    ["special:telegram"] = "Telegram",
    ["special:slack"]    = "slack",
    ["special:terminal"] = "xdg-terminal-exec",
}) do
    hl.workspace_rule({ workspace = workspace, on_created_empty = app })
end

-- Smart gaps for single tiled/fullscreen windows, excluding special workspaces
for _, selector in ipairs({ "w[tv1]s[false]", "f[1]s[false]" }) do
    hl.workspace_rule({ workspace = selector, gaps_out = 0, gaps_in = 0 })
    hl.window_rule({ match = { float = false, workspace = selector }, border_size = 0, rounding = 0 })
end

-- App Routing
for workspace, classes in pairs({
    ["1"]                       = { "zen" },
    ["3 silent"]                = { [[dev\.zed\.Zed]] },
    ["5 silent"]                = { [[org\.qbittorrent\.qBittorrent]], "steam_app_.*" },
    ["7 silent"]                = { [[org\.mozilla\.Thunderbird]] },
    ["special:telegram silent"] = { [[org\.telegram\.desktop]] },
    ["special:vesktop silent"]  = { "vesktop" },
    ["special:slack silent"]    = { "slack" },
}) do
    for _, class in ipairs(classes) do
        hl.window_rule({ match = { class = class }, workspace = workspace })
    end
end

-- Floating Dialogs & Special Cases
local function float_rule(size, match, options)
    local rule = options or {}
    for property, patterns in pairs(match) do
        if type(patterns) == "table" then
            match[property] = "(" .. table.concat(patterns, "|") .. ")"
        end
    end
    rule.match = match
    if size then rule.size = size end
    rule.float = true
    if not rule.move then rule.center = true end
    hl.window_rule(rule)
end

float_rule(nil, { modal = true })
float_rule(sizes.tiny, { class = [[org\.gnome\.Calculator]] })
float_rule(sizes.small, { class = [[org\.kde\.kdeconnect\.handler]] })
float_rule(sizes.medium, {
    initial_title = {
        "Steam - Self Updater",
        "Steam Settings",
    },
})
float_rule(sizes.large, {
    class = {
        "xdg-desktop-portal-gtk",
        "xdg-desktop-portal-gnome",
        [[org\.kde\.kdeconnect\.app]],
        [[org\.gnome\.DiskUtility]],
        "zenity",
        [[io\.missioncenter\.MissionCenter]],
        "mpv",
        [[com\.gabm\.satty]],
    },
})
float_rule(sizes.large, {
    initial_title = {
        "OpenRGB",
        "Create or select new Steam library folder",
    },
})
float_rule(sizes.large, { class = "blender", initial_title = "Blender" })
float_rule(sizes.large, { initial_title = "Picture-in-Picture" }, {
    pin  = true,
    -- 60% window size leaves 38% for its origin and a 2% edge margin.
    move = { "(monitor_w*0.38)", "(monitor_h*0.38)" },
})
