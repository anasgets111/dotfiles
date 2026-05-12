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
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "vertical", action = "special", workspace_name = "terminal" })
