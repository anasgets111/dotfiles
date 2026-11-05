-- Rows the audio panel's sections share: a level row with its slider, and a picker option.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local glyph = require("components.glyph")
local panel_action_icon = require("components.panel_action_icon")
local panel_row = require("components.panel_row")
local slider = require("components.slider")
local disclosure = require("lib.disclosure")

local rows = {}

-- One grid for every audio row, so icons, titles, sliders and the trailing columns line up
-- across cards. Left to right: card padding, row inset, icon column, gap, text, then %, mute
-- and the row inset again. Sliders run between the two insets.
local SPACE = theme.spacing.sm
rows.GRID = {
    pad = SPACE, -- card padding, as `panel_card` takes it
    inset = SPACE, -- a row's own left and right padding, `panel_row`'s
    gap = SPACE, -- between columns, `panel_row`'s spacing
    -- Puts the title on the panel header's title edge: tile `control.lg`, then `gap`.
    icon_column = theme.control.lg - 2 * SPACE,
    icon = theme.icon.lg, -- glyphs and app icons alike, drawn from the column's left edge
    option_icon = theme.icon.md, -- a picker option's lighter glyph, in the same column
    row_height = theme.control.md, -- every row's title block, cards' headers included
    track_gap = theme.spacing.xs, -- from a row's title block down to its slider
    percent = theme.control.lg,
    mute = theme.control.md, -- `panel_action_icon` at size `"md"`
    mute_icon = theme.icon.md,
    -- Optical sizes. The Mono face draws every glyph 0.6 em wide, but Material's microphone inks
    -- 0.82 em tall against the speaker's 0.59 em, with 1.3x the area (measured at 240 px).
    glyph_scale = {
        [icons.mic] = 0.8,
        [icons.mic_muted] = 0.85,
    },
    -- The same in a mute button, where the speaker beside it sits in a smaller box.
    mute_scale = {
        [icons.mic] = 0.9,
        [icons.mic_muted] = 0.9,
    },
}
local G = rows.GRID

-- A level row is its row plus its track, so a list is cut between them, not through a slider.
rows.LEVEL_HEIGHT = G.row_height + G.track_gap + theme.slider_height
rows.OPTION_HEIGHT = G.row_height
-- A slider runs from the icon's left edge to the row's right inset, as the trailing column does.
rows.TRACK_MARGIN = { left = G.inset, right = G.inset }

local function scaled(size, content, scale)
    return util.lift(content, function(shown)
        return math.floor(size * ((scale or G.glyph_scale)[shown] or 1) + 0.5)
    end)
end

-- The icon column, centred on the title and subtitle block.
function rows.icon_column(node)
    return rect {
        width = G.icon_column,
        height = G.icon,
        align_v = "center",
        children = { node },
    }
end

-- A glyph on the column's left edge, which every slider shares.
function rows.glyph(content, color, size)
    return glyph(content, color or theme.FG, scaled(size or G.icon, content), { align = "start", align_v = "center" })
end

-- The struck glyph while muted, on outputs and inputs alike.
function rows.mute_glyph(muted, is_input)
    if is_input then
        return muted and icons.mic_muted or icons.mic
    end
    return muted and icons.vol_muted or icons.vol_high
end

-- A mute button on the grid. `glyph` may be a signal; both of a direction's glyphs share a scale.
function rows.mute_button(glyph_content, is_input, on_activate, opts)
    opts.size = "md"
    opts.icon_size = scaled(G.mute_icon, rows.mute_glyph(false, is_input), G.mute_scale)
    return panel_action_icon(glyph_content, on_activate, opts)
end

function rows.percent_cell(content, color, bold)
    return cell(bold and util.bold(content) or content, color, theme.font.sm,
        { width = G.percent, align = "end", align_v = "center" })
end

function rows.percent(value)
    return value and string.format("%d%%", math.floor(value + 0.5)) or "--"
end

-- The one device list open in the panel: `"output"`, `"input"`, `"app-<id>"`, or `""`. Opening one
-- closes the others.
rows.open_picker = disclosure.state("audio_open_picker", "")

function rows.toggle_picker(key)
    rows.open_picker:set(rows.open_picker:get() == key and "" or key)
end

-- The subtitle that opens list `key` below its slider: "<name> ›", accent on hover. With one
-- choice (`choosable` false) it is plain text that takes no click.
---@param opts { slot: string, key: string, label: string|Bound, choosable: boolean|Bound }
function rows.picker_button(opts)
    local hovered = hover(opts.slot)
    local choosable = opts.choosable
    local open = rows.open_picker:map(function(key) return key == opts.key end)
    local ink = type(choosable) == "userdata" and computed({ hovered, choosable }, function(lit, on)
        return lit and on and theme.ACCENT or theme.DIM
    end, theme.DIM) or choosable and util.choose(hovered, theme.ACCENT, theme.DIM) or theme.DIM
    return row {
        hover = hovered,
        spacing = theme.spacing.xs,
        align_v = "center",
        cursor = util.choose(choosable, "pointer", "default"),
        on_click = function(_, mouse_button)
            local on = choosable
            if type(on) == "userdata" then
                on = on:get()
            end
            if mouse_button == "left" and on then
                rows.toggle_picker(opts.key)
            end
        end,
        children = {
            cell(opts.label, ink, theme.font.xs, { animate = { foreground = theme.animation_ms } }),
            glyph(util.choose(open, icons.chevron_down, icons.chevron_right), ink, theme.font.xs,
                { align_v = "center", visible = choosable, animate = { foreground = theme.animation_ms } }),
        },
    }
end

-- A row on the grid: icon, a title over optional lines, then `trailing` (e.g. %, mute).
---@param opts { leading: Node, title: string|TextRun[]|Bound, lines?: Node[], trailing?: Node[], opacity?: number|Bound }
function rows.header(opts)
    local lines = { cell(opts.title, theme.FG, theme.font.sm, { width = "fill" }) }
    for _, line in ipairs(opts.lines or {}) do
        lines[#lines + 1] = line
    end
    return row {
        width = "fill",
        min_height = G.row_height,
        spacing = G.gap,
        align_v = "center",
        opacity = opts.opacity,
        padding = { left = G.inset, right = G.inset },
        children = {
            rows.icon_column(opts.leading),
            column { width = "fill", align_v = "center", children = lines },
            row { spacing = G.gap, align_v = "center", children = opts.trailing or {} },
        },
    }
end

-- The `%` then mute columns, after anything in `before`.
function rows.trailing(before, percent, mute)
    local children = {}
    for _, node in ipairs(before or {}) do
        children[#children + 1] = node
    end
    children[#children + 1] = percent
    children[#children + 1] = rect { width = G.mute, align_v = "center", children = { mute } }
    return children
end

---@class LevelRowOpts
---@field key string Unique per row; names the held value and the hover slots.
---@field leading Node The icon; `rows.glyph` makes one.
---@field title string
---@field picker? { key: string, label: string, choosable: boolean } A subtitle button for list `key`, which opens under the slider.
---@field level { muted: boolean, volume?: number } The stream or device as last pushed.
---@field read fun(audio: AudioState): number? The level off a fresh payload, for the slider.
---@field set_volume fun(value: number)
---@field set_muted fun(muted: boolean)
---@field is_input? boolean Microphone mute glyphs.
---@field headroom? boolean Up to `util.MAX_VOLUME`, the boost colour past a tick at 100%.
---@field badge? Node Before the readout.

-- A stream or device: its row, then its track. Muted dims both.
---@param opts LevelRowOpts
function rows.level_row(opts)
    local level = opts.level
    local tint = level.muted and theme.DIM or theme.FG
    local held = state("audio_pending_" .. opts.key, -1)
    local max = opts.headroom and util.MAX_VOLUME or 100
    local dimmed = (level.muted or level.volume == nil) and theme.opacity.muted or nil
    local picker = opts.picker
    return column {
        width = "fill",
        spacing = G.track_gap,
        children = {
            rows.header {
                leading = opts.leading,
                title = opts.title,
                lines = picker and { rows.picker_button {
                    slot = "audio-level-picker-" .. opts.key,
                    key = picker.key,
                    label = picker.label,
                    choosable = picker.choosable,
                } } or nil,
                opacity = dimmed,
                trailing = rows.trailing({ opts.badge }, rows.percent_cell(held:map(function(value)
                    return rows.percent(value >= 0 and value or level.volume)
                end), tint), rows.mute_button(rows.mute_glyph(level.muted, opts.is_input), opts.is_input,
                    level.volume and function() opts.set_muted(not level.muted) end,
                    { slot = "audio-level-mute-" .. opts.key, tint = tint })),
            },
            column {
                width = "fill",
                opacity = dimmed,
                margin = rows.TRACK_MARGIN,
                children = { slider {
                    name = "audio_pending_" .. opts.key,
                    accessible_name = opts.title .. " volume",
                    pending = held,
                    signal = mantle.audio,
                    read = opts.read,
                    on_commit = opts.set_volume,
                    max = max,
                    steps = max / 5,
                    split_at = opts.headroom and 100 or nil,
                    marker = opts.headroom,
                    headroom_color = level.muted and theme.INACTIVE or theme.RED,
                    color = level.muted and theme.INACTIVE or theme.ACCENT,
                } },
            },
        },
    }
end

-- One picker option: a device, a profile or a port, with its kind's icon. An unplugged one is
-- greyed with "not connected" and takes no click; the current one carries the check.
---@param item { key: string, title: string, icon?: string, active?: boolean, available?: boolean }
---@param on_activate fun()
function rows.option_row(item, on_activate)
    local plugged = item.available ~= false
    local trailing = item.active and glyph(icons.check, theme.ACCENT, theme.icon.sm)
        or not plugged and cell("not connected", theme.DIM, theme.font.xs) or nil
    return panel_row {
        slot = "audio-option-" .. item.key,
        height = rows.OPTION_HEIGHT,
        leading = rows.icon_column(rows.glyph(item.icon or icons.speaker, item.active and theme.ACCENT or nil,
            G.option_icon)),
        title = item.title,
        color = item.active and theme.ACCENT or nil,
        opacity = not plugged and theme.opacity.disabled or nil,
        trailing = trailing,
        on_activate = plugged and not item.active and on_activate or nil,
    }
end

return rows
