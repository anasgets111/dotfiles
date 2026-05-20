local Bind = require("config.bind")

local mod = "SUPER"
local file_manager = "nautilus"
local browser = "zen-browser"
local menu = "quickshell ipc call launcher toggle"
local lock_cmd = "quickshell ipc call lock lock"

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
    Bind.leader_key(mod, keys, hl.dsp.focus({ workspace = workspace }))
    Bind.leader_key(mod, { "SHIFT + " .. keys[1], "SHIFT + " .. keys[2] },
        hl.dsp.window.move({ workspace = workspace }))
end

local directions = {
    { key = "left",  dir = "l", x = -15, y = 0,   desc = "to the left" },
    { key = "right", dir = "r", x = 15,  y = 0,   desc = "to the right" },
    { key = "up",    dir = "u", x = 0,   y = -15, desc = "upwards" },
    { key = "down",  dir = "d", x = 0,   y = 15,  desc = "downwards" },
}

for _, direction in ipairs(directions) do
    Bind.leader_key(mod, direction.key, hl.dsp.focus({ direction = direction.dir }),
        { description = "Move focus " .. direction.desc })
    Bind.leader_key(mod, "SHIFT + " .. direction.key, hl.dsp.window.move({ direction = direction.dir }),
        { description = "Move window " .. direction.desc })
    Bind.leader_key(mod, "CTRL + SHIFT + " .. direction.key,
        hl.dsp.window.resize({ x = direction.x, y = direction.y, relative = true }),
        { description = "Resize " .. direction.desc })
end

local keybinds = {
    -- Window Management
    { mod .. " + Q",           hl.dsp.window.close() },
    { mod .. " + V",           hl.dsp.window.float({ action = "toggle" }) },
    { mod .. " + F",           hl.dsp.window.fullscreen({ action = "toggle" }) },
    { mod .. " + P",           hl.dsp.window.pseudo({ action = "toggle" }) },
    { mod .. " + J",           hl.dsp.layout("togglesplit") },
    { mod .. " + mouse:272",   hl.dsp.window.drag(),                                  { mouse = true } },
    { mod .. " + mouse:273",   hl.dsp.window.resize(),                                { mouse = true } },

    -- Special Workspaces
    { mod .. " + Return",      hl.dsp.workspace.toggle_special("terminal") },
    { mod .. " + KP_Enter",    hl.dsp.workspace.toggle_special("terminal") },
    { mod .. " + SHIFT + S",   hl.dsp.window.move({ workspace = "special:terminal" }) },
    { mod .. " + D",           hl.dsp.workspace.toggle_special("vesktop") },
    { mod .. " + T",           hl.dsp.workspace.toggle_special("telegram") },
    { mod .. " + S",           hl.dsp.workspace.toggle_special("slack") },

    -- Cycle Workspaces
    { mod .. " + Tab",         hl.dsp.focus({ workspace = "e+1" }) },
    { mod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "e-1" }) },
    { mod .. " + mouse_down",  hl.dsp.focus({ workspace = "e+1" }) },
    { mod .. " + mouse_up",    hl.dsp.focus({ workspace = "e-1" }) },

    -- Apps & Utilities
    { mod .. " + E",           hl.dsp.exec_cmd(file_manager) },
    { mod .. " + B",           hl.dsp.exec_cmd(browser) },
    { "CTRL + ALT + Delete",   hl.dsp.exec_cmd("missioncenter") },
    { mod .. " + space",       hl.dsp.exec_cmd(menu) },
    { mod .. " + C",           hl.dsp.exec_cmd("cursor") },
    { mod .. " + A",           hl.dsp.exec_cmd("antigravity.sh") },
    { mod .. " + Z",           hl.dsp.exec_cmd("WAYLAND_DISPLAY='' zeditor") },
    { mod .. " + H",           hl.dsp.exec_cmd("heroic", { workspace = "6" }) },
    { mod .. " + G",           hl.dsp.exec_cmd("steam", { workspace = "6" }) },
    { mod .. " + n",           hl.dsp.exec_cmd("say --clipboard") },
    { mod .. " + CTRL + S",    hl.dsp.exec_cmd("voxtype record toggle") },
    { mod .. " + M",           hl.dsp.exec_cmd("quickshell ipc call mic mute") },

    -- System & Lock
    { mod .. " + L",           hl.dsp.exec_cmd(lock_cmd) },
    { mod .. " + SHIFT + L",   hl.dsp.exec_cmd("uwsm stop") },
    { "switch:on:Lid Switch",  hl.dsp.exec_cmd(lock_cmd),                             { locked = true } },

    -- Media & Hardware
    { "XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
        { locked = true, repeating = true } },
    { "XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
        { locked = true, repeating = true } },
    { "XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -q set 5%+"),
        { locked = true, repeating = true } },
    { "XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q set 5%-"),
        { locked = true, repeating = true } },
    { "XF86AudioMute",    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true } },
    { "XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true } },
    { "XF86AudioNext",    hl.dsp.exec_cmd("playerctl next"),                               { locked = true } },
    { "XF86AudioPause",   hl.dsp.exec_cmd("playerctl play-pause"),                         { locked = true } },
    { "XF86AudioPlay",    hl.dsp.exec_cmd("playerctl play-pause"),                         { locked = true } },
    { "XF86AudioPrev",    hl.dsp.exec_cmd("playerctl previous"),                           { locked = true } },
    { "XF86Calculator",   hl.dsp.exec_cmd("gnome-calculator"),                             { locked = true } },

    -- Screenshots
    { "Print",            hl.dsp.exec_cmd("hdrshot region") },
    { "CTRL + Print",     hl.dsp.exec_cmd("hdrshot output") },
    { "SHIFT + Print",    hl.dsp.exec_cmd("quickshell ipc call rec toggle") },
}

Bind.keys(keybinds)
