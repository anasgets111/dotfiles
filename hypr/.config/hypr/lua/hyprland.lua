-- Staged Hyprland Lua configuration.
-- This file is intentionally kept under ./lua so the current hyprland.conf
-- remains active until the Lua migration is enabled explicitly.

local source = debug and debug.getinfo and debug.getinfo(1, "S").source or nil
local config_dir = source and source:sub(1, 1) == "@" and source:sub(2):match("(.+)/[^/]+$") or nil
local home = os and os.getenv and os.getenv("HOME") or nil
config_dir = config_dir or (home and (home .. "/.config/hypr/lua") or ".")
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
