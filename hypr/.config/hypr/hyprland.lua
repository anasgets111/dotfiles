local config_home = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or ".") .. "/.config")
local hypr_config = config_home .. "/hypr"

package.path = hypr_config .. "/?.lua;" .. hypr_config .. "/?/init.lua;" .. package.path

-- Modules
require("config.env")
require("config.startup")
require("config.monitors")
require("config.appearance")
require("config.input")
require("config.windowrules")
require("config.keybinds")
