local palette = {
    accent      = "rgba(8839b5aa)",
    secondary   = "rgba(f5c2e7ee)",
    inactive    = "rgba(aaaaaaaa)",
    transparent = "rgba(0,0,0,0)",
}

hl.config({
    general    = {
        gaps_in          = 1,
        gaps_out         = 4,
        border_size      = 4,
        allow_tearing    = true,
        resize_on_border = true,
        snap             = { enabled = true, window_gap = 11, monitor_gap = 11 },
        col              = {
            active_border = {
                angle  = 35,
                colors = {
                    palette.accent,
                    palette.transparent,
                    palette.secondary,
                    palette.transparent,
                    palette.accent
                },
            },
            inactive_border = palette.inactive,
        },
    },

    render     = { direct_scanout = 2 },

    decoration = {
        rounding         = 14,
        active_opacity   = 0.92,
        inactive_opacity = 0.92,
        shadow           = { enabled = false },
        blur             = { size = 5, passes = 3 },
    },

    dwindle    = { preserve_split = true, special_scale_factor = 0.85 },
    master     = { new_status = "master", special_scale_factor = 0.85 },
    scrolling  = { follow_focus = true, follow_min_visible = 0.05 },

    misc       = {
        force_default_wallpaper    = 0,
        session_lock_xray          = true,
        disable_hyprland_logo      = true,
        disable_splash_rendering   = true,
        middle_click_paste         = false,
        allow_session_lock_restore = true,
    },
})

local curves = {
    wind      = { { 0.05, 0.90 }, { 0.10, 1.05 } },
    winIn     = { { 0.10, 1.10 }, { 0.10, 1.10 } },
    winOut    = { { 0.30, -0.30 }, { 0.00, 1.00 } },
    liner     = { { 1.00, 1.00 }, { 1.00, 1.00 } },
    overshot  = { { 0.00, 0.00 }, { 1.00, 1.00 } },
    smoothOut = { { 0.50, 0.00 }, { 0.99, 0.99 } },
    smoothIn  = { { 0.50, -0.50 }, { 0.68, 1.50 } },
}

for name, points in pairs(curves) do
    hl.curve(name, { type = "bezier", points = points })
end

local animations = {
    { leaf = "windows",          speed = 3, bezier = "wind",      style = "slide" },
    { leaf = "windowsIn",        speed = 2, bezier = "winIn",     style = "slide" },
    { leaf = "windowsOut",       speed = 1, bezier = "smoothOut", style = "slide" },
    { leaf = "windowsMove",      speed = 2, bezier = "wind",      style = "slide" },
    { leaf = "border",           speed = 1, bezier = "liner" },
    { leaf = "fade",             speed = 2, bezier = "smoothOut" },
    { leaf = "workspaces",       speed = 2, bezier = "overshot" },
    { leaf = "workspacesIn",     speed = 2, bezier = "winIn",     style = "slide" },
    { leaf = "workspacesOut",    speed = 2, bezier = "winOut",    style = "slide" },
    { leaf = "specialWorkspace", speed = 2, bezier = "default",   style = "slidefadevert -90%" },
}

for _, anim in ipairs(animations) do
    anim.enabled = true
    hl.animation(anim)
end
