local mod = "SUPER"
local file_manager = "nautilus"
local browser = "zen-browser"
local menu = "quickshell ipc call launcher toggle"
local lock_cmd = "quickshell ipc call lock lock"

local function bind_workspace(key, workspace)
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
end

local function bind_move_to_workspace(key, workspace)
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

local workspace_keys = {
    { "1",         1 },
    { "2",         2 },
    { "3",         3 },
    { "4",         4 },
    { "5",         5 },
    { "6",         6 },
    { "7",         7 },
    { "8",         8 },
    { "9",         9 },
    { "0",         10 },
    { "KP_End",    1 },
    { "KP_Down",   2 },
    { "KP_Next",   3 },
    { "KP_Left",   4 },
    { "KP_Begin",  5 },
    { "KP_Right",  6 },
    { "KP_Home",   7 },
    { "KP_Up",     8 },
    { "KP_Prior",  9 },
    { "KP_Insert", 10 },
}

for _, entry in ipairs(workspace_keys) do
    bind_workspace(entry[1], entry[2])
    bind_move_to_workspace(entry[1], entry[2])
end

hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

local directional_binds = {
    {
        key = "left",
        direction = "l",
        resize = { x = -15, y = 0 },
        move_description = "Move active window to the left",
        focus_description = "Move focus to the left",
        resize_description = "Resize to the left",
    },
    {
        key = "right",
        direction = "r",
        resize = { x = 15, y = 0 },
        move_description = "Move active window to the right",
        focus_description = "Move focus to the right",
        resize_description = "Resize to the right",
    },
    {
        key = "up",
        direction = "u",
        resize = { x = 0, y = -15 },
        move_description = "Move active window upwards",
        focus_description = "Move focus upwards",
        resize_description = "Resize upwards",
    },
    {
        key = "down",
        direction = "d",
        resize = { x = 0, y = 15 },
        move_description = "Move active window downwards",
        focus_description = "Move focus downwards",
        resize_description = "Resize downwards",
    },
}

for _, binding in ipairs(directional_binds) do
    hl.bind(mod .. " + SHIFT + " .. binding.key, hl.dsp.window.move({ direction = binding.direction }), {
        description = binding.move_description,
    })
    hl.bind(mod .. " + " .. binding.key, hl.dsp.focus({ direction = binding.direction }), {
        description = binding.focus_description,
    })
    hl.bind(
        mod .. " + CTRL + SHIFT + " .. binding.key,
        hl.dsp.window.resize({ x = binding.resize.x, y = binding.resize.y, relative = true }),
        { description = binding.resize_description }
    )
end

hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mod .. " + P", hl.dsp.window.pseudo({ action = "toggle" }))
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mod .. " + Return", hl.dsp.workspace.toggle_special("terminal"))
hl.bind(mod .. " + KP_Enter", hl.dsp.workspace.toggle_special("terminal"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:terminal" }))
hl.bind(mod .. " + D", hl.dsp.workspace.toggle_special("vesktop"))
hl.bind(mod .. " + T", hl.dsp.workspace.toggle_special("telegram"))
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("slack"))

hl.bind(mod .. " + E", hl.dsp.exec_cmd(file_manager))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("missioncenter"))
hl.bind(mod .. " + space", hl.dsp.exec_cmd(menu))

hl.bind(mod .. " + C", hl.dsp.exec_cmd("cursor"))
hl.bind(mod .. " + A", hl.dsp.exec_cmd("antigravity.sh"))
hl.bind(mod .. " + Z", hl.dsp.exec_cmd("WAYLAND_DISPLAY='' zeditor"))
hl.bind(mod .. " + H", hl.dsp.exec_cmd("heroic", { workspace = "6" }))
hl.bind(mod .. " + G", hl.dsp.exec_cmd("steam", { workspace = "6" }))
hl.bind(mod .. " + n", hl.dsp.exec_cmd("say --clipboard"))

hl.bind(mod .. " + L", hl.dsp.exec_cmd(lock_cmd))
hl.bind(mod .. " + SHIFT + L", hl.dsp.exit())

hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd(lock_cmd), { locked = true })

local locked_repeating_command_binds = {
    { key = "XF86AudioRaiseVolume",  command = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+" },
    { key = "XF86AudioLowerVolume",  command = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" },
    { key = "XF86AudioMute",         command = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" },
    { key = "XF86AudioMicMute",      command = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" },
    { key = "XF86MonBrightnessUp",   command = "brightnessctl -q set 5%+" },
    { key = "XF86MonBrightnessDown", command = "brightnessctl -q set 5%-" },
}

for _, binding in ipairs(locked_repeating_command_binds) do
    hl.bind(binding.key, hl.dsp.exec_cmd(binding.command), { locked = true, repeating = true })
end

local locked_command_binds = {
    { key = "XF86AudioNext",  command = "playerctl next" },
    { key = "XF86AudioPause", command = "playerctl play-pause" },
    { key = "XF86AudioPlay",  command = "playerctl play-pause" },
    { key = "XF86AudioPrev",  command = "playerctl previous" },
    { key = "XF86Calculator", command = "gnome-calculator" },
}

for _, binding in ipairs(locked_command_binds) do
    hl.bind(binding.key, hl.dsp.exec_cmd(binding.command), { locked = true })
end

hl.bind(mod .. " + CTRL + S", hl.dsp.exec_cmd("voxtype record toggle"))
hl.bind(mod .. " + M", hl.dsp.exec_cmd("quickshell ipc call mic mute"))

local screenshot_binds = {
    { key = "Print",         command = "hdrshot region" },
    { key = "CTRL + Print",  command = "hdrshot output" },
    { key = "SHIFT + Print", command = "quickshell ipc call rec toggle" },
}

for _, binding in ipairs(screenshot_binds) do
    hl.bind(binding.key, hl.dsp.exec_cmd(binding.command))
end
