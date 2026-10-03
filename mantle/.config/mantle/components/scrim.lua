local theme = require("config.theme")
local card_motion = require("components.card_motion")
-- No `showing` keeps the scrim static and preserves the caller's animation.
return function(showing, opts)
    opts = opts or {}
    opts.width, opts.height, opts.background = "fill", "fill", theme.SCRIM
    if showing then
        card_motion(opts, showing, { scale = false, y = 0 })
    end
    return rect(opts)
end
