-- Autofocus search, Tab for the mode rail, arrows and Enter. A layer surface, not an `xdg_toplevel`,
-- which niri would tile beside other windows.
--
-- `selected_id` holds the last key or hover choice; `effective_selected` keeps it while visible
-- and falls back to the first. Mouse and arrows move the same selection.
--
-- Search mode shows one row of app tiles above the first provider to claim the query: currency,
-- calculator, then web. Apps mode is the whole grid. Providers return plain tables because a
-- `computed` cannot carry a closure.
-- Ranking, the web provider and the mode rail live in `launcher/`.
local theme = require("config.theme")
local icons = require("config.icons")
local cell = require("components.cell")
local glyph = require("components.glyph")
local section_header = require("components.section_header")
local util = require("lib.util")
local store = require("lib.store")
local ui_state = require("lib.ui_state")
local modal = require("components.modal")
local app_provider = require("modules.global.launcher.apps")
local calc = require("modules.global.launcher.calc")
local currency = require("modules.global.launcher.currency")
local mode_rail = require("modules.global.launcher.rail")
local web_provider = require("modules.global.launcher.web")

---What a provider returns when it claims a query, and the whole of what the special row draws. One
---table carries these fields because a `computed` can hold it.
---@class LauncherRow
---@field kind "currency"|"calc"|"web" What `activate` does with `payload`: copy it, or open it.
---@field hint string
---@field icon string
---@field icon_is_text? boolean The glyph needs the body family, not the Nerd Font one.
---@field title string
---@field subtitle string
---@field payload string

local MODES = {
    { id = "apps",       label = "Apps",       icon = icons.launcher },
    { id = "wallpapers", label = "Wallpapers", icon = icons.wallpaper },
    { id = "calc",       label = "Calculator", icon = icons.calc },
    { id = "web",        label = "Web",        icon = icons.web },
}
local PROMPTS = { search = "Search", apps = "Search apps", calc = "Enter an expression", web = "Search the web" }
-- Special-row id in `selected_id`, not a desktop-file id; desktop-file ids never start with a space.
local SPECIAL = " special"

-- The Quickshell reference's timings.
local WEB_MS = 340
local PANEL_MS = 210

local SIZE = theme.launcher_search_height
local SEARCH_PADDING = theme.spacing.xl
local RESULTS_PADDING = theme.spacing.sm
local COLUMNS = math.floor((theme.launcher_width - 2 * RESULTS_PADDING) / theme.launcher_tile_width)
local VISIBLE_ROWS = 4
local STEPS = { left = -1, right = 1, up = -COLUMNS, down = COLUMNS }
local SCROLL = scroll("launcher_grid")

local query = state("launcher_query", "")
local selected_id = state("launcher_selected", "")
local mode = state("launcher_mode", "search")
local rail = state("launcher_rail", false)
local rail_focus = state("launcher_rail_focus", 1)
local search_focus = focus_target("launcher_search")
local web = mode:map(function(current)
    return current == "web"
end)
local on_rail = mode_rail.binder(rail)

-- The web pill's press: a dip over 25% of the run and a rise over the next 37%, mirrored on exit.
local web_moving = pulse(web, WEB_MS)

-- Durations are whole milliseconds.
local function web_ms(fraction)
    return math.floor(fraction * WEB_MS + 0.5)
end

local function press(rest, pressed, entering)
    local ease = "InOutQuad"
    return {
        duration = WEB_MS,
        keyframes = {
            rest,
            { value = rest,    duration = entering and 0 or web_ms(0.38) },
            { value = pressed, duration = web_ms(entering and 0.25 or 0.37), easing = ease },
            { value = rest,    duration = web_ms(entering and 0.37 or 0.25), easing = ease },
        },
    }
end
local press_runs = {}
for _, entering in ipairs({ true, false }) do
    local lift = theme.launcher_shadow_y * 0.43
    press_runs[entering] = {
        scale = press({ x = 1, y = 1 }, { x = 0.985, y = 0.945 }, entering),
        shadow_blur = press(theme.launcher_shadow_blur, theme.launcher_shadow_blur * 0.72, entering),
        shadow_offset = press({ x = 0, y = theme.launcher_shadow_y }, { x = 0, y = theme.launcher_shadow_y - lift },
            entering),
    }
end

-- The pill's reveal runs over 36-80% of the web transition, mirrored on exit.
local pill_motion = web:map(function(on)
    local window = { duration = web_ms(0.44), delay = web_ms(on and 0.36 or 0.2), easing = "InOutQuad" }
    return { width = window, opacity = window, scale = window }
end)

local trimmed = query:map(util.trim)
local matches = computed({ mantle.applications, query, store.app_usage }, app_provider.rank)
local results = computed({ matches, mode, trimmed }, function(found, current, text)
    if current == "apps" then
        return found.apps
    end
    if current ~= "search" or text == "" then
        return {}
    end
    return { table.unpack(found.apps, 1, math.min(#found.apps, COLUMNS)) }
end)
local rows = results:map(function(apps)
    return util.chunk(apps, COLUMNS)
end)

-- The first provider that claims wins; web takes every other query.
local special = computed(
    { trimmed, matches, store.currency_rates, store.currency_updated_at, util.today, mode },
    function(text, found, rates, updated_at, today, current)
        if text == "" or current == "apps" then
            return nil
        end
        if current == "calc" then
            return calc.claims(text)
        end
        if current == "web" then
            return web_provider.claims(text)
        end
        -- A bare currency code yields to a good app match; a subsequence is weak.
        local weak = #found.apps == 0 or found.best < 2000
        return currency.claims(text, rates, updated_at, weak, today) or calc.claims(text) or web_provider.claims(text)
    end
)
-- Web mode draws no panel, as the reference; Enter still opens its row.
local special_shown = computed({ special, web }, function(row, on)
    return row ~= nil and not on
end)

-- `selected_id` when its row shows, else the first. Calculator and currency answers lead; a web
-- fallback trails the apps.
local effective_selected = computed({ selected_id, results, special }, function(id, apps, row)
    if id == SPECIAL and row then
        return id
    end
    if util.find(apps, function(app) return app.id == id end) then
        return id
    end
    if row and (row.kind ~= "web" or #apps == 0) then
        return SPECIAL
    end
    return apps[1] and apps[1].id or ""
end)

-- Left and right stay on their row; down from the last row reaches the special row.
local function move(key)
    local apps = results:get()
    local id = effective_selected:get()
    local current = #apps + 1
    for i, app in ipairs(apps) do
        if app.id == id then
            current = i
        end
    end
    local target = current + STEPS[key]
    if id == SPECIAL then
        target = key == "up" and #apps - (#apps - 1) % COLUMNS or 0
    elseif (key == "left" or key == "right") and math.ceil(target / COLUMNS) ~= math.ceil(current / COLUMNS) then
        return
    elseif key == "down" and target > #apps then
        if special_shown:get() then
            return selected_id:set(SPECIAL)
        end
        target = math.ceil(current / COLUMNS) < math.ceil(#apps / COLUMNS) and #apps or current
    end
    if apps[target] then
        selected_id:set(apps[target].id)
        SCROLL:reveal(math.ceil(target / COLUMNS))
    end
end

-- The query and selection reset themselves: `autofocus` re-arms the field empty on the next open.
ui_state.on_modal_close("launcher", function()
    mode:set("search")
    rail:set(false)
end)

local function close()
    ui_state.close_modal("launcher")
end

local function choose_mode(target)
    rail:set(false)
    if target == "wallpapers" then
        return ui_state.active_modal:set("wallpaper_picker")
    end
    mode:set(target)
    selected_id:set("")
    search_focus:request()
end

local function activate()
    if rail:get() then
        return choose_mode(MODES[rail_focus:get()].id)
    end
    local id = effective_selected:get()
    if id == "" then
        return
    end
    if id == SPECIAL then
        local row = special:get()
        if not row then
            return
        end
        if row.kind == "web" then
            mantle.applications:open_url(row.payload)
        else
            -- A Wayland selection lives as long as its owner, and a `process.run` child is
            -- reaped with its Renderer, taking the clipboard with it.
            process.detach("wl-copy", { row.payload })
        end
    else
        mantle.applications:launch(id)
        local usage = store.app_usage:get() or {}
        local count = usage[id] and usage[id].count or 0
        store:set("app_usage", util.with(usage, id, { count = count + 1, last = os.time() }))
    end
    close()
end

-- Enter and leave count as crossings, so the selection follows a pointer already in place.
local function selectable(id, node)
    node.background = effective_selected:map(function(selected)
        return selected == id and theme.ACCENT_LIGHT or theme.CLEAR
    end)
    node.animate = { background = theme.animation_fast_ms }
    node.on_hover = function(inside)
        if inside then
            selected_id:set(id)
        end
    end
    node.on_click = function(_, mouse_button)
        if mouse_button == "left" then
            selected_id:set(id)
            activate()
        end
    end
    return node
end

---@param app AppSummary
local function app_tile(app)
    return column(selectable(app.id, {
        hover = hover("launcher-app-" .. app.id),
        width = theme.launcher_tile_width,
        height = theme.launcher_tile_height,
        radius = theme.radius.md,
        align_v = "Center",
        spacing = theme.spacing.xs,
        padding = theme.spacing.xs,
        children = {
            icon {
                name = app.icon or "application-x-executable",
                size = theme.icon.xl,
                align_h = "Center",
                scale = effective_selected:map(function(selected)
                    return selected == app.id and theme.selected_scale or 1
                end),
                animate = { scale = { duration = theme.animation_fast_ms, easing = "OutCubic" } },
            },
            cell(app.name, theme.FG, theme.font.md, { width = "Fill", align = "Center" }),
        },
    }))
end

local grid = list {
    width = "Fill",
    height = rows:map(function(chunks)
        return math.min(#chunks, VISIBLE_ROWS) * theme.launcher_tile_height
    end),
    scroll = SCROLL,
    source = rows,
    itemfn = function(apps)
        local tiles = {}
        for i, app in ipairs(apps) do
            tiles[i] = app_tile(app)
        end
        return row { width = "Fill", children = tiles }
    end,
    key = function(apps)
        local ids = {}
        for i, app in ipairs(apps) do
            ids[i] = app.id
        end
        return table.concat(ids, "\n")
    end,
}

local function special_field(key)
    return special:map(function(row)
        return row and row[key] or ""
    end)
end

-- Leading glyph, title over subtitle, then the action hint.
local special_row = row(selectable(SPECIAL, {
    hover = hover("launcher-special"),
    width = "Fill",
    height = theme.control.xl,
    radius = theme.radius.md,
    visible = special_shown,
    spacing = theme.spacing.sm,
    padding = { left = theme.spacing.sm, right = theme.spacing.sm },
    children = {
        -- One node, the family chosen by signal: under the Icon family a regional indicator never
        -- reaches the colour emoji face at the end of the fallback chain.
        cell(special_field("icon"), theme.FG, theme.icon.xl, {
            align_v = "Center",
            font = special:map(function(row)
                return (row and row.icon_is_text) and "Body" or "Icon"
            end),
        }),
        column {
            width = "Fill",
            align_v = "Center",
            children = {
                cell(special_field("title"), theme.FG, theme.font.lg, { width = "Fill" }),
                cell(special_field("subtitle"), theme.DIM, theme.font.sm, { width = "Fill" }),
            },
        },
        cell(special_field("hint"), theme.DIM, theme.font.sm, { align_v = "Center" }),
    },
}))

local body_height = computed({ rows, special_shown }, function(chunks, has_row)
    local height = #chunks > 0 and theme.section_header_height + math.min(#chunks, VISIBLE_ROWS) *
        theme.launcher_tile_height or 0
    if has_row then
        height = height + (height > 0 and theme.spacing.xs or 0) + theme.control.xl
    end
    return height > 0 and height + 2 * RESULTS_PADDING or 0
end)
local expanded = body_height:map(function(height)
    return height > 0
end)
local card_height = body_height:map(function(height)
    return SIZE + (height > 0 and theme.spacing.md + height or 0)
end)

local function tip(label, hovered, x)
    return rect {
        width = theme.launcher_tooltip_width,
        height = theme.control.xs,
        translate = util.lift(x, function(left)
            return { x = left, y = -theme.control.xs - theme.spacing.sm }
        end),
        opacity = util.choose(hovered, 1, 0),
        animate = { opacity = theme.animation_fast_ms },
        radius = theme.radius.md,
        background = theme.ELEVATED,
        children = { cell(label, theme.FG, theme.font.sm, { align = "Center", align_v = "Center" }) },
    }
end

local engine_label = geometry("launcher_engine_label")
local pill_width = engine_label:map(function(box)
    return box.width + theme.spacing.md + theme.control.sm
end)
local return_hover = hover("launcher-return")
local pill_close_hover = hover("launcher-pill-close")

local search = on_rail(row {
    height = SIZE,
    clip = "None",
    align_v = "Center",
    spacing = theme.spacing.sm,
    padding = { left = SEARCH_PADDING, right = SEARCH_PADDING },
    children = {
        rect {
            hover = return_hover,
            width = theme.icon.lg,
            height = theme.icon.lg,
            align_v = "Center",
            radius = theme.icon.lg / 2,
            background = util.choose(return_hover, theme.ACCENT_SUBTLE, theme.CLEAR),
            animate = { background = theme.animation_fast_ms },
            on_click = function()
                choose_mode("search")
            end,
            children = { glyph(icons.search, theme.DIM, theme.icon.lg, { align = "Center", align_v = "Center" }) },
        },
        rect {
            width = computed({ web, pill_width }, function(on, width)
                return on and width or 0
            end),
            height = theme.control.md,
            align_v = "Center",
            radius = theme.control.md / 2,
            background = theme.ACCENT_LIGHT,
            clip = "Rounded",
            opacity = util.choose(web, 1, 0),
            scale = util.choose(web, 1, 0.92),
            animate = pill_motion,
            children = { row {
                width = "Fill",
                height = "Fill",
                align_v = "Center",
                padding = { left = theme.spacing.md },
                children = {
                    cell(web_provider.ENGINE, theme.FG, theme.font.md, { width = "Fill", align_v = "Center" }),
                    rect {
                        hover = pill_close_hover,
                        width = theme.control.sm,
                        height = "Fill",
                        on_click = function()
                            choose_mode("search")
                        end,
                        children = { glyph(icons.close, theme.DIM, theme.icon.sm, { align = "Center", align_v = "Center" }) },
                    },
                },
            } },
        },
        textfield {
            id = "launcher_input",
            focus_target = search_focus,
            width = "Fill",
            height = "Fill",
            autofocus = true,
            font_size = theme.font.xl,
            foreground = theme.FG,
            placeholder = computed({ mode, rail, hover("launcher-mode-1"), hover("launcher-mode-2"),
                hover("launcher-mode-3"), hover("launcher-mode-4") }, function(current, open, apps, walls, calc, web)
                return open and (apps and MODES[1].label or walls and MODES[2].label or calc and MODES[3].label
                    or web and MODES[4].label) or PROMPTS[current]
            end),
            on_change = function(text)
                query:set(text)
                selected_id:set("")
                if text ~= "" then
                    rail:set(false)
                end
            end,
            on_submit = activate,
            -- Escape closes the rail, leaves a mode, then closes; the engine clears text first and
            -- drops focus on every Escape, so each stage that stays takes it back.
            on_cancel = function(cleared)
                if rail:get() then
                    rail:set(false)
                elseif not cleared and mode:get() ~= "search" then
                    mode:set("search")
                elseif not cleared then
                    return close()
                end
                search_focus:request()
            end,
            on_navigate = function(key)
                local step = (key == "backtab" or key == "left") and -1 or 1
                if rail:get() and (key == "left" or key == "right" or key == "tab" or key == "backtab") then
                    rail_focus:set((rail_focus:get() - 1 + step) % #MODES + 1)
                elseif key == "tab" or key == "backtab" then
                    rail_focus:set(1)
                    for index, entry in ipairs(MODES) do
                        if entry.id == mode:get() then
                            rail_focus:set(index)
                        end
                    end
                    rail:set(true)
                elseif STEPS[key] then
                    move(key)
                end
            end,
        },
    },
}, { width = mode_rail.width })

local search_layers = {
    on_rail(rect { height = "Fill", radius = SIZE / 2, behind_blur = true }, { width = mode_rail.width }),
    shader {
        -- Leave room for the last circle's spring overshoot.
        width = theme.launcher_width + theme.spacing.md,
        height = "Fill",
        source = mantle.config_dir .. "/shaders/launcher_sheen.frag",
        params = {
            fill = theme.rgba(theme.LAUNCHER_FILL),
            sheen = theme.rgba(theme.GLASS_BORDER_HOVER),
            shade = theme.rgba(theme.LAUNCHER_SHADOW),
            edge_width = theme.border_width,
            gap = theme.launcher_mode_gap,
            layout_width = theme.launcher_width,
        },
        progress = util.choose(rail, 1, 0),
        shadow_color = theme.LAUNCHER_SHADOW,
        shadow_blur = theme.launcher_shadow_blur,
        shadow_offset = { x = 0, y = theme.launcher_shadow_y },
        animate = computed({ web_moving, web }, function(moving, on)
            local run = { progress = { duration = mode_rail.MS, easing = "Linear" } }
            if moving then
                run.shadow_blur, run.shadow_offset = press_runs[on].shadow_blur, press_runs[on].shadow_offset
            end
            return run
        end),
    },
    search,
    -- Measures the engine name for the pill, which animates a number, not a content size.
    text { content = web_provider.ENGINE, font_size = theme.font.md, geometry = engine_label, opacity = 0 },
    tip("Search", return_hover, SEARCH_PADDING + (theme.icon.lg - theme.launcher_tooltip_width) / 2),
    tip("Return to search", pill_close_hover, pill_width:map(function(width)
        return SEARCH_PADDING + theme.icon.lg + theme.spacing.sm + width
            - (theme.control.sm + theme.launcher_tooltip_width) / 2
    end)),
}
for _, node in ipairs(mode_rail.buttons({
    open = rail,
    focus = rail_focus,
    mode = mode,
    modes = MODES,
    choose = choose_mode,
    bind = on_rail,
})) do
    search_layers[#search_layers + 1] = node
end

return modal({
    kind = "launcher",
    reset_on_close = { SCROLL },
    card = column {
        width = theme.launcher_width,
        height = card_height,
        clip = "None",
        align_h = "Center",
        align_v = "Start",
        margin = { top = theme.launcher_top_margin },
        spacing = theme.spacing.md,
        children = {
            rect {
                width = "Fill",
                height = SIZE,
                clip = "None",
                animate = computed({ web_moving, web }, function(moving, on)
                    return moving and { scale = press_runs[on].scale } or {}
                end),
                children = search_layers,
            },
            column {
                width = "Fill",
                height = body_height,
                visible = util.linger(expanded, PANEL_MS),
                opacity = util.choose(expanded, 1, 0),
                animate = {
                    height = { duration = PANEL_MS, easing = "OutCubic" },
                    opacity = { duration = PANEL_MS, easing = "OutCubic", from = 0 },
                },
                spacing = theme.spacing.xs,
                padding = RESULTS_PADDING,
                background = theme.LAUNCHER_RESULTS,
                behind_blur = expanded,
                radius = theme.launcher_radius,
                clip = "Rounded",
                border_width = theme.border_width,
                border_color = theme.GLASS_BORDER,
                shadow_color = theme.LAUNCHER_SHADOW,
                shadow_blur = theme.launcher_shadow_blur,
                shadow_offset = { x = 0, y = theme.launcher_shadow_y },
                children = {
                    column {
                        width = "Fill",
                        visible = rows:map(function(chunks)
                            return #chunks > 0
                        end),
                        children = { section_header("Apps"), grid },
                    },
                    special_row,
                },
            },
        },
    },
})
