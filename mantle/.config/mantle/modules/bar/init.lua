local theme = require("config.theme")
local left = require("modules.bar.left_side")
local center = require("modules.bar.center_side")
local right = require("modules.bar.right_side")

-- Three zones: two `Fill` sides share spare space equally, while each side uses its own `align_h`.
-- That keeps the centre's midpoint at the bar's midpoint.
--
-- `scene.rs` sizes `Fill` from the siblings' remainder rather than the whole parent.
--
-- Power, updates, keyboard, battery, launcher and workspaces left; media or the focused title
-- centre; status, tray and clock right. Registered
-- `StatusNotifierItem`s and the independently growing workspace strip occupy opposite sides.
--
-- `row` still does not shrink children to fit siblings, so an overfull left zone paints past its
-- edge. The budget follows content.
--
-- `GLASS_SURFACE` is half-alpha, so the bar composites over the wallpaper; an opaque ground reads
-- as a black strip with boxes instead of glass.
--
-- No vertical padding: a 31px item in a 38px bar already leaves 3.5px each side. Horizontal
-- padding is `spacing.md`.
return row {
    width = "Fill",
    height = theme.bar_height,
    background = theme.GLASS_SURFACE,
    blur = true,
    padding = { left = theme.spacing.md, right = theme.spacing.md },
    children = { left, center, right },
}
