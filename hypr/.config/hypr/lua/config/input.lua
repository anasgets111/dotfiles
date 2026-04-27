local M = {}

function M.apply()
  hl.config({
    input = {
      kb_layout = "us,eg",
      kb_options = "grp:alt_shift_toggle,lv3:ralt_alt",
      numlock_by_default = true,
      follow_mouse = 1,
      touchpad = {
        natural_scroll = true,
        disable_while_typing = true,
      },
    },
    gestures = {
      workspace_swipe_invert = true,
      workspace_swipe_distance = 700,
    },
  })

  hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
  hl.gesture({ fingers = 3, direction = "vertical", action = "special", arg = "terminal" })
end

return M
