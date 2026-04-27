local M = {}

function M.apply()
  hl.config({
    general = {
      gaps_in = 1,
      gaps_out = 4,
      border_size = 4,
      allow_tearing = true,
      col = {
        active_border = {
          colors = {
            "rgba(8839b5aa)",
            "rgba(0,0,0,0)",
            "rgba(f5c2e7ee)",
            "rgba(0,0,0,0)",
            "rgba(8839b5aa)",
          },
          angle = 35,
        },
        inactive_border = "rgba(aaaaaaaa)",
      },
      resize_on_border = true,
      layout = "twindle",
      snap = {
        enabled = true,
        window_gap = 11,
        monitor_gap = 11,
        border_overlap = false,
      },
    },
    render = {
      cm_auto_hdr = true,
      cm_fs_passthrough = true,
      direct_scanout = 2,
    },
    decoration = {
      rounding = 14,
      active_opacity = 0.92,
      inactive_opacity = 0.92,
      shadow = {
        enabled = false,
      },
      blur = {
        enabled = true,
        size = 5,
        passes = 3,
        new_optimizations = true,
      },
    },
    animations = {
      enabled = true,
    },
    dwindle = {
      pseudotile = true,
      preserve_split = true,
      special_scale_factor = 0.85,
    },
    master = {
      new_status = "master",
      special_scale_factor = 0.85,
    },
    scrolling = {
      follow_focus = true,
      follow_min_visible = 0.05,
    },
    misc = {
      force_default_wallpaper = 0,
      session_lock_xray = true,
      disable_hyprland_logo = true,
      disable_splash_rendering = true,
      middle_click_paste = false,
      enable_swallow = true,
      allow_session_lock_restore = true,
    },
  })

  hl.curve("wind", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
  hl.curve("winIn", { type = "bezier", points = { { 0.1, 1.1 }, { 0.1, 1.1 } } })
  hl.curve("winOut", { type = "bezier", points = { { 0.3, -0.3 }, { 0, 1 } } })
  hl.curve("liner", { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })
  hl.curve("overshot", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
  hl.curve("smoothOut", { type = "bezier", points = { { 0.5, 0 }, { 0.99, 0.99 } } })
  hl.curve("smoothIn", { type = "bezier", points = { { 0.5, -0.5 }, { 0.68, 1.5 } } })

  hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "wind", style = "slide" })
  hl.animation({ leaf = "windowsIn", enabled = true, speed = 2, bezier = "winIn", style = "slide" })
  hl.animation({ leaf = "windowsOut", enabled = true, speed = 1, bezier = "smoothOut", style = "slide" })
  hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "wind", style = "slide" })

  hl.animation({ leaf = "border", enabled = true, speed = 1, bezier = "liner" })
  hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "smoothOut" })

  hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "overshot" })
  hl.animation({ leaf = "workspacesIn", enabled = true, speed = 2, bezier = "winIn", style = "slide" })
  hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2, bezier = "winOut", style = "slide" })
  hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2, bezier = "default", style = "slidefadevert -90%" })
end

return M
