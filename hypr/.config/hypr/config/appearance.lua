local palette = {
    accent      = "rgba(8839b5aa)",
    secondary   = "rgba(f5c2e7ee)",
    inactive    = "rgba(aaaaaaaa)",
    transparent = "rgba(0,0,0,0)",
}

-- 1. Core
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

    render     = { direct_scanout = 2, cm_auto_hdr = 1 },

    decoration = {
        rounding         = 14,
        active_opacity   = 0.97,
        inactive_opacity = 0.97,
        shadow           = { enabled = false },
        blur             = { size = 5, passes = 3 },
    },

    dwindle    = { preserve_split = true, special_scale_factor = 0.85 },
    master     = { new_status = "master", special_scale_factor = 0.85 },
    scrolling  = { follow_focus = true, follow_min_visible = 0, focus_fit_method = 1 },

    misc       = {
        force_default_wallpaper    = 0,
        session_lock_xray          = true,
        disable_hyprland_logo      = true,
        disable_splash_rendering   = true,
        middle_click_paste         = false,
        allow_session_lock_restore = true,
    },
})

-- 2. Curves
local curves = {
    wind      = { { 0.05, 0.90 }, { 0.10, 1.05 } },
    winIn     = { { 0.10, 1.10 }, { 0.10, 1.10 } },
    winOut    = { { 0.30, -0.30 }, { 0.00, 1.00 } },
    linear    = { { 1.00, 1.00 }, { 1.00, 1.00 } },
    overshot  = { { 0.05, 0.90 }, { 0.10, 1.10 } },
    smoothOut = { { 0.50, 0.00 }, { 0.99, 0.99 } },
}

for name, points in pairs(curves) do
    hl.curve(name, { type = "bezier", points = points })
end

-- 3. Animations
local animations = {
    { enabled = true, leaf = "windows",          speed = 3, bezier = "wind",      style = "slide" },
    { enabled = true, leaf = "windowsIn",        speed = 2, bezier = "winIn",     style = "slide" },
    { enabled = true, leaf = "windowsOut",       speed = 1, bezier = "smoothOut", style = "slide" },
    { enabled = true, leaf = "windowsMove",      speed = 2, bezier = "wind",      style = "slide" },
    { enabled = true, leaf = "border",           speed = 1, bezier = "linear" },
    { enabled = true, leaf = "fade",             speed = 2, bezier = "smoothOut" },
    { enabled = true, leaf = "workspaces",       speed = 2, bezier = "overshot" },
    { enabled = true, leaf = "workspacesIn",     speed = 2, bezier = "winIn",     style = "slide" },
    { enabled = true, leaf = "workspacesOut",    speed = 2, bezier = "winOut",    style = "slide" },
    { enabled = true, leaf = "specialWorkspace", speed = 2, bezier = "default",   style = "slidefadevert -90%" },
}

for _, anim in ipairs(animations) do
    hl.animation(anim)
end

-- 4. Layer rules
-- Blur obelisk surfaces + their popups (blur_popups; Hyprland needs it, niri
-- doesn't). ignore_alpha skips transparent corners, keeps the glass body.
for _, namespace in ipairs({ "^obelisk-.*", "^polkit-dialog$" }) do
    hl.layer_rule({
        match        = { namespace = namespace },
        blur         = true,
        blur_popups  = true,
        ignore_alpha = 0.1,
    })
end
