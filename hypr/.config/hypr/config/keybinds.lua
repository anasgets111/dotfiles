local vars = require("config.vars")
local mod = vars.mainMod

local function bind_workspace(key, workspace)
	hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
end

local function bind_move_to_workspace(key, workspace)
	hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

local workspace_keys = {
	{ "1", 1 },
	{ "2", 2 },
	{ "3", 3 },
	{ "4", 4 },
	{ "5", 5 },
	{ "6", 6 },
	{ "7", 7 },
	{ "8", 8 },
	{ "9", 9 },
	{ "0", 10 },
	{ "KP_End", 1 },
	{ "KP_Down", 2 },
	{ "KP_Next", 3 },
	{ "KP_Left", 4 },
	{ "KP_Begin", 5 },
	{ "KP_Right", 6 },
	{ "KP_Home", 7 },
	{ "KP_Up", 8 },
	{ "KP_Prior", 9 },
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

hl.bind(
	mod .. " + SHIFT + left",
	hl.dsp.window.move({ direction = "l" }),
	{ description = "Move active window to the left" }
)
hl.bind(
	mod .. " + SHIFT + right",
	hl.dsp.window.move({ direction = "r" }),
	{ description = "Move active window to the right" }
)
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "u" }), { description = "Move active window upwards" })
hl.bind(
	mod .. " + SHIFT + down",
	hl.dsp.window.move({ direction = "d" }),
	{ description = "Move active window downwards" }
)

hl.bind(mod .. " + left", hl.dsp.focus({ direction = "l" }), { description = "Move focus to the left" })
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "r" }), { description = "Move focus to the right" })
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "u" }), { description = "Move focus upwards" })
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "d" }), { description = "Move focus downwards" })

hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mod .. " + P", hl.dsp.window.pseudo({ action = "toggle" }))
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))

hl.bind(
	mod .. " + CTRL + SHIFT + right",
	hl.dsp.window.resize({ x = 15, y = 0, relative = true }),
	{ description = "Resize to the right" }
)
hl.bind(
	mod .. " + CTRL + SHIFT + left",
	hl.dsp.window.resize({ x = -15, y = 0, relative = true }),
	{ description = "Resize to the left" }
)
hl.bind(
	mod .. " + CTRL + SHIFT + up",
	hl.dsp.window.resize({ x = 0, y = -15, relative = true }),
	{ description = "Resize upwards" }
)
hl.bind(
	mod .. " + CTRL + SHIFT + down",
	hl.dsp.window.resize({ x = 0, y = 15, relative = true }),
	{ description = "Resize downwards" }
)

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mod .. " + Return", hl.dsp.workspace.toggle_special("terminal"))
hl.bind(mod .. " + KP_Enter", hl.dsp.workspace.toggle_special("terminal"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:terminal" }))
hl.bind(mod .. " + D", hl.dsp.workspace.toggle_special("vesktop"))
hl.bind(mod .. " + T", hl.dsp.workspace.toggle_special("telegram"))
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("slack"))

hl.bind(mod .. " + E", hl.dsp.exec_cmd(vars.fileManager))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(vars.browser, { workspace = "2" }))
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("missioncenter"))
hl.bind(mod .. " + space", hl.dsp.exec_cmd(vars.menu))

hl.bind(mod .. " + C", hl.dsp.exec_cmd("cursor"))
hl.bind(mod .. " + A", hl.dsp.exec_cmd("antigravity.sh"))
hl.bind(mod .. " + Z", hl.dsp.exec_cmd("WAYLAND_DISPLAY='' zeditor"))
hl.bind(mod .. " + H", hl.dsp.exec_cmd("heroic", { workspace = "6" }))
hl.bind(mod .. " + G", hl.dsp.exec_cmd("steam", { workspace = "6" }))
hl.bind(mod .. " + n", hl.dsp.exec_cmd("say --clipboard"))

hl.bind(mod .. " + L", hl.dsp.exec_cmd(vars.lockCmd))
hl.bind(mod .. " + SHIFT + L", hl.dsp.exit())

hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd(vars.lockCmd), { locked = true })
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -q set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q set 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.bind(mod .. " + CTRL + S", hl.dsp.exec_cmd("voxtype record toggle"))
hl.bind(mod .. " + M", hl.dsp.exec_cmd("quickshell ipc call mic mute"))
hl.bind("XF86Calculator", hl.dsp.exec_cmd("gnome-calculator"), { locked = true })

hl.bind("Print", hl.dsp.exec_cmd("hdrshot region"))
hl.bind("CTRL + Print", hl.dsp.exec_cmd("hdrshot output"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("quickshell ipc call rec toggle"))
