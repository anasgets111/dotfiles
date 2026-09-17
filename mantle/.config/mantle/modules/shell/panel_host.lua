-- One surface displays every bar panel.
--
-- One screen slot shows the last-requested panel. Five surfaces would need manual mutual exclusion;
-- one `kind` signal makes that impossible to get wrong.
--
-- ## `panel`, not `popup`
--
-- A layer surface has no grab, so `keyboard_interactivity` binds only to the fact needing keys and
-- the bar never asks, following `password_ssid`.
--
-- Three things return, one is paid for:
--
--   * The catcher handles click-outside instead of compositor `popup_done`, so it knows which panel
--     closed and resolves `lib/ui_state.lua`'s `toggle_panel` ambiguity.
--   * Switching panels is one click; no grab needs breaking and re-arming.
--   * `linger` shows and hides the card, so no armed grab serial is needed
--   * Cost: popups had `constraint_adjustment`; layers do not, so the clamp is hand-written
--     `"SlideX"`.
--
-- ## Card height follows its panel
--
-- The card has no `height`; each list owns `max_height` and scrolls at the same cap.
local theme = require("config.theme")
local util = require("lib.util")
local panel_card = require("components.panel_card")
local ui_state = require("lib.ui_state")
local bar = require("modules.bar")

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

-- Only the matching `kind` is a child: a hidden sibling is frozen, not dropped. A
-- section's `geometry` keeps its last rect while it is gone, so a reveal knows its
-- height; a section never shown reads zero.
local sections = {}
local section_rects = {}
for _, panel in ipairs(panels) do
    local rect = geometry("panel-section-" .. panel.kind)
    table.insert(section_rects, rect)
    sections[panel.kind] = column { width = "Fill", spacing = theme.spacing.xs, geometry = rect, children = panel.body }
end
local shown_section = ui_state.panel_kind:map(function(kind)
    return { sections[kind] }
end)

-- Shared width except history, updates, audio, and media. Those use their own widths because
-- history is a list, package rows need two version strings, audio sliders need length, and media
-- puts artwork beside the track rather than above it.
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

-- `popup_anchor` is the indicator's `on_click` rect in this surface's
-- coordinates, so `x` needs no translation. Center under the indicator, then clamp
-- within `spacing.sm` of either edge. Left-edge anchoring made a card under a
-- button read as belonging to its right neighbor. The hand-written `"SlideX"` matters near the
-- clock/tray: a 340px card centered on a 1920px output would otherwise run off by half its width.
--
-- No `"FlipY"`: this starts below the bar. `screens[1]` on a hotplugged second head is the same
-- guess as `config/theme.lua`'s `main_screen`. This follows the signal, so resolution changes move
-- the clamp instead of stranding boot values. Empty `mantle.screens` (first evaluation) clamps
-- only at zero.
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

-- The card drops from just above the bar's bottom edge and retracts the same way while `linger`
-- keeps it in the tree for exit. No fade: only `y` moves, and the wrapper below the
-- bar's `clip` cuts the card as it moves off-screen. Travel is the shown section's measured
-- height plus card chrome, read from the section so a closed switch retracts to the *next* card's
-- height instead starting a taller card part-visible. An unlaid section reads zero and falls back
-- to the tallest card, so its first open in a session drops from further up.
--
-- Switching kinds while open does not retract: the card morphs in place, animating `width` and
-- `height`. The card height is the shown section's measured height plus its chrome; a pass that
-- changes a measurement earns one follow-up pass, keeping the card from sitting one pass
-- behind a section that grew. An unmeasured section leaves the card content-sized, which snaps that
-- once.
--
-- `panel_card`'s default is `sm` top and bottom, `md` left and right, which left every panel's
-- first line -- the greeting, a section heading -- on the card's top edge. This uses `md` on every
-- edge.
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
-- A signal makes `from` carry the hidden position, so the first open of a kind slides rather
-- than appears (a first value is taken as it is without one).
local card_animate = hidden_top:map(function(hidden)
    return { margin = { duration = theme.animation_ms, easing = "OutQuad", from = { top = hidden } } }
end)

-- Bar and panels share one surface: niri blurs each surface on its own, so a card on a second
-- surface met the bar at a visible seam.
local shown = util.linger(ui_state.panel_open, theme.animation_ms)
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
    -- The network panel's credential sheet asks for the keyboard at every step: a name, then a
    -- password. `ui_state.credential_step` is the whole question, and `clear_network_prompts` ends
    -- the sheet on every closing edge, so it cannot leave this surface holding the keyboard.
    --
    -- Hold it across the wait between the two. `"None"` in the gap would hand the keyboard back to
    -- whatever is behind the panel for as long as the Supervisor takes to answer.
    --
    -- `"Exclusive"`, not `"OnDemand"`: both fields must be typable without a click. The engine arms
    -- a scope's *sole* `secure_submit` field and first `autofocus` plain field on compositor focus
    -- (`layout::secure_submit`, `wayland::input`); the sheet shows one at a time. The sheet is
    -- raised by a click on an already-open panel.
    --
    -- Notifications also need it: history draws the popup's always-present reply field,
    -- and niri focuses an `OnDemand` layer on a click while already on demand, not on the flip.
    -- Ask on demand only while history is shown: clicks there take the keyboard, other windows give
    -- it back, and the catcher closes the panel. Network and calendar never ask without a field.
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
    -- Input follows drawn and clickable nodes, so a closed panel leaves the
    -- bar and its corners as the only region and the rest of the screen clicks through.
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
                visible = shown,
                children = {
                    -- `close_panel` answers pending passwords, not this catcher. Outside click and
                    -- a second indicator click are the same edge; one writer keeps them in sync.
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
                        margin = card_x:map(function(x)
                            return { left = x - CORNER }
                        end),
                        children = {
                            row {
                                margin = card_margin,
                                animate = card_animate,
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
                                        -- History cards sit on this glass and do not ask again.
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
            -- Last, so it paints over the catcher and hit-testing reaches its indicators first.
            bar,
        },
    },
}
