local config_home = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or ".") .. "/.config")
local hypr_config = config_home .. "/hypr"

package.path = hypr_config .. "/?.lua;" .. hypr_config .. "/?/init.lua;" .. package.path

for _, module_name in ipairs({
    "config.env",
    "config.startup",
    "config.monitors",
    "config.appearance",
    "config.input",
    "config.windowrules",
    "config.keybinds",
}) do
    require(module_name)
end
