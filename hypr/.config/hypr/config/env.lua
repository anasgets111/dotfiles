-- Variables
local env_vars = {
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1",
    -- QT_QUICK_CONTROLS_STYLE             = "org.hyprland.style",
    HYPRCURSOR_THEME                    = "Bibata-Modern-Ice",
    HYPRCURSOR_SIZE                     = "24",
    XCURSOR_THEME                       = "Bibata-Modern-Ice",
    XCURSOR_SIZE                        = "24",
    GTK_THEME                           = "Catppuccin-GnomeTheme",
    PASSWORD_STORE                      = "secret-service",
}

for key, value in pairs(env_vars) do
    hl.env(key, value)
end
