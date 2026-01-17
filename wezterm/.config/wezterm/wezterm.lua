local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- 1. Performance & Core
config.front_end = "WebGpu" -- Faster rendering for modern systems
config.max_fps = 165
config.check_for_updates = false
config.scrollback_lines = 5000
-- 2. Tiling WM Optimizations
config.use_resize_increments = false
config.adjust_window_size_when_changing_font_size = false
config.pane_focus_follows_mouse = true

-- 3. Font & Rendering
config.font = wezterm.font("CaskaydiaCove Nerd Font Mono")
config.font_size = 12.0
config.line_height = 1.1

-- 4. Window & Appearance
config.color_scheme = "Catppuccin Mocha"
config.window_decorations = "NONE"
config.window_close_confirmation = "NeverPrompt"
config.window_padding = { left = 10, right = 10, top = 10, bottom = 0 }
config.initial_cols = 133
config.initial_rows = 35

-- 5. Modern Tab Bar
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = true
config.tab_max_width = 64

-- 6. Color Overrides
config.colors = {
  tab_bar = {
    background = "#11111b",
    active_tab = { bg_color = "#1e1e2e", fg_color = "#cba6f7", intensity = "Bold" },
    inactive_tab = { bg_color = "#11111b", fg_color = "#a6adc8" },
    inactive_tab_hover = { bg_color = "#181825", fg_color = "#cdd6f4" },
    new_tab = { bg_color = "#11111b", fg_color = "#a6adc8" },
    new_tab_hover = { bg_color = "#181825", fg_color = "#cdd6f4" },
  },
}
config.window_frame = {
  active_titlebar_bg = "#11111b",
  inactive_titlebar_bg = "#11111b",
  font = wezterm.font({ family = "CaskaydiaCove Nerd Font Mono", weight = "Bold" }),
  font_size = 11.0,
}

-- 7. Cursor & Bell
config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 600
config.cursor_blink_ease_in = "Constant"
config.audible_bell = "Disabled"

-- 8. Keybindings
config.keys = {
  { key = "{", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
  { key = "}", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(1) },
  { key = ";", mods = "CTRL", action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = "_", mods = "CTRL|SHIFT", action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = "W", mods = "CTRL|SHIFT", action = act.CloseCurrentPane { confirm = false } },
  { key = "d", mods = "CTRL|SHIFT", action = act.ScrollByPage(1) },
  { key = "u", mods = "CTRL|SHIFT", action = act.ScrollByPage(-1) },
  { key = "(", mods = "CTRL|SHIFT", action = act.ScrollToTop },
  { key = ")", mods = "CTRL|SHIFT", action = act.ScrollToBottom },
  { key = "<", mods = "CTRL|SHIFT", action = act.ReloadConfiguration },
}

return config