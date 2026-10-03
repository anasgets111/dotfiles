-- The mode rail: the search pill shrinks while four buttons bud out of its end and melt apart.
-- `shaders/launcher_sheen.frag` paints the fill; this places the buttons and their blur on the same
-- curves, walked as keyframes because the shader's springs have no engine easing.
local theme = require("config.theme")
local glyph = require("components.glyph")
local util = require("lib.util")

local M = {}

-- The Quickshell reference's timing. 31 steps keep each keyframe a whole 20 ms.
M.MS = 620
local STEPS = 31

local SIZE = theme.launcher_search_height
local GAP = theme.launcher_mode_gap
local SLOT = SIZE + GAP
-- The pill's width with the rail open; the shader draws four buttons.
local OPEN_WIDTH = theme.launcher_width - 4 * SLOT

local function smoothstep(value)
    local amount = math.max(0, math.min(1, value))
    return amount * amount * (3 - 2 * amount)
end

-- The shader's damped step, scaled to land on 1 at progress 1.
local function response(progress, delay_time, decay, frequency, phase)
    local function at(time)
        return 1 - math.exp(-decay * time) * (math.cos(frequency * time) + phase * math.sin(frequency * time))
    end
    return at(math.max(0, progress - delay_time)) / at(1 - delay_time)
end

local function growth(index, progress)
    if index == 1 then
        return response(progress, 0.055, 10.5, 10.5, 1)
    end
    local rate = ({ 3.8, 3.1, 2.7 })[index - 1]
    return response(progress, 0, rate, rate, 0)
end

-- Delay, decay and frequency of each trailing button's travel out of the first.
local TRAVEL = { { 0.06, 7.2, 8.9 }, { 0.036, 5.4, 6.2 }, { 0.032, 5.4, 5.35 } }

-- How far button `index` sits from its resting slot.
local function offset(index, progress)
    local emerge = SIZE * 0.3 * (growth(1, progress) - 1)
    local travel = TRAVEL[index - 1]
    if not travel then
        return emerge
    end
    local delay_time, decay, frequency = table.unpack(travel)
    return emerge + (index - 1) * SLOT * (response(progress, delay_time, decay, frequency, decay / frequency) - 1)
end

local function reveal(index, progress)
    return smoothstep((progress - 0.36 - 0.025 * (index - 1)) / 0.19)
end

---The search pill's width at `progress`.
---@param progress number
---@return number
function M.width(progress)
    return theme.launcher_width - (theme.launcher_width - OPEN_WIDTH) * response(progress, 0, 6.2, 7.5, 0.4)
end

---Returns `bind(node, fields, extra)`, which binds each `fields[prop](progress)` on `node` at rest
---and walks it as keyframes while `open` changes. `extra` joins the animate table.
---@param open Signal<boolean>
function M.binder(open)
    local moving = pulse(open, M.MS)
    return function(node, fields, extra)
        local runs = { [true] = {}, [false] = {} }
        for prop, value in pairs(fields) do
            node[prop] = open:map(function(on)
                return value(on and 1 or 0)
            end)
            for _, on in ipairs({ true, false }) do
                local frames = {}
                for step = 0, STEPS do
                    frames[#frames + 1] = value((on and step or STEPS - step) / STEPS)
                end
                runs[on][prop] = { duration = M.MS / STEPS, easing = "Linear", keyframes = frames }
            end
        end
        node.animate = computed({ open, moving }, function(on, running)
            local run = running and runs[on] or {}
            for key, value in pairs(extra or {}) do
                run[key] = value
            end
            return run
        end)
        return node
    end
end

---@class RailOpts
---@field open Signal<boolean>
---@field focus Signal<integer> The button keys point at while `open`.
---@field mode Signal<string>
---@field modes { id: string, label: string, icon: string }[]
---@field choose fun(id: string)
---@field bind fun(node: table, fields: table, extra?: table): table From `binder(open)`.

-- ponytail: the blur covers the pill and the buttons but not the necks the shader melts between
-- them, since `behind_blur` ignores `mask` and shaders. Shape the blur from the shader once the engine can.
---@param opts RailOpts
---@return table[]
function M.buttons(opts)
    local bind = opts.bind
    local shown = util.linger(opts.open, M.MS)
    local nodes = {}
    for index, entry in ipairs(opts.modes) do
        local hovered = hover("launcher-mode-" .. index)
        local selected = computed({ opts.open, opts.focus, opts.mode }, function(open, focused, current)
            return open and focused == index or not open and current == entry.id
        end)
        nodes[index] = bind(rect {
            width = SIZE,
            height = SIZE,
            margin = { left = OPEN_WIDTH + GAP + (index - 1) * SLOT },
            clip = "None",
            visible = shown,
            children = {
                bind(rect { width = SIZE, height = SIZE, radius = SIZE / 2, behind_blur = true }, {
                    scale = function(progress)
                        return growth(index, progress)
                    end,
                }),
                bind(rect {
                    hover = hovered,
                    width = SIZE,
                    height = SIZE,
                    radius = SIZE / 2,
                    background = computed({ hovered, selected }, function(over, active)
                        return over and theme.ACCENT_LIGHT or active and theme.ACCENT_SUBTLE or theme.CLEAR
                    end),
                    on_click = function()
                        if opts.open:get() then
                            opts.choose(entry.id)
                        end
                    end,
                    children = { glyph(entry.icon, util.choose(selected, theme.FG, theme.DIM), theme.icon.lg, { align = "Center", align_v = "Center" }) },
                }, {
                    opacity = function(progress)
                        return reveal(index, progress)
                    end,
                    scale = function(progress)
                        return 0.9 + 0.1 * reveal(index, progress)
                    end,
                }, { background = theme.animation_fast_ms }),
            },
        }, {
            translate = function(progress)
                return { x = offset(index, progress) }
            end,
        })
    end
    return nodes
end

return M
