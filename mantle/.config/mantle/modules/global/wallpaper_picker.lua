-- A searchable file grid with settings beside it; a click or Enter applies to the chosen screen or
-- to all of them.
--
-- `mantle.files` follows the folder, so the grid is a `computed` and scans nothing. Tiles decode
-- `async`, which downsizes 4K files off-thread instead of holding the shell for a second on open.
-- There is no wrapping layout, so `rows` chunks into `theme.wallpaper_columns`.
local theme = require("config.theme")
local icons = require("config.icons")
local cell = require("components.cell")
local glyph = require("components.glyph")
local search_bar = require("components.search_bar")
local ui_state = require("lib.ui_state")
local modal = require("components.modal")
local wallpaper = require("lib.wallpaper")
local util = require("lib.util")
local panel_card = require("components.panel_card")
local panel_empty_state = require("components.panel_empty_state")
local panel_toggle_card = require("components.panel_toggle_card")
local section_header = require("components.section_header")
local spinner = require("components.spinner")

local SCROLL = scroll("wallpaper_grid")
local COLUMNS = theme.wallpaper_columns
-- `"all"` is the "All displays" option; no connector has that name.
local ALL = "all"
local STEPS = {
    backtab = -1,
    tab = 1,
    left = -1,
    right = 1,
    up = -COLUMNS,
    down = COLUMNS,
    page_up = -COLUMNS * 3,
    page_down = COLUMNS * 3,
}

local query = state("wallpaper_query", "")
local selected_path = state("wallpaper_selected", "")
local monitor = state("wallpaper_monitor", ALL)

-- Tile width divides the grid card's inner width across the columns, leaving no right gutter.
local card_padding = theme.spacing.lg
local grid_padding = theme.spacing.sm
local tile_gap = theme.spacing.xs
local grid_inner = theme.wallpaper_picker_width
    - 2 * card_padding
    - theme.wallpaper_sidebar_width
    - theme.spacing.md
    - 2 * grid_padding
local TILE_WIDTH = math.floor((grid_inner - (COLUMNS - 1) * tile_gap) / COLUMNS)
local TILE_HEIGHT = math.floor(TILE_WIDTH * 9 / 16)
-- The grid shows whole rows, and the card shrinks to fit them, so `reveal`'s least move lands on a
-- row edge instead of cutting the top row.
local rows_budget = theme.wallpaper_picker_height - 2 * card_padding - theme.control.xl - theme.spacing.md
    - 2 * grid_padding
local VISIBLE_ROWS = math.floor((rows_budget + tile_gap) / (TILE_HEIGHT + tile_gap))
local GRID_HEIGHT = VISIBLE_ROWS * (TILE_HEIGHT + tile_gap) - tile_gap

local trimmed = query:map(function(text)
    return util.trim(text):lower()
end)

---@return FileEntry[]
local filtered = computed({ mantle.files, trimmed }, function(files, needle)
    local folder = wallpaper.folder_in(files)
    local entries = folder and folder.entries or {}
    if needle == "" then
        return entries
    end
    local found = {}
    for _, entry in ipairs(entries) do
        if entry.name:lower():find(needle, 1, true) then
            found[#found + 1] = entry
        end
    end
    return found
end)

local rows = filtered:map(function(entries)
    local chunks = {}
    for i = 1, #entries, COLUMNS do
        chunks[#chunks + 1] = { table.unpack(entries, i, math.min(i + COLUMNS - 1, #entries)) }
    end
    return chunks
end)

-- An unplugged selection reads as "all", since `mantle.screens` has no `on_change`.
local effective_monitor = computed({ monitor, mantle.screens }, function(chosen, screens)
    for _, screen in ipairs(screens or {}) do
        if screen.name == chosen then
            return chosen
        end
    end
    return ALL
end)

local function targets_now()
    local chosen = effective_monitor:get()
    return chosen == ALL and wallpaper.outputs() or { chosen }
end

-- `read`'s answer for the targeted screens, or `""` where they disagree, so the badge and the ring
-- never pick between conflicting answers.
local function targeted(read)
    return computed({ require("lib.store").wallpapers, mantle.screens, effective_monitor },
        function(wallpapers, screens, chosen)
            local first
            for _, screen in ipairs(screens or {}) do
                if chosen == ALL or chosen == screen.name then
                    local value = read(wallpapers, screen.name)
                    if first ~= nil and value ~= first then
                        return ""
                    end
                    first = value
                end
            end
            return first or ""
        end)
end

local current_path = targeted(wallpaper.path_in)
local current_fit = targeted(wallpaper.fit_in)

local function index_of(entries, path)
    for index, entry in ipairs(entries) do
        if entry.path == path then
            return index
        end
    end
    return 0
end

-- `selected_path` if visible, else the applied file, else the first tile.
local effective_selected = computed({ selected_path, current_path, filtered }, function(chosen, applied, entries)
    entries = entries or {}
    for _, path in ipairs({ chosen, applied }) do
        if index_of(entries, path) > 0 then
            return path
        end
    end
    return entries[1] and entries[1].path or ""
end)

local function move(delta)
    local entries = filtered:get() or {}
    if #entries == 0 then
        return
    end
    local current = math.max(1, index_of(entries, effective_selected:get()))
    local next_index = math.max(1, math.min(current + delta, #entries))
    selected_path:set(entries[next_index].path)
    SCROLL:reveal(math.ceil(next_index / COLUMNS))
end

-- With no query, ring the applied file and scroll to it; else the first match.
local function reset_selection()
    local entries = filtered:get() or {}
    local index = math.max(1, trimmed:get() == "" and index_of(entries, current_path:get()) or 1)
    selected_path:set(entries[index] and entries[index].path or "")
    SCROLL:reveal(math.ceil(index / COLUMNS))
end

local function close()
    ui_state.close_modal("wallpaper_picker")
end

local function apply(path)
    if path == nil or path == "" then
        return
    end
    for _, output in ipairs(targets_now()) do
        wallpaper.set(output, path)
    end
end

---@param entry FileEntry
local function tile(entry)
    local hovered = hover("wallpaper-tile-" .. entry.path)
    local selected = effective_selected:map(function(path)
        return path == entry.path
    end)
    local applied = current_path:map(function(path)
        return path == entry.path
    end)
    return button {
        width = TILE_WIDTH,
        height = TILE_HEIGHT,
        radius = theme.radius.lg,
        clip = "Rounded",
        hover = hovered,
        background = theme.GLASS_CONTENT,
        border_width = selected:map(function(on)
            return on and theme.border_width_medium or theme.border_width
        end),
        border_color = computed({ selected, hovered }, function(on, hot)
            if on then
                return theme.ACCENT
            end
            return hot and theme.GLASS_BORDER_HOVER or theme.GLASS_BORDER
        end),
        on_hover = function(inside)
            if inside then
                selected_path:set(entry.path)
            end
        end,
        on_click = function(_, mouse_button)
            if mouse_button ~= "left" then
                return
            end
            selected_path:set(entry.path)
            apply(entry.path)
        end,
        children = {
            -- Zooms with the selection, so keys and pointer show the same tile; cut by the rounded box.
            image {
                source = entry.path,
                fit = "cover",
                async = true,
                width = "Fill",
                height = "Fill",
                scale = selected:map(function(on)
                    return on and theme.selected_scale or 1
                end),
                animate = { scale = { duration = theme.animation_fast_ms, easing = "OutCubic" } },
            },
            -- Bottom name strip.
            rect {
                width = "Fill",
                height = theme.control.md,
                align_v = "End",
                -- Card glass, not the scrim: xs text over a bright photo needs the near-opaque ground.
                background = theme.GLASS,
                padding = { left = theme.spacing.sm, right = theme.spacing.sm },
                children = {
                    cell(entry.name, theme.FG, theme.font.xs, { width = "Fill", align = "Center", align_v = "Center" }),
                },
            },
            rect {
                width = theme.control.xs,
                height = theme.control.xs,
                radius = theme.control.xs / 2,
                margin = { left = theme.spacing.sm, top = theme.spacing.sm },
                background = theme.ACCENT,
                visible = applied,
                children = {
                    glyph(icons.check, theme.text_contrast(theme.ACCENT), theme.font.xs, { align = "Center", align_v = "Center" }),
                },
            },
        },
    }
end

local function grid_row(entries)
    local tiles = {}
    for _, entry in ipairs(entries) do
        tiles[#tiles + 1] = tile(entry)
    end
    return row { width = "Fill", spacing = tile_gap, children = tiles }
end

local grid = list {
    width = "Fill",
    height = GRID_HEIGHT,
    scroll = SCROLL,
    spacing = tile_gap,
    source = rows,
    itemfn = grid_row,
    key = function(entries)
        local paths = {}
        for i, entry in ipairs(entries) do
            paths[i] = entry.path
        end
        return table.concat(paths, "\n")
    end,
}

local folder_state = computed({ mantle.files, filtered }, function(files, shown)
    local folder = wallpaper.folder_in(files)
    if folder == nil or not folder.ready then
        return "loading"
    elseif folder.error then
        return "error"
    elseif #folder.entries == 0 then
        return "empty"
    elseif #shown == 0 then
        -- Only reachable with a query: an empty needle keeps every entry.
        return "no_match"
    end
    return "ok"
end)

local function state_is(name)
    return folder_state:map(function(current)
        return current == name
    end)
end

local empty_states = {
    panel_empty_state("Loading wallpapers…", state_is("loading"), { icon = spinner(state_is("loading"), theme.icon.xl) }),
    panel_empty_state(
        mantle.files:map(function(files)
            local folder = wallpaper.folder_in(files)
            return string.format("Cannot read %s: %s", wallpaper.FOLDER, folder and folder.error or "")
        end),
        state_is("error"),
        { icon = icons.wallpaper }
    ),
    panel_empty_state("No wallpapers found", state_is("empty"), { icon = icons.wallpaper }),
    panel_empty_state("No results found", state_is("no_match")),
}

local search = search_bar(textfield {
    placeholder = "Search wallpapers…",
    on_change = function(text)
        query:set(text)
        reset_selection()
    end,
    on_submit = function()
        apply(effective_selected:get())
    end,
    on_cancel = function(cleared)
        if not cleared then
            close()
        end
    end,
    on_navigate = function(key)
        if STEPS[key] then
            move(STEPS[key])
        end
    end,
})

-- Each option set is a row of radio tiles, the recorder's short kind. The monitor row is a `list`
-- because screens can change.
local function choice(value, label, current, on_pick, slot)
    return panel_toggle_card {
        slot = slot,
        label = label,
        height = theme.control.md,
        signal = current,
        read = function(now)
            return now == value
        end,
        -- A radio: the lit tile stays lit when clicked again.
        on_change = function()
            on_pick(value)
        end,
    }
end

local monitor_options = mantle.screens:map(function(screens)
    local options = { { value = ALL, label = "All displays" } }
    for _, screen in ipairs(screens or {}) do
        if screen.name and screen.name ~= "" then
            options[#options + 1] = { value = screen.name, label = screen.name }
        end
    end
    return options
end)

local monitor_row = list {
    width = "Fill",
    direction = "Horizontal",
    spacing = theme.spacing.xs,
    source = monitor_options,
    itemfn = function(option)
        return choice(option.value, option.label, effective_monitor, function(value)
            monitor:set(value)
            reset_selection()
        end, "wallpaper-monitor-" .. option.value)
    end,
    key = function(option)
        return option.value
    end,
}

local fit_buttons = {}
for _, fit in ipairs(wallpaper.FITS) do
    fit_buttons[#fit_buttons + 1] = choice(fit.value, fit.label, current_fit, function(value)
        for _, output in ipairs(targets_now()) do
            wallpaper.set_fit(output, value)
        end
    end, "wallpaper-fit-" .. fit.value)
end
local fit_row = row { width = "Fill", spacing = theme.spacing.xs, children = fit_buttons }

-- Three across, matching Fill/Fit/Stretch above, whatever the effect count.
local EFFECTS_PER_ROW = 3
local current_effect = wallpaper.effect()

-- Padded with `""`, an empty slot that keeps its share so a short last row does not stretch.
local effect_rows = wallpaper.effects():map(function(names)
    local rows = {}
    for index = 1, #names, EFFECTS_PER_ROW do
        local slots = {}
        for offset = 0, EFFECTS_PER_ROW - 1 do
            slots[offset + 1] = names[index + offset] or ""
        end
        rows[#rows + 1] = slots
    end
    return rows
end)

local effect_grid = list {
    width = "Fill",
    direction = "Vertical",
    spacing = theme.spacing.xs,
    source = effect_rows,
    itemfn = function(slots)
        local buttons = {}
        for _, name in ipairs(slots) do
            if name ~= "" then
                buttons[#buttons + 1] = choice(
                    name,
                    -- The file's name is the value; its title is what a person reads.
                    name:sub(1, 1):upper() .. name:sub(2),
                    current_effect,
                    wallpaper.set_effect,
                    "wallpaper-effect-" .. name
                )
            else
                buttons[#buttons + 1] = rect { width = "Fill", height = theme.control.md }
            end
        end
        return row { width = "Fill", spacing = theme.spacing.xs, children = buttons }
    end,
    key = function(slots)
        return table.concat(slots, "|")
    end,
}

-- Escape and a click outside close the picker, as they do the launcher, so the sidebar has no ×.
local sidebar = panel_card({
    cell(util.bold("Wallpaper settings"), theme.FG, theme.font.lg, { width = "Fill" }),
    section_header("monitor"),
    monitor_row,
    -- Mixed fits across the targeted screens light no tile, so the label says so.
    section_header(current_fit:map(function(fit)
        return fit == "" and "fill mode · mixed" or "fill mode"
    end)),
    fit_row,
    section_header("transition"),
    effect_grid,
    section_header("folder"),
    cell(wallpaper.FOLDER, theme.DIM, theme.font.xs, { width = "Fill" }),
    cell(filtered:map(function(entries)
        return #entries == 1 and "1 file" or string.format("%d files", #entries)
    end), theme.DIM, theme.font.xs, { width = "Fill" }),
}, {
    width = theme.wallpaper_sidebar_width,
    align_v = "Start",
    spacing = theme.spacing.md,
    outlined = true,
    padding = theme.spacing.md,
})

local body = row {
    width = "Fill",
    height = "Fill",
    spacing = theme.spacing.md,
    children = {
        -- A `rect` stacks, so an empty state centres over the grid instead of under its `Fill`.
        panel_card({ rect { width = "Fill", height = "Fill", children = { grid, table.unpack(empty_states) } } }, {
            width = "Fill",
            height = "Fill",
            outlined = true,
            padding = grid_padding,
        }),
        sidebar,
    },
}

return modal({
    kind = "wallpaper_picker",
    card = panel_card({ search, body }, {
        width = theme.wallpaper_picker_width,
        height = theme.wallpaper_picker_height - (rows_budget - GRID_HEIGHT),
        align_h = "Center",
        align_v = "Center",
        spacing = theme.spacing.md,
        padding = card_padding,
        tone = "dialog",
    }),
})
