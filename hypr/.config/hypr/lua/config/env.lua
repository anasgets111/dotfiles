local M = {}

function M.apply()
  hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
  hl.env("XDG_SESSION_DESKTOP", "Hyprland")
  hl.env("XDG_SESSION_TYPE", "wayland")

  hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
  hl.env("QT_QUICK_CONTROLS_STYLE", "org.hyprland.style")

  hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
  hl.env("HYPRCURSOR_SIZE", "24")
  hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
  hl.env("XCURSOR_SIZE", "24")

  hl.env("GTK_THEME", "Catppuccin-GnomeTheme")
  hl.env("PASSWORD_STORE", "secret-service")
end

return M
