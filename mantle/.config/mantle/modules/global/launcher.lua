-- Autofocus search, arrow navigation, Enter launch. A layer surface, not an `xdg_toplevel`, which
-- niri would tile beside other windows.
--
-- `selected_id` holds the last key or hover choice; `effective_selected` keeps it when its row is
-- visible and falls back to the first, computed once for the whole list so three hundred rows stay
-- inside the 5ms budget. Mouse and arrows move the same ring.
--
-- A query routes through currency, calculator, then the web fallback. The first to claim draws the
-- special row above the apps. Providers return plain tables because a `computed` marshals a value
-- and cannot carry a closure.
local theme = require("config.theme")
local icons = require("config.icons")
local cell = require("components.cell")
local search_bar = require("components.search_bar")
local util = require("lib.util")
local store = require("lib.store")
local ui_state = require("lib.ui_state")
local modal = require("components.modal")
local panel_card = require("components.panel_card")
local panel_empty_state = require("components.panel_empty_state")
local info_badge = require("components.info_badge")
local calc = require("modules.global.launcher.calc")
local currency = require("modules.global.launcher.currency")

---What a provider returns when it claims a query, and the whole of what the special row draws. One
---table carries these fields because a `computed` can hold it.
---@class LauncherRow
---@field kind "currency"|"calc"|"web" What `activate` does with `payload`: copy it, or open it.
---@field badge string
---@field hint string
---@field icon string
---@field icon_is_text? boolean The glyph needs the body family, not the Nerd Font one.
---@field title string
---@field subtitle string
---@field payload string

local SCROLL = scroll("launcher_list")
local MAX_RESULTS = 200
local STEPS = { up = -1, backtab = -1, down = 1, tab = 1, page_up = -8, page_down = 8 }
-- Special-row id in `selected_id`, not a desktop-file id; desktop-file ids never start with a space.
local SPECIAL = " special"

local query = state("launcher_query", "")
local selected_id = state("launcher_selected", "")

local function entries_of(applications)
    return (applications and applications.entries) or {}
end

-- One string per entry, scored by `fuzzy` and ordered by score, match start, then length. The name
-- comparison last is ours. `table.sort` is unstable, so entries alike on all three would trade
-- places between keystrokes. The haystack takes keywords too, since "image" is only in GIMP's.
local haystacks = setmetatable({}, { __mode = "k" })
local function haystack_of(app)
    if not haystacks[app] then
        local parts = { app.name }
        if app.comment and app.comment ~= "" then parts[#parts + 1] = app.comment end
        if app.generic_name and app.generic_name ~= "" then parts[#parts + 1] = app.generic_name end
        for _, word in ipairs(app.keywords or {}) do parts[#parts + 1] = word end
        haystacks[app] = table.concat(parts, " ")
    end
    return haystacks[app]
end

-- `best` is the top score, the one thing the web row needs that a sorted list does not carry.
---@return { apps: AppSummary[], best: integer }
local function filter(applications, text)
    local entries = entries_of(applications)
    -- No `lower()`: `fuzzy` is smart-case, so an uppercase letter in the query is the user asking
    -- for an exact match.
    local needle = util.trim(text)
    if needle == "" then
        return { apps = { table.unpack(entries, 1, math.min(#entries, MAX_RESULTS)) }, best = 0 }
    end
    local scored = {}
    local best = 0
    for _, app in ipairs(entries) do
        local haystack = haystack_of(app)
        local value, start = fuzzy(haystack, needle)
        if value then
            scored[#scored + 1] = { app = app, score = value, start = start, length = #haystack }
            if value > best then
                best = value
            end
        end
    end
    table.sort(scored, function(left, right)
        if left.score ~= right.score then
            return left.score > right.score
        end
        if left.start ~= right.start then
            return left.start < right.start
        end
        if left.length ~= right.length then
            return left.length < right.length
        end
        return left.app.name < right.app.name
    end)
    local apps = {}
    for i = 1, math.min(#scored, MAX_RESULTS) do
        apps[i] = scored[i].app
    end
    return { apps = apps, best = best }
end

local matches = computed({ mantle.applications, query }, filter)
local results = matches:map(function(found)
    return found.apps
end)

-- Hostname-shaped input opens as a link, other input searches. Always shown for a URL, otherwise
-- only when the apps matched weakly.
---@return LauncherRow|nil
local function web_claims(text, apps_weak)
    local is_url = text:match("^https?://[^%s]+$") ~= nil or text:match("^[%w%-]+%.[%w%-%.]+[%w]/?[^%s]*$") ~= nil
    if not (is_url or apps_weak) then
        return nil
    end
    local target
    if is_url then
        target = text:match("^https?://") and text or ("https://" .. text)
    else
        target = "https://duckduckgo.com/?q=" .. text:gsub("[^%w%-_%.~]", function(char)
            return string.format("%%%02X", char:byte())
        end)
    end
    return {
        kind = "web",
        badge = is_url and "URL" or "WEB",
        hint = "Enter to open",
        icon = is_url and icons.web or icons.search,
        title = is_url and target or text,
        subtitle = is_url and "Open link" or "Web search",
        payload = target,
    }
end

local trimmed = query:map(util.trim)

-- The first provider that claims wins, and the web row is only reached when neither does.
local special = computed(
    { trimmed, matches, store.currency_rates, store.currency_updated_at },
    function(text, found, rates, updated_at)
        if text == "" then
            return nil
        end
        -- A bare code claims the row only where the web row would have: `dash`, `link`, `php` and
        -- `cad` are currencies as well as things people launch, and an application that matches
        -- well owns the query. A code with no rate falls through here whatever the score. Weak is no
        -- matched apps, or a best score under a threshold that grows with query length, in fzf's units.
        local weak = #found.apps == 0 or found.best < math.max(32, #text * 25)
        return currency.claims(text, rates, updated_at, weak)
            or calc.claims(text)
            or web_claims(text, weak)
    end
)

-- `selected_id` when its row shows, else the first: the launch target before any input, and after
-- filtering drops the hovered row.
local effective_selected = computed({ selected_id, results, special }, function(id, found, row)
    local first = row and SPECIAL or (found and found[1] and found[1].id) or ""
    if id == "" then
        return first
    end
    if id == SPECIAL then
        return row and SPECIAL or first
    end
    for _, app in ipairs(found or {}) do
        if app.id == id then
            return id
        end
    end
    return first
end)

-- Arrow-key order, read when the key arrives and never inside a `computed`.
local function rows_now()
    local ids = {}
    if special:get() then
        ids[#ids + 1] = SPECIAL
    end
    for _, app in ipairs(results:get() or {}) do
        ids[#ids + 1] = app.id
    end
    return ids
end

local function select_first()
    selected_id:set("")
    SCROLL:reveal(1)
end

local function move(delta)
    local ids = rows_now()
    if #ids == 0 then
        return
    end
    local current = 1
    for i, id in ipairs(ids) do
        if id == effective_selected:get() then
            current = i
            break
        end
    end
    local next_index = math.max(1, math.min(current + delta, #ids))
    selected_id:set(ids[next_index])
    local in_list = next_index - (ids[1] == SPECIAL and 1 or 0)
    if in_list >= 1 then
        SCROLL:reveal(in_list)
    end
end

local function close()
    ui_state.close_modal("launcher")
end

local function activate()
    local id = effective_selected:get()
    if id == "" then
        return
    end
    if id == SPECIAL then
        -- The calculator and currency rows copy; the web row opens.
        local row = special:get()
        if not row then
            return
        end
        if row.kind == "web" then
            mantle.applications:invoke("open_url", row.payload)
        else
            -- A Wayland selection lives as long as its owner, and a `process.run` child is
            -- reaped with its Renderer, taking the clipboard with it.
            process.detach("wl-copy", { row.payload })
        end
    else
        mantle.applications:invoke("launch", id)
    end
    close()
end

local function is_selected(id)
    return effective_selected:map(function(selected)
        return selected == id
    end)
end

local function row_shell(id, slot, children, opts)
    local selected = is_selected(id)
    return button {
        hover = hover(slot),
        width = "Fill",
        height = (opts and opts.height) or theme.launcher_row_height,
        radius = theme.radius.md,
        visible = opts and opts.visible,
        background = selected:map(function(on)
            return on and theme.ACCENT_SUBTLE or nil
        end),
        border_width = theme.border_width,
        border_color = selected:map(function(on)
            return on and theme.ACCENT or theme.CLEAR
        end),
        animate = { background = theme.animation_fast_ms, border_color = theme.animation_fast_ms },
        -- Enter and leave count as crossings, so the ring follows a pointer already in place.
        on_hover = function(inside)
            if inside then
                selected_id:set(id)
            end
        end,
        on_click = function(_, mouse_button)
            if mouse_button ~= "left" then
                return
            end
            selected_id:set(id)
            activate()
        end,
        children = { row {
            width = "Fill",
            height = "Fill",
            spacing = theme.spacing.sm,
            align_v = "Center",
            padding = { left = theme.spacing.sm, right = theme.spacing.sm },
            children = children,
        } },
    }
end

---@param app AppSummary
local function app_row(app)
    local selected = is_selected(app.id)
    local lines = {
        cell(util.bold_when(selected, app.name), selected:map(function(on)
            return on and theme.ACCENT or theme.FG
        end), theme.font.md, { width = "Fill" }),
    }
    local subtitle = (app.comment and app.comment ~= "") and app.comment
        or (app.generic_name and app.generic_name ~= "") and app.generic_name
        or nil
    if subtitle then
        lines[#lines + 1] = cell(subtitle, theme.DIM, theme.font.xs, { width = "Fill" })
    end
    return row_shell(app.id, "launcher-app-" .. app.id, {
        -- A generic picture for entries without `Icon=`; the selected one grows in place.
        icon {
            name = app.icon or "application-x-executable",
            size = theme.launcher_icon,
            align_v = "Center",
            scale = selected:map(function(on)
                return on and 1.3 or 1
            end),
            animate = { scale = { duration = theme.animation_fast_ms, easing = "OutCubic" } },
        },
        column { width = "Fill", align_v = "Center", children = lines },
    })
end

-- Leading glyph, title over subtitle, then the badge and hint.
local function special_field(key)
    return special:map(function(row)
        return row and row[key] or ""
    end)
end

local special_selected = is_selected(SPECIAL)
local special_title = computed({ special, special_selected }, function(row, selected)
    local title = row and row.title or ""
    return selected and util.bold(title) or title
end)
local special_row = row_shell(SPECIAL, "launcher-special", {
    -- One node, the family chosen by signal: under the Icon family a regional indicator never
    -- reaches the colour emoji face at the end of the fallback chain.
    cell(special_field("icon"), theme.FG, theme.launcher_icon, {
        align_v = "Center",
        font = special:map(function(row)
            return (row and row.icon_is_text) and "Body" or "Icon"
        end),
    }),
    column {
        width = "Fill",
        align_v = "Center",
        children = {
            cell(special_title, special_selected:map(function(on)
                return on and theme.ACCENT or theme.FG
            end), theme.font.md, { width = "Fill" }),
            cell(special_field("subtitle"), theme.DIM, theme.font.xs, { width = "Fill" }),
        },
    },
    info_badge(special_field("badge")),
    cell(special_field("hint"), theme.DIM, theme.font.xs, { align_v = "Center" }),
}, {
    height = theme.launcher_special_height,
    visible = special:map(function(row)
        return row ~= nil
    end),
})

local app_list = list {
    width = "Fill",
    height = "Fill",
    scroll = SCROLL,
    spacing = theme.spacing.xs,
    source = results,
    itemfn = app_row,
    key = function(app)
        return app.id
    end,
}

local search = search_bar(textfield {
    placeholder = "Search apps, calculate, convert currency…",
    on_change = function(text)
        query:set(text)
        select_first()
    end,
    on_submit = activate,
    -- Two-stage Escape: text clears and stays, empty closes.
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

local no_results = panel_empty_state(
    "No results found",
    computed({ trimmed, results, special }, function(text, found, row)
        return text ~= "" and #found == 0 and row == nil
    end),
    { icon = icons.search, subtext = "Check spelling or try a calculation / currency query" }
)

local no_apps = panel_empty_state(
    "No applications found",
    computed({ mantle.applications, trimmed }, function(apps, text)
        return text == "" and #entries_of(apps) == 0
    end),
    { icon = icons.launcher, subtext = "No desktop entries available" }
)

return modal({
    kind = "launcher",
    below_bar = true,
    card = panel_card({
        search,
        panel_card({ special_row, app_list, no_results, no_apps }, {
            width = "Fill",
            height = "Fill",
            border_width = theme.border_width,
            border_color = theme.GLASS_BORDER,
            padding = theme.spacing.sm,
        }),
    }, {
        width = theme.launcher_width,
        height = theme.launcher_height,
        spacing = theme.spacing.sm,
        padding = theme.spacing.lg,
        tone = "dialog",
    }),
})
