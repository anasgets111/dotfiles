-- Hyprland 0.55+ Lua configuration entrypoint.
-- Modules live under ./config. The old hyprlang config is kept under ./old.

local config_home = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or ".") .. "/.config")
local hypr_config = config_home .. "/hypr"

package.path = hypr_config .. "/?.lua;" .. hypr_config .. "/?/init.lua;" .. package.path

require("config.env")
require("config.startup")
require("config.monitors")
require("config.appearance")
require("config.input")
require("config.windowrules")
require("config.keybinds")
