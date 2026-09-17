-- Devices
hl.config({
    input = {
        kb_layout = "us,eg",
        kb_options = "grp:alt_shift_toggle,lv3:ralt_alt",
        numlock_by_default = true,
        touchpad = {
            natural_scroll = true,
        },
    },
    gestures = {
        workspace_swipe_distance = 700,
    },
    -- Let input wake a blanked display on its own. Without these, a dispatched `dpms off` is undone
    -- only by another dispatch, so a shell that dies while blanked leaves a black screen.
    misc = {
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
    },
})

-- Gestures
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "vertical", action = "special", workspace_name = "terminal" })
