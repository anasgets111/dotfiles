local mod = "SUPER"
local file_manager = "nautilus"
local browser = "zen-browser"
local menu = "quickshell ipc call launcher toggle"
local lock_command = "quickshell ipc call lock lock"

local function bind(keys, dispatcher, options)
    if type(keys) == "string" then keys = { keys } end

    for _, key in ipairs(keys) do
        hl.bind(key, dispatcher, options)
    end
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
        bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
        bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
    end
end

local directions = {
    { key = "left",  direction = "l", x = -15, y = 0,   description = "to the left" },
    { key = "right", direction = "r", x = 15,  y = 0,   description = "to the right" },
    { key = "up",    direction = "u", x = 0,   y = -15, description = "upwards" },
    { key = "down",  direction = "d", x = 0,   y = 15,  description = "downwards" },
}

for _, direction in ipairs(directions) do
    bind(mod .. " + " .. direction.key, hl.dsp.focus({ direction = direction.direction }),
        { description = "Move focus " .. direction.description })
    bind(mod .. " + SHIFT + " .. direction.key, hl.dsp.window.move({ direction = direction.direction }),
        { description = "Move window " .. direction.description })
    bind(mod .. " + CTRL + SHIFT + " .. direction.key,
        hl.dsp.window.resize({ x = direction.x, y = direction.y, relative = true }),
        { description = "Resize " .. direction.description })
end

local keybinds = {
    -- Window management
    { mod .. " + Q",                                     hl.dsp.window.close() },
    { mod .. " + V",                                     hl.dsp.window.float({ action = "toggle" }) },
    { mod .. " + F",                                     hl.dsp.window.fullscreen({ action = "toggle" }) },
    { mod .. " + P",                                     hl.dsp.window.pseudo({ action = "toggle" }) },
    { mod .. " + J",                                     hl.dsp.layout("togglesplit") },
    { mod .. " + mouse:272",                             hl.dsp.window.drag(),                                  { mouse = true } },
    { mod .. " + mouse:273",                             hl.dsp.window.resize(),                                { mouse = true } },

    -- Special workspaces
    { { mod .. " + Return", mod .. " + KP_Enter" },      hl.dsp.workspace.toggle_special("terminal") },
    { mod .. " + SHIFT + S",                             hl.dsp.window.move({ workspace = "special:terminal" }) },
    { mod .. " + D",                                     hl.dsp.workspace.toggle_special("vesktop") },
    { mod .. " + T",                                     hl.dsp.workspace.toggle_special("telegram") },
    { mod .. " + S",                                     hl.dsp.workspace.toggle_special("slack") },

    -- Cycle workspaces
    { { mod .. " + Tab", mod .. " + mouse_down" },       hl.dsp.focus({ workspace = "e+1" }) },
    { { mod .. " + SHIFT + Tab", mod .. " + mouse_up" }, hl.dsp.focus({ workspace = "e-1" }) },

    -- Apps and utilities
    { mod .. " + E",                                     hl.dsp.exec_cmd(file_manager) },
    { mod .. " + B",                                     hl.dsp.exec_cmd(browser) },
    { "CTRL + ALT + Delete",                             hl.dsp.exec_cmd("missioncenter") },
    { mod .. " + space",                                 hl.dsp.exec_cmd(menu) },
    { mod .. " + C",                                     hl.dsp.exec_cmd("cursor") },
    { mod .. " + A",                                     hl.dsp.exec_cmd("antigravity.sh") },
    { mod .. " + Z",                                     hl.dsp.exec_cmd("WAYLAND_DISPLAY='' zeditor") },
    { mod .. " + H",                                     hl.dsp.exec_cmd("heroic", { workspace = "6" }) },
    { mod .. " + G",                                     hl.dsp.exec_cmd("steam", { workspace = "6" }) },
    { mod .. " + n",                                     hl.dsp.exec_cmd("say --clipboard") },
    { mod .. " + CTRL + S",                              hl.dsp.exec_cmd("voxtype record toggle") },
    { mod .. " + M",                                     hl.dsp.exec_cmd("quickshell ipc call mic mute") },

    -- System and lock
    { mod .. " + L",                                     hl.dsp.exec_cmd(lock_command) },
    { mod .. " + SHIFT + L",                             hl.dsp.exec_cmd("uwsm stop") },
    { "switch:on:Lid Switch",                            hl.dsp.exec_cmd(lock_command),                         { locked = true } },

    -- Media and hardware
    { "XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
        { locked = true, repeating = true } },
    { "XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
        { locked = true, repeating = true } },
    { "XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -q set 5%+"),
        { locked = true, repeating = true } },
    { "XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q set 5%-"),
        { locked = true, repeating = true } },
    { "XF86AudioMute",                       hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true } },
    { "XF86AudioMicMute",                    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true } },
    { "XF86AudioNext",                       hl.dsp.exec_cmd("playerctl next"),                               { locked = true } },
    { { "XF86AudioPause", "XF86AudioPlay" }, hl.dsp.exec_cmd("playerctl play-pause"),                         { locked = true } },
    { "XF86AudioPrev",                       hl.dsp.exec_cmd("playerctl previous"),                           { locked = true } },
    { "XF86Calculator",                      hl.dsp.exec_cmd("gnome-calculator"),                             { locked = true } },

    -- Screenshots
    { "Print",                               hl.dsp.exec_cmd("hdrshot region") },
    { "CTRL + Print",                        hl.dsp.exec_cmd("hdrshot output") },
    { "SHIFT + Print",                       hl.dsp.exec_cmd("quickshell ipc call rec toggle") },
}

for _, binding in ipairs(keybinds) do
    bind(table.unpack(binding))
end
