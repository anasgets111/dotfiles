-- Two capture buttons, four encoder bars in one expandable row, and a folder action: the only way
-- to reach the encoder settings without a keybind.
local util = require("lib.util")
local theme = require("config.theme")
local icons = require("config.icons")
local cell = require("components.cell")
local panel_row = require("components.panel_row")
local panel_header = require("components.panel_header")
local segmented = require("components.segmented")
local section_header = require("components.section_header")
local action_button = require("components.action_button")
local info_badge = require("components.info_badge")
local store = require("lib.store")
local ui_state = require("lib.ui_state")
local disclosure = require("lib.disclosure")
local recorder = require("lib.screen_recording")

local KIND = "screen_recorder"

-- `fallback` repeats `lib/store.lua`'s default, because an older `state.json` can lack a key and
-- leave a group with no selected tile.
local GROUPS = {
    {
        key = "audio",
        title = "audio",
        fallback = "desktop",
        options = {
            { value = "off",     label = "No audio" },
            { value = "desktop", label = "Desktop" },
            { value = "mic",     label = "Desktop + mic" },
        },
    },
    {
        key = "quality",
        title = "quality",
        fallback = "high",
        options = {
            { value = "low",    label = "Low",    detail = "Smallest files, softest detail in motion" },
            { value = "medium", label = "Medium", detail = "Balanced size and detail" },
            { value = "high",   label = "High",   detail = "Sharpest detail, largest files" },
        },
    },
    {
        key = "fps",
        title = "frame rate",
        fallback = 60,
        options = {
            { value = 30,  label = "30 fps" },
            { value = 60,  label = "60 fps" },
            { value = 120, label = "120 fps" },
        },
    },
    {
        key = "container",
        title = "format",
        fallback = "mp4",
        options = {
            { value = "mp4", label = "MP4", detail = "Plays and uploads anywhere" },
            { value = "mkv", label = "MKV", detail = "Stays playable if the session crashes mid-recording" },
        },
    },
}

local settings_expanded = disclosure.state("recorder_settings_expanded", false)

local function selected_option(group, settings)
    local chosen = (type(settings) == "table" and settings[group.key]) or group.fallback
    return util.find(group.options, function(option) return option.value == chosen end)
end

-- Keeps the four choices visible in the row without opening it.
local settings_summary = store.screen_recorder:map(function(settings)
    local words = {}
    for _, group in ipairs(GROUPS) do
        local option = selected_option(group, settings)
        if option then
            words[#words + 1] = option.label
        end
    end
    return table.concat(words, " · ")
end)

local status_text = computed(
    { recorder.recording, recorder.paused, recorder.capture_label, recorder.monitor, recorder.start_error },
    function(up, held, label, output, failure)
        if not up then
            if failure ~= nil and failure ~= "" then
                return failure
            end
            return string.format("Ready · %s", output ~= "" and output or "No output")
        end
        local words = held and "Paused" or "Recording"
        return label ~= "" and string.format("%s · %s", words, label) or words
    end
)

-- One bar per group; the detail line explains only the chosen segment.
local function option_group(group)
    local labels, values = {}, {}
    for _, option in ipairs(group.options) do
        labels[option.value] = option.label
        values[#values + 1] = option.value
    end
    local bar = segmented {
        slot = "recorder-" .. group.key,
        options = values,
        value = store.screen_recorder:map(function(settings)
            local option = selected_option(group, settings)
            return option and option.value
        end),
        format = function(value)
            return labels[value]
        end,
        on_select = function(value)
            recorder.set_setting(group.key, value)
        end,
    }

    local detail = store.screen_recorder:map(function(settings)
        local option = selected_option(group, settings)
        return (option and option.detail) or ""
    end)

    return column {
        width = "Fill",
        spacing = theme.spacing.xs,
        children = {
            section_header(group.title),
            bar,
            cell(detail, theme.DIM, theme.font.xs, {
                width = "Fill",
                wrap = "Word",
                visible = detail:map(function(line)
                    return line ~= ""
                end),
            }),
        },
    }
end

local settings_children = {}
for _, group in ipairs(GROUPS) do
    settings_children[#settings_children + 1] = option_group(group)
end
settings_children[#settings_children + 1] = cell("Changes apply to the next recording", theme.DIM, theme.font.xs, {
    width = "Fill",
    wrap = "Word",
    visible = recorder.recording,
})

local idle = recorder.recording:map(function(up)
    return not up
end)

local function capture(target)
    return function()
        ui_state.close_panel()
        recorder.start(target)
    end
end

local function wide_button(label, on_activate, slot, tone, icon, visible)
    return action_button(label, on_activate, slot, {
        tone = tone,
        width = "Fill",
        height = theme.panel_toggle_height,
        glyph = icon,
        visible = visible,
    })
end

local body = {
    panel_header {
        title = "Screen recorder",
        subtitle = status_text,
        -- Red marks an active capture, not "off".
        accent = util.choose(recorder.recording, theme.RED, theme.ACCENT),
        trailing = {
            info_badge(recorder.elapsed_text, util.choose(recorder.paused, theme.PEACH, theme.RED),
                { visible = recorder.recording }),
        },
    },

    -- Four buttons in two slots, not two colour-changing ones: `action_button` fixes its grounds
    -- from a static `tone`, and an invisible node takes no size or spacing gap (`layout/scene.rs`),
    -- so a pair per state costs the same row and each button keeps one label and one job. Tinted
    -- glass at tile height, like the switch tiles other panels keep in this band; solid is for a
    -- footer's conclusion, and red for the one action that ends a capture.
    row {
        width = "Fill",
        spacing = theme.spacing.sm,
        children = {
            wide_button("Region", capture("selection"), "recorder-region", "accent", icons.region, idle),
            wide_button("Screen", capture(), "recorder-screen", "accent", icons.display, idle),
            wide_button("Stop", recorder.stop, "recorder-stop", "danger", icons.stop, recorder.recording),
            wide_button(util.choose(recorder.paused, "Resume", "Pause"), recorder.toggle_pause,
                "recorder-pause", "accent", util.choose(recorder.paused, icons.play, icons.pause), recorder.recording),
        },
    },


    panel_row {
        title = "Recording settings",
        subtitle = settings_summary,
        slot = "recorder-settings",
        expanded = settings_expanded,
        details = column {
            width = "Fill",
            spacing = theme.spacing.md,
            padding = { left = theme.spacing.sm, right = theme.spacing.sm },
            children = settings_children,
        },
    },

    panel_row {
        title = "Open recordings folder",
        subtitle = recorder.directory:map(function(dir)
            local home = os.getenv("HOME") or ""
            if home ~= "" and dir:sub(1, #home) == home then
                return "~" .. dir:sub(#home + 1)
            end
            return dir
        end),
        slot = "recorder-folder",
        on_activate = function()
            ui_state.close_panel()
            recorder.open_directory()
        end,
    },
}

return { kind = KIND, body = body }
