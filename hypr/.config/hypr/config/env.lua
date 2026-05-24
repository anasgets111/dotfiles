local cursor_theme = "Bibata-Modern-Ice"
local cursor_size = "24"

for key, value in pairs({
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1",
    -- QT_QUICK_CONTROLS_STYLE             = "org.hyprland.style",
    HYPRCURSOR_THEME                    = cursor_theme,
    HYPRCURSOR_SIZE                     = cursor_size,
    XCURSOR_THEME                       = cursor_theme,
    XCURSOR_SIZE                        = cursor_size,
    GTK_THEME                           = "Catppuccin-GnomeTheme",
    PASSWORD_STORE                      = "secret-service",
}) do
    hl.env(key, value)
end
