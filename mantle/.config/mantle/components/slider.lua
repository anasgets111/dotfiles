-- Value-filled track. A drag sets the value anywhere, the wheel steps it, and `on_commit` fires once
-- per drag or notch.
--
-- `pending` holds the dragged value locally, sparing a Supervisor round trip per pixel. It stays
-- until the snapshot carries it, because clearing on release flashes new, old, new. One `on_change`
-- per slider name clears it, with a one-second timer for a write that another writer or a clamp
-- never lands. `state()` fixes its type as numeric, so `-1` means nothing held.
local theme = require("config.theme")

---@class SliderOpts
---@field name string The `state()` name for the held drag. Unique per slider.
---@field signal Signal|Capability<any> The capability or state the value is read from.
---@field read fun(payload: any): number? The value, `0` to `max`, off one payload; `nil` ignores drag and wheel.
---@field on_commit fun(value: number) Called once per drag, on release, and once per wheel step.
---@field max? number The full track's value. Default `1`.
---@field steps? number How many positions the track has across `0` to `max`. A drag lands on the nearest one and a wheel notch moves one. Default `20 * max`, 5% steps; `0` is continuous.
---@field split_at? number The value past which the fill takes `headroom_color`. Default `max`.
---@field headroom_color? Color|Bound The fill past `split_at`. Default `theme.RED`.
---@field marker? boolean A 1px line at `split_at`.
---@field color? Color|Bound The fill. Default accent.
---@field fill_visible? Signal<boolean> Fades the fill while keeping the track and input.
---@field width? Length|Bound
---@field height? integer|Bound
---@field radius? integer|Bound
---@field align_v? Align
---@field background? Color|Bound The ground under the fill. Default `theme.SURFACE`.
---@field border_width? integer
---@field border_color? Color|Bound
---@field animate? ButtonAnimations|Bound Eases the track's own properties; the fill follows the value and is not eased.
---@field hover? Signal
---@field pending? StateSignal<number> The held value, `-1` when none. Default `state(name)`.
---@field dragging? StateSignal<boolean> True while a drag is held. Default `state(name .. "_dragging")`.
---@field visible? boolean|Bound
---@field on_click? fun(rect: Rect, button: "left"|"right"|"middle") The left click still lands after the drag ends.
---@field label? fun(ground: Color|Bound): Node Built on the track and again inside each bar, which clips its copy, so ink contrasts with the ground under each pixel. Give it the control's width so the copies line up.

local function clamp(value, max)
    return math.max(0, math.min(max, value))
end

-- Snap to the nearest `steps` position, so a 79% drag commits 80%.
local function quantize(value, steps, max)
    if steps <= 0 then
        return clamp(value, max)
    end
    return clamp(math.floor(value / max * steps + 0.5) * max / steps, max)
end

local function value_of(read, payload, max)
    local ok, value = pcall(read, payload)
    if payload ~= nil and ok and type(value) == "number" then
        return clamp(value, max)
    end
end

-- Per name, since `list` rebuilds rows: `on_change` registers once, `timer` and wheel `rest` persist.
local per_name = {}

---@param opts SliderOpts
return function(opts)
    local pending = opts.pending or state(opts.name, -1)
    local dragging = opts.dragging or state(opts.name .. "_dragging", false)
    local max = opts.max or 1
    local steps = opts.steps or (20 * max)
    -- Continuous: half a displayed percent.
    local tolerance = (steps > 0 and 0.5 / steps or 0.005) * max
    local on_change = opts.signal.on_change

    local entry = per_name[opts.name]
    if not entry then
        entry = { rest = 0 }
        per_name[opts.name] = entry
        if on_change then
            on_change(opts.signal, function(current, previous)
                local held = pending:get()
                if dragging:get() or held < 0 then
                    return
                end
                -- Landed, or another writer moved away from `held`; our own writes move toward it.
                local now, before = value_of(opts.read, current, max), value_of(opts.read, previous, max)
                if now == nil or before == nil then
                    return
                end
                local off = math.abs(now - held)
                local was = math.abs(before - held)
                if off <= tolerance or off > was + tolerance then
                    pending:set(-1)
                end
            end)
        end
    end

    local function hold(value)
        if not on_change then
            pending:set(-1)
            return
        end
        pending:set(value)
        if entry.timer then
            entry.timer:cancel()
        end
        entry.timer = timer(1000, function()
            if not dragging:get() then
                pending:set(-1)
            end
        end)
    end

    local fill = computed({ opts.signal, pending }, function(payload, held)
        if held >= 0 then
            return held
        end
        return value_of(opts.read, payload, max) or 0
    end)

    local fill_opacity = opts.fill_visible and opts.fill_visible:map(function(shown)
        return shown and 1 or 0
    end)
    local fill_animate = fill_opacity and { opacity = { duration = theme.animation_ms, easing = "OutCubic" } }

    -- `%d` raises on a float in Lua 5.4; see `components/meter.lua`.
    local function percent(value)
        return string.format("%d%%", math.floor(value / max * 100 + 0.5))
    end
    -- The track's rounded clip cuts both bars, so a short fill follows its arc.
    local function bar(width, color)
        return rect {
            width = width,
            height = "Fill",
            radius = opts.radius or theme.radius.sm,
            background = color,
            opacity = fill_opacity,
            animate = fill_animate,
            -- ponytail: the bar's square box clips its copy, so ink overhangs a pill's rounded end
            -- by ~1.5px; `clip = "Rounded"` is exact for an offscreen target per bar.
            children = { opts.label and opts.label(color) or nil },
        }
    end
    local split = opts.split_at or max
    local track = opts.background or theme.SURFACE
    local children = {
        -- Headroom under the fill, drawn only past `split`: the fill's rounded end caps it.
        bar(fill:map(function(value)
            return percent(value > split and value or 0)
        end), opts.headroom_color or theme.RED),
        bar(fill:map(function(value)
            return percent(math.min(value, split))
        end), opts.color or theme.ACCENT),
        row {
            width = "Fill",
            height = "Fill",
            children = {
                rect { width = percent(split) },
                -- A zero-width box paints nothing.
                rect { width = opts.marker and 1 or 0, height = "Fill", background = theme.with_opacity(theme.FG, theme.opacity.medium) },
            },
        },
    }
    -- Under the bars, which cover it with their own copies.
    if opts.label then
        table.insert(children, 1, opts.label(track))
    end

    return button {
        width = opts.width or "Fill",
        height = opts.height or theme.slider_height,
        align_v = opts.align_v,
        radius = opts.radius or theme.radius.sm,
        clip = "Rounded",
        background = track,
        border_width = opts.border_width,
        border_color = opts.border_color,
        animate = opts.animate,
        hover = opts.hover,
        visible = opts.visible,
        on_click = opts.on_click,
        on_drag = function(rect, pointer, phase)
            if value_of(opts.read, opts.signal:get(), max) == nil then
                dragging:set(false)
                pending:set(-1)
                return
            end
            local value = quantize(pointer.x / rect.width * max, steps, max)
            if phase ~= "end" then
                dragging:set(true)
                pending:set(value)
                return
            end
            dragging:set(false)
            hold(value)
            opts.on_commit(value)
        end,
        on_wheel = function(_, notches)
            local current = value_of(opts.read, opts.signal:get(), max)
            if steps <= 0 or current == nil then
                return
            end
            -- Touchpad fractions accumulate, reset on reversal; 1e-4 rounds f32 0.9999... up.
            local total = (entry.rest * notches < 0 and 0 or entry.rest) + notches
            local whole = math.modf(total + (total < 0 and -1e-4 or 1e-4))
            entry.rest = total - whole
            if whole == 0 then
                return
            end
            local held = pending:get()
            current = held >= 0 and held or current
            -- Snap first: a 79% value from another mixer steps to 80% then 85%, not 84%.
            local next_value = quantize(quantize(current, steps, max) + whole * max / steps, steps, max)
            hold(next_value)
            opts.on_commit(next_value)
        end,
        children = children,
    }
end
