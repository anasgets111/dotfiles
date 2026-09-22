-- One surface and one `kind` signal for every bar panel, so mutual exclusion cannot be got wrong.
--
-- A layer surface, not a popup: the catcher handles click-outside itself, so it knows which panel
-- closed and resolves `ui_state.toggle_panel`'s ambiguity, switching panels takes one click, and no
-- grab serial is armed. The cost is the clamp below, which `constraint_adjustment` used to do.
local theme = require("config.theme")
local util = require("lib.util")
local panel_card = require("components.panel_card")
local ui_state = require("lib.ui_state")
local bar = require("modules.bar").indicator

local power_menu = require("modules.bar.panels.power_menu")
local network_panel = require("modules.bar.panels.network_panel")
local bluetooth_panel = require("modules.bar.panels.bluetooth_panel")
local notification_history = require("modules.bar.panels.notification_history")
local update_panel = require("modules.bar.panels.update_panel")
local audio_panel = require("modules.bar.panels.audio_panel")
local media_panel = require("modules.bar.panels.media_panel")
local tray_menu = require("modules.bar.panels.tray_menu")
local screen_recorder_panel = require("modules.bar.panels.screen_recorder_panel")

local panels = { power_menu, network_panel, bluetooth_panel, notification_history, update_panel, audio_panel,
    media_panel, tray_menu, screen_recorder_panel }

-- Only the matching `kind` is a child: a hidden sibling would be frozen, not dropped. `geometry`
-- keeps a gone section's last rect, so a reveal knows its height; one never shown reads zero.
local sections = {}
local section_rects = {}
for _, panel in ipairs(panels) do
    local rect = geometry("panel-section-" .. panel.kind)
    local panel_hover = panel.kind == media_panel.kind and hover("media_panel") or nil
    table.insert(section_rects, rect)
    sections[panel.kind] = column {
        width = "Fill",
        spacing = panel.spacing or theme.spacing.xs,
        geometry = rect,
        hover = panel_hover,
        on_hover = panel_hover and function(is_hovered)
            ui_state.set_media_hover("panel", is_hovered)
        end or nil,
        children = panel.body,
    }
end
local shown_section = ui_state.panel_kind:map(function(kind)
    return { sections[kind] }
end)

-- Shared width except where content dictates: a list, two version columns, slider length, artwork.
local PANEL_WIDTHS = {
    [notification_history.kind] = theme.notification_panel_width,
    [update_panel.kind] = theme.update_panel_width,
    [audio_panel.kind] = theme.audio_panel_width,
    [media_panel.kind] = theme.media_panel_width,
    [tray_menu.kind] = theme.tray_menu_width,
}

local card_width = ui_state.panel_kind:map(function(kind)
    return PANEL_WIDTHS[kind] or theme.panel_width
end)

-- The inverted corners joining the card to the bar.
local CORNER = math.min(theme.radius.md * 3, theme.bar_height)

-- `popup_anchor` is the indicator's rect in this surface's coordinates, so centring needs no
-- translation. The hand-written clamp matters near the clock and tray, where a centred card would
-- otherwise run off the edge. `screens[1]` guesses the head like `theme.main_screen`, and follows
-- the signal so a resolution change moves the clamp; an empty list clamps only at zero.
local card_x = computed({ ui_state.popup_anchor, mantle.screens, card_width }, function(anchor, screens, width)
    local anchor_x = (anchor and anchor.x) or 0
    local anchor_width = (anchor and anchor.width) or 0
    local x = anchor_x + anchor_width / 2 - width / 2
    local screen = screens and screens[1]
    if screen and screen.width then
        x = math.min(x, screen.width - width - theme.spacing.sm - CORNER)
        x = math.max(x, theme.spacing.sm + CORNER)
    end
    return math.floor(math.max(0, x))
end)

-- The card drops from behind the bar and retracts the same way, `linger` keeping it for the exit.
-- Travel is the shown section's measured height plus chrome, so a switch while closed retracts to
-- the *next* card's height; an unmeasured section falls back to the slide distance and snaps once.
-- Switching while open morphs in place, animating `width` and `height` instead.
local CARD_PADDING = theme.spacing.md
-- The card starts `radius.md` above the bar's bottom edge, which cuts its top corners square.
local CARD_CHROME = CARD_PADDING * 2 + theme.radius.md
local card_height = computed({ ui_state.panel_kind, table.unpack(section_rects) }, function(kind, ...)
    for index, panel in ipairs(panels) do
        if panel.kind == kind then
            local height = select(index, ...).height
            return height > 0 and height + CARD_CHROME or nil
        end
    end
    return nil
end)
local hidden_top = card_height:map(function(height)
    return height and -(height + theme.panel_gap) or -theme.panel_slide
end)
local card_margin = computed({ hidden_top, ui_state.panel_open }, function(hidden, open)
    return { top = open and -theme.radius.md or hidden }
end)

-- A scooped box whose bottom corner point is this piece's, cut to one quadrant. `+ 2` keeps the
-- box's other scoops off the visible quadrant. Blur is a second scoop 2px wider, so the region's
-- pixel staircase then sits under the tint, not on the antialiased arc.
local function inverted_corner(corner, glass_on_right, margin)
    local function scoop(radius, glass)
        local size = radius * 2 + 2
        return rect {
            width = size,
            height = size,
            margin = { left = glass_on_right and 0 or corner - size, top = corner - size },
            radius = radius,
            corner_shape = "Scoop",
            background = glass and theme.GLASS_SURFACE or nil,
            blur = not glass,
        }
    end
    return rect {
        width = corner,
        height = corner,
        margin = margin,
        children = { scoop(corner, true), scoop(corner + 2, false) },
    }
end
-- Bar and panels share one surface: niri blurs each surface on its own, so a card on a second
-- surface met the bar at a visible seam.
local shown = util.linger(ui_state.panel_open, theme.animation_ms)

local card_animate = computed({ hidden_top, shown }, function(hidden, visible)
    if not visible then
        return {}
    end
    return { margin = { duration = theme.animation_ms, easing = "OutQuad", from = { top = hidden } } }
end)

return panel {
    id = "bar",
    -- Under `Overlay`, so notifications and OSD still draw and click over an open panel.
    layer = "Top",
    -- Three edges and a pixel zone: anchored to all four, a surface reserves nothing.
    anchor = { top = true, left = true, right = true },
    exclusive = theme.bar_height,
    width = "Fill",
    -- Screen-tall: Hyprland animates a layer resize by stretching the old buffer.
    height = "100%",
    -- The credential sheet asks for a name, then a password, and `ui_state.credential_step` covers
    -- both including the wait between them: `"None"` in that gap would hand the keyboard back.
    -- `"Exclusive"` because either field must be typable without a click, the engine arming the
    -- scope's sole field on compositor focus. History's reply field needs only `"OnDemand"`, since a
    -- click there takes the keyboard and other windows give it back.
    keyboard_interactivity = computed(
        { ui_state.credential_step, ui_state.panel_showing("notifications") },
        function(step, showing_notifications)
            -- The sheet stays `Exclusive`: this panel's click raised it and the catcher ends it.
            if step ~= "" then
                return "Exclusive"
            end
            return showing_notifications and "OnDemand" or "None"
        end
    ),
    -- Input follows drawn nodes, so a closed panel leaves only the bar and its corners clickable.
    child = rect {
        width = "Fill",
        height = "Fill",
        children = {
            -- Screen-edge corners, under the catcher so a click on one closes.
            row {
                width = "Fill",
                margin = { top = theme.bar_height },
                children = {
                    inverted_corner(theme.radius.md, false),
                    rect { width = "Fill" },
                    inverted_corner(theme.radius.md, true),
                },
            },
            -- Starts at the bar's bottom edge, which cuts the card while it slides. Hit-testing
            -- stops at the first child holding the point, so the catcher lives in here.
            rect {
                width = "Fill",
                height = "Fill",
                margin = { top = theme.bar_height },
                children = ui_state.panel_instance:map(function(instance)
                    return {
                        -- `close_panel`, not a local handler: an outside click and a second
                        -- indicator click are the same edge, and it also answers pending passwords.
                        button {
                            width = "Fill",
                            height = "Fill",
                            cursor = "default",
                            -- Not lingering: clicks reach windows while the card retracts.
                            visible = ui_state.panel_open,
                            on_click = ui_state.close_panel,
                        },
                        -- The column's margin is the horizontal placement, the row's the vertical: a
                        -- tween carries a whole edge table, so one node holding both would slide the
                        -- card sideways from the last indicator.
                        column {
                            id = "panel-" .. tostring(instance),
                            margin = card_x:map(function(x)
                                return { left = x - CORNER }
                            end),
                            animate = { margin = { duration = theme.animation_ms, easing = "OutCubic" } },
                            children = {
                                row {
                                    margin = card_margin,
                                    animate = card_animate,
                                    children = {
                                        row {
                                            visible = shown,
                                            children = {
                                                inverted_corner(CORNER, true, { top = theme.radius.md }),
                                                panel_card(shown_section, {
                                                    width = card_width,
                                                    height = card_height,
                                                    animate = {
                                                        width = { duration = theme.animation_ms, easing = "OutCubic" },
                                                        height = { duration = theme.animation_ms, easing = "OutCubic" },
                                                    },
                                                    background = theme.GLASS_SURFACE,
                                                    blur = true,
                                                    padding = {
                                                        top = CARD_PADDING + theme.radius.md,
                                                        right = CARD_PADDING,
                                                        bottom = CARD_PADDING,
                                                        left = CARD_PADDING,
                                                    },
                                                }),
                                                inverted_corner(CORNER, false, { top = theme.radius.md }),
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    }
                end),
            },
            -- Last, so it paints over the catcher and hit-testing reaches its indicators first.
            bar,
        },
    },
}
