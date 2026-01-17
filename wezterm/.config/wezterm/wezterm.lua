local wezterm = require("wezterm")
local act = wezterm.action

return {
  -- 1. Performance & Maintenance
  max_fps = 165,                  -- Global cap (Safe for 60Hz laptops)
  check_for_updates = false,      -- Silence update nags

  -- 2. Font & Appearance
  font = wezterm.font("CaskaydiaCove Nerd Font Mono"),
  font_size = 12.0,
  line_height = 1.2,
  -- freetype_load_target = "Light",
  color_scheme = "Catppuccin Mocha",

  -- 3. Window Layout
  window_decorations = "NONE",
  window_close_confirmation = "NeverPrompt",
  window_padding = { left = 10, right = 10, top = 10, bottom = 0 },
  initial_cols = 133,
  initial_rows = 35,

  -- 4. Tab Bar (Bottom & Styled)
  tab_bar_at_bottom = true,
  hide_tab_bar_if_only_one_tab = true,
  tab_max_width = 32,

  -- 5. Color Overrides
  colors = {
    tab_bar = {
      background = "#11111b",
      active_tab = { bg_color = "#1e1e2e", fg_color = "#cba6f7", intensity = "Bold" },
      inactive_tab = { bg_color = "#11111b", fg_color = "#a6adc8" },
      inactive_tab_hover = { bg_color = "#181825", fg_color = "#cdd6f4" },
      new_tab = { bg_color = "#11111b", fg_color = "#a6adc8" },
      new_tab_hover = { bg_color = "#181825", fg_color = "#cdd6f4" },
    },
  },
  
  window_frame = {
    active_titlebar_bg = "#11111b",
    inactive_titlebar_bg = "#11111b",
    font = wezterm.font({ family = "CaskaydiaCove Nerd Font Mono", weight = "Bold" }),
    font_size = 11.0,
  },

  -- 6. Cursor & Bell
  default_cursor_style = "BlinkingBar",
  cursor_blink_rate = 600,
  cursor_blink_ease_in = "Constant",
  audible_bell = "Disabled",

  -- 7. Keybindings
  keys = {
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
  },
}