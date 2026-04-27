-- Staged Hyprland Lua configuration.
-- This file is intentionally kept under ./lua so the current hyprland.conf
-- remains active until the Lua migration is enabled explicitly.

local source = debug.getinfo(1, "S").source
local config_dir = source:sub(1, 1) == "@" and source:sub(2):match("(.+)/[^/]+$") or "."
package.path = config_dir .. "/?.lua;" .. config_dir .. "/?/init.lua;" .. package.path

local ctx = require("config.helpers").context

require("config.env").apply(ctx)
require("config.monitors").apply(ctx)
require("config.startup").apply(ctx)
require("config.appearance").apply(ctx)
require("config.input").apply(ctx)
require("config.windowrules").apply(ctx)
require("config.keybinds").apply(ctx)

hl.config({
  xwayland = {
    enabled = true,
  },
})
