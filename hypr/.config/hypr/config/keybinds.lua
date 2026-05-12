local mod = "SUPER"
local file_manager = "nautilus"
local browser = "zen-browser"
local menu = "quickshell ipc call launcher toggle"
local lock_cmd = "quickshell ipc call lock lock"

local function bind(keys, dispatcher, options)
    return { keys, dispatcher, options }
end

local workspace_keys = {
    { "1", "KP_End" },
    { "2", "KP_Down" },
    { "3", "KP_Next" },
    { "4", "KP_Left" },
    { "5", "KP_Begin" },
    { "6", "KP_Right" },
    { "7", "KP_Home" },
    { "8", "KP_Up" },
    { "9", "KP_Prior" },
    { "0", "KP_Insert" },
}

for workspace, keys in ipairs(workspace_keys) do
    for _, key in ipairs(keys) do
        hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
        hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
    end
end

local directions = {
    { key = "left",  dir = "l", x = -15, y = 0,   desc = "to the left" },
    { key = "right", dir = "r", x = 15,  y = 0,   desc = "to the right" },
    { key = "up",    dir = "u", x = 0,   y = -15, desc = "upwards" },
    { key = "down",  dir = "d", x = 0,   y = 15,  desc = "downwards" },
}

for _, direction in ipairs(directions) do
    hl.bind(mod .. " + " .. direction.key, hl.dsp.focus({ direction = direction.dir }),
        { description = "Move focus " .. direction.desc })
    hl.bind(mod .. " + SHIFT + " .. direction.key, hl.dsp.window.move({ direction = direction.dir }),
        { description = "Move window " .. direction.desc })
    hl.bind(mod .. " + CTRL + SHIFT + " .. direction.key,
        hl.dsp.window.resize({ x = direction.x, y = direction.y, relative = true }),
        { description = "Resize " .. direction.desc })
end

local keybinds = {
    -- Window Management
    bind(mod .. " + Q", hl.dsp.window.close()),
    bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" })),
    bind(mod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" })),
    bind(mod .. " + P", hl.dsp.window.pseudo({ action = "toggle" })),
    bind(mod .. " + J", hl.dsp.layout("togglesplit")),
    bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true }),
    bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true }),

    -- Special Workspaces
    bind(mod .. " + Return", hl.dsp.workspace.toggle_special("terminal")),
    bind(mod .. " + KP_Enter", hl.dsp.workspace.toggle_special("terminal")),
    bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:terminal" })),
    bind(mod .. " + D", hl.dsp.workspace.toggle_special("vesktop")),
    bind(mod .. " + T", hl.dsp.workspace.toggle_special("telegram")),
    bind(mod .. " + S", hl.dsp.workspace.toggle_special("slack")),

    -- Cycle Workspaces
    bind(mod .. " + Tab", hl.dsp.focus({ workspace = "e+1" })),
    bind(mod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "e-1" })),
    bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" })),
    bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" })),

    -- Apps & Utilities
    bind(mod .. " + E", hl.dsp.exec_cmd(file_manager)),
    bind(mod .. " + B", hl.dsp.exec_cmd(browser)),
    bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("missioncenter")),
    bind(mod .. " + space", hl.dsp.exec_cmd(menu)),
    bind(mod .. " + C", hl.dsp.exec_cmd("cursor")),
    bind(mod .. " + A", hl.dsp.exec_cmd("antigravity.sh")),
    bind(mod .. " + Z", hl.dsp.exec_cmd("WAYLAND_DISPLAY='' zeditor")),
    bind(mod .. " + H", hl.dsp.exec_cmd("heroic", { workspace = "6" })),
    bind(mod .. " + G", hl.dsp.exec_cmd("steam", { workspace = "6" })),
    bind(mod .. " + n", hl.dsp.exec_cmd("say --clipboard")),
    bind(mod .. " + CTRL + S", hl.dsp.exec_cmd("voxtype record toggle")),
    bind(mod .. " + M", hl.dsp.exec_cmd("quickshell ipc call mic mute")),

    -- System & Lock
    bind(mod .. " + L", hl.dsp.exec_cmd(lock_cmd)),
    bind(mod .. " + SHIFT + L", hl.dsp.exec_cmd("uwsm stop")),
    bind("switch:on:Lid Switch", hl.dsp.exec_cmd(lock_cmd), { locked = true }),

    -- Media & Hardware
    bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
        { locked = true, repeating = true }),
    bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
        { locked = true, repeating = true }),
    bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -q set 5%+"),
        { locked = true, repeating = true }),
    bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q set 5%-"),
        { locked = true, repeating = true }),
    bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true }),
    bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true }),
    bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true }),
    bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true }),
    bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true }),
    bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true }),
    bind("XF86Calculator", hl.dsp.exec_cmd("gnome-calculator"), { locked = true }),

    -- Screenshots
    bind("Print", hl.dsp.exec_cmd("hdrshot region")),
    bind("CTRL + Print", hl.dsp.exec_cmd("hdrshot output")),
    bind("SHIFT + Print", hl.dsp.exec_cmd("quickshell ipc call rec toggle")),
}

for _, binding in ipairs(keybinds) do
    hl.bind(binding[1], binding[2], binding[3])
end
