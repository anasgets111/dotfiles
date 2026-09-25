-- Effects demo: one floating window that is one viewport. The wallpaper sits under everything,
-- each feature is an island with its controls in a glass strip right under it, and a frosted pane
-- drags over all of it. Its own instance, `mantle -c ~/.config/mantle/demo`, sharing the shell's
-- `config/`, `components/` and `lib/` through symlinks. Closing the window stops the instance.
fonts {
    "CaskaydiaCove Nerd Font Propo",
    "Noto Sans",
    "Noto Color Emoji",
}

local theme = require("config.theme")
local slider = require("components.slider")
local segmented = require("components.segmented")
local store = require("lib.store")
local wallpaper = require("lib.wallpaper")

-- Two rows of three islands on one set of columns. An island is a title, a stage and a strip.
local WIN_W, WIN_H = 1280, 760
local PAD, GAP = theme.spacing.xl, theme.spacing.lg
local HEADER_H, TITLE_H, STRIP_H = 32, theme.control.xs, 36
local INSET = theme.spacing.sm
local STAGE_H = (WIN_H - 2 * PAD - HEADER_H - 2 * GAP) / 2 - 4 * INSET - TITLE_H - STRIP_H
local SIDE_W = 360
local WIDE_W = WIN_W - 2 * PAD - 2 * GAP - 2 * SIDE_W
local SHADERS = mantle.config_dir .. "/shaders/"
local INK, INK_DIM = "#ffffff", "#ffffffcc"
local TINT = theme.with_opacity("#ffffff", 0.15)

-- The first output, and its wallpaper as it changes.
local first_output = mantle.screens:map(function(screens)
    return screens and screens[1] and screens[1].name or ""
end)
local picture = computed({ store.wallpapers, mantle.files, mantle.screens }, function(wallpapers, files, screens)
    local first = screens and screens[1]
    return first and wallpaper.path_in(wallpapers, first.name, files) or ""
end)

---------------------------------------------------------------------------------------------------
-- Building blocks

local function label(content, color, size)
    return text { content = content, foreground = color or theme.FG, font_size = size or theme.font.sm, align_v = "Center" }
end

local function centred(child)
    return column { align_h = "Center", align_v = "Center", clip = "None", children = { child } }
end

-- A slider on one line, updating while dragged.
local function knob(name, title, max, initial, steps, format)
    local value = state("fx_" .. name, initial)
    local held = state("fx_" .. name .. "_held", -1)
    local live = computed({ value, held }, function(v, h)
        return h >= 0 and h or v
    end)
    local node = row {
        width = "Fill",
        align_v = "Center",
        spacing = theme.spacing.sm,
        children = {
            label(title, INK_DIM, theme.font.xs),
            slider {
                name = "fx_" .. name .. "_slider",
                signal = value,
                pending = held,
                read = function(v) return v end,
                on_commit = function(v) value:set(v) end,
                max = max,
                steps = steps,
                width = "Fill",
                height = 10,
            },
            label(live:map(function(v) return string.format(format, v) end), INK, theme.font.xs),
        },
    }
    return node, live
end

-- Segments are sized by the longest label; `after` runs per selection.
local function choice(name, options, initial, after)
    local value = state("fx_" .. name, initial)
    local longest = 0
    for _, option in ipairs(options) do
        longest = math.max(longest, #tostring(option))
    end
    local node = segmented {
        slot = "fx_" .. name,
        options = options,
        value = value,
        on_select = function(v)
            value:set(v)
            if after then
                after()
            end
        end,
        width = #options * (7 * longest + 18),
        height = theme.control.xs,
    }
    return node, value
end

local function glass(props)
    props.radius = props.radius or theme.radius.md
    props.background = theme.with_opacity(theme.CRUST, 0.6)
    props.backdrop_blur = 8
    props.border_width = 1
    props.border_color = theme.GLASS_BORDER
    return rect(props)
end

local function badge(content)
    return rect {
        padding = { left = 8, right = 8, top = 2, bottom = 2 },
        radius = 999,
        background = theme.ACCENT_SUBTLE,
        children = { label(content, theme.ACCENT, theme.font.xs) },
    }
end

-- An island: one glass card with its title, its stage and its controls as the footer.
local function island(title, width, scene, controls, ground)
    return glass {
        width = width,
        radius = theme.radius.lg,
        padding = INSET,
        children = {
            column {
                width = "Fill",
                spacing = INSET,
                children = {
                    row { height = TITLE_H, padding = { left = theme.spacing.xs }, children = { label(title, INK, theme.font.sm) } },
                    rect { width = "Fill", height = STAGE_H, radius = theme.radius.md, clip = "Rounded", background = ground, children = scene },
                    row { width = "Fill", height = STRIP_H, align_v = "Center", spacing = theme.spacing.md, padding = { left = theme.spacing.xs, right = theme.spacing.xs }, children = controls },
                },
            },
        },
    }
end

---------------------------------------------------------------------------------------------------
-- Shader and blur: the goo shader's `progress` rides `animate`, and three pills over it show no
-- blur, content_blur (the pill itself blurs) and backdrop_blur (what is under it blurs). Each
-- caption sits under its pill, so a blurred pill still says what it is.

local shader_mode_node, shader_mode = choice("shader_mode", { "Loop", "Open", "Closed" }, "Loop")
local softness_node, softness = knob("soft", "goo", 60, 24, 60, "%.0f")
local sigma_node, sigma = knob("lab_sigma", "blur", 32, 6, 64, "%.1f")

local function pill(title, props)
    local node = {
        width = 136,
        height = 48,
        radius = 999,
        background = TINT,
        border_width = 1,
        border_color = "#ffffff55",
        shadow_color = "#00000099",
        shadow_blur = 18,
        shadow_offset = { x = 0, y = 8 },
        children = { centred(label("Mantle", INK, theme.font.md)) },
    }
    for key, value in pairs(props) do
        node[key] = value
    end
    return column { align_h = "Center", clip = "None", spacing = theme.spacing.xs, children = { rect(node), label(title, INK, theme.font.xs) } }
end

local shader_island = island("Shader & blur", WIDE_W, {
    shader {
        width = "Fill",
        height = "Fill",
        source = SHADERS .. "probe_goo.frag",
        progress = shader_mode:map(function(m) return m == "Open" and 1 or 0 end),
        params = softness:map(function(s) return { tint = { 0.95, 0.45, 0.75, 0.85 }, softness = s, stagger = 0.15 } end),
        animate = shader_mode:map(function(m)
            if m == "Loop" then
                return { progress = { duration = 1600, easing = "InOutCubic", keyframes = { 0, 1, 1, 0 }, loops = "Infinite" } }
            end
            return { progress = { spring = { stiffness = 140, damping = 10 } } }
        end),
    },
    centred(row {
        translate = { x = 0, y = 44 },
        clip = "None",
        spacing = theme.spacing.lg,
        children = {
            pill("no blur", {}),
            -- The whole pill blurs, text included, since a flat fill blurs into itself and looks
            -- unchanged. The rounded clip keeps the 3-sigma spread inside the pill.
            pill("content_blur", { clip = "Rounded", content_blur = sigma }),
            pill("backdrop_blur", { backdrop_blur = sigma }),
        },
    }),
}, { shader_mode_node, softness_node, sigma_node })

---------------------------------------------------------------------------------------------------
-- Shadow: hover lifts the shape, and every shadow property tweens on the way.

local shape_node, shape = choice("shadow_shape", { "Card", "Pill", "Glass" }, "Card")
local shadow_mode_node, shadow_mode = choice("shadow_mode", { "Box", "Content" }, "Box")
local lifted = hover("fx_shadow_hover")

local shadow_island = island("Shadow", SIDE_W, {
    centred(rect {
        hover = lifted,
        width = shape:map(function(s) return s == "Pill" and 200 or 160 end),
        height = shape:map(function(s) return s == "Pill" and 56 or 96 end),
        radius = shape:map(function(s) return s == "Pill" and 999 or theme.radius.lg end),
        background = shape:map(function(s) return s == "Glass" and theme.with_opacity(theme.ACCENT, 0.4) or theme.ACCENT end),
        shadow_color = "#00000099",
        shadow_blur = lifted:map(function(on) return on and 36 or 12 end),
        shadow_offset = lifted:map(function(on) return { x = 0, y = on and 20 or 6 } end),
        translate = lifted:map(function(on) return { x = 0, y = on and -8 or 0 } end),
        shadow_mode = shadow_mode,
        animate = { shadow_blur = theme.animation_slow_ms, shadow_offset = theme.animation_slow_ms, translate = theme.animation_slow_ms },
        children = { centred(label("hover me", theme.CRUST, theme.font.md)) },
    }),
}, { shape_node, shadow_mode_node }, theme.GLASS)

---------------------------------------------------------------------------------------------------
-- Gradient and mask: a gradient square that turns, and a list whose alpha a gradient or an image
-- multiplies, like Qt's OpacityMask.

local kind_node, kind = choice("grad_kind", { "Linear", "Radial", "Conic" }, "Linear")
local mask_node, mask_mode = choice("mask_mode", { "Fade", "Star", "Off" }, "Fade")

local gradient_island = island("Gradient & mask", SIDE_W, {
    row {
        align_h = "Center",
        align_v = "Center",
        spacing = theme.spacing.xl,
        children = {
            rect {
                width = 120,
                height = 120,
                radius = theme.radius.lg,
                rotate = 0,
                animate = { rotate = { duration = 9000, easing = "Linear", keyframes = { 0, 360 }, loops = "Infinite" } },
                background = kind:map(function(k)
                    return { gradient = k, angle = k ~= "Radial" and 90 or nil, stops = { { 0, "#cba6f7" }, { 0.5, "#f38ba8" }, { 1, "#89b4fa" } } }
                end),
            },
            rect {
                width = 120,
                height = 120,
                radius = theme.radius.lg,
                clip = "Rounded",
                children = { image { source = picture, width = "Fill", height = "Fill", fit = "cover", async = true } },
                mask = computed({ mask_mode, kind }, function(m, k)
                    if m == "Off" then
                        return nil
                    end
                    if m == "Star" then
                        return { source = SHADERS .. "probe_mask.svg" }
                    end
                    return {
                        gradient = k,
                        angle = k ~= "Radial" and 90 or nil,
                        stops = { { 0, "#ffffff00" }, { 0.3, "#ffffff" }, { 0.7, "#ffffff" }, { 1, "#ffffff00" } },
                    }
                end),
            },
        },
    },
}, { kind_node, mask_node }, theme.GLASS)

---------------------------------------------------------------------------------------------------
-- Live capture: the first output's contents, which on its own output shows itself inside itself.

local live_node, live = choice("cap_live", { "60 fps", "Uncapped", "Still" }, "60 fps")

local capture_island = island("Live capture", WIDE_W, {
    capture {
        width = "Fill",
        height = "Fill",
        output = first_output,
        fit = "cover",
        live = live:map(function(v)
            return v == "Uncapped" or (v == "60 fps" and 60)
        end),
        paint_cursor = true,
    },
}, { live_node, badge(first_output) }, "#000000")

---------------------------------------------------------------------------------------------------
-- Palette: the wallpaper's dominant colours, off the Lua thread. The stage is a gradient through them.

local swatches = state("fx_swatches", {})
local colours_node, colours
local function quantize()
    local path = picture:get()
    if path ~= "" then
        palette.quantize(path, { depth = math.floor(math.log(colours:get(), 2) + 0.5) }, function(found)
            swatches:set(found or {})
        end)
    end
end
colours_node, colours = choice("pal_colours", { 8, 16, 32 }, 8, quantize)

-- A grid of eight per row, since `list` lays out one line.
local palette_island = island("Palette", SIDE_W, {
    column {
        align_h = "Center",
        align_v = "Center",
        spacing = theme.spacing.xs,
        children = swatches:map(function(found)
            local grid = {}
            for i, swatch in ipairs(found) do
                local line = math.ceil(i / 8)
                grid[line] = grid[line] or {}
                table.insert(grid[line], rect {
                    width = 36,
                    height = 32,
                    radius = theme.radius.sm,
                    background = swatch.color,
                    border_width = 1,
                    border_color = "#ffffff55",
                })
            end
            for line, cells in ipairs(grid) do
                grid[line] = row { spacing = theme.spacing.xs, children = cells }
            end
            return grid
        end),
    },
}, { label("colours", INK_DIM, theme.font.xs), colours_node }, swatches:map(function(found)
    if #found < 2 then
        return theme.BG
    end
    local stops = {}
    for i, swatch in ipairs(found) do
        stops[i] = { (i - 1) / (#found - 1), swatch.color }
    end
    return { gradient = "Linear", angle = 90, stops = stops }
end))

---------------------------------------------------------------------------------------------------
-- Windows and screens: chips that fade in, follow focus and shrink away when a window closes.

local window_list = mantle.windows:map(function(payload)
    return payload and payload.windows or {}
end)
local screen_line = mantle.screens:map(function(screens)
    local s = screens and screens[1]
    return s and string.format("%s %s  %dx%d @ %.0f Hz  scale %.2f", s.name, s.model or "", s.width, s.height,
        s.refresh or 0, s.fractional_scale or s.scale) or ""
end)

local windows_island = island("Windows", SIDE_W, {
    list {
        source = window_list,
        width = "Fill",
        padding = INSET,
        spacing = theme.spacing.xs,
        limit = 7,
        key = function(w) return w.id end,
        itemfn = function(w)
            return rect {
                width = "Fill",
                height = 26,
                radius = 999,
                padding = { left = 12, right = 12 },
                background = w.focused and theme.ACCENT_SUBTLE or theme.SURFACE,
                opacity = 1,
                animate = {
                    opacity = { duration = theme.animation_very_slow_ms, from = 0 },
                    background = theme.animation_ms,
                    exit = { duration = theme.animation_very_slow_ms, opacity = 0, scale = 0.5 },
                },
                children = { row { width = "Fill", height = "Fill", align_v = "Center", spacing = theme.spacing.sm, children = {
                    text { content = w.app_id, foreground = w.focused and theme.ACCENT or theme.FG, font_size = theme.font.xs, max_width = 120, elide = "End", align_v = "Center" },
                    text { content = w.title, foreground = theme.DIM, font_size = theme.font.xs, width = "Fill", elide = "End", align_v = "Center" },
                } } },
            }
        end,
    },
}, { label(screen_line, INK_DIM, theme.font.xs) }, theme.GLASS)

---------------------------------------------------------------------------------------------------
-- The frosted pane drags over every island, so backdrop_blur is tried against each of them.

local PANE_W, PANE_H = 240, 120
local pane_x = state("fx_lab_x", 170)
local pane_y = state("fx_lab_y", 570)
local grab = { x = 0, y = 0, from_x = 0, from_y = 0 }

local pane = button {
    width = PANE_W,
    height = PANE_H,
    margin = computed({ pane_x, pane_y }, function(x, y) return { left = x, top = y } end),
    radius = theme.radius.lg,
    background = TINT,
    backdrop_blur = sigma,
    border_width = 1,
    border_color = "#ffffff66",
    shadow_color = "#000000aa",
    shadow_blur = 18,
    shadow_offset = { x = 0, y = 8 },
    cursor = "grab",
    on_drag = function(rect, pointer, phase)
        local x, y = rect.x + pointer.x, rect.y + pointer.y
        if phase == "start" then
            grab.x, grab.y, grab.from_x, grab.from_y = x, y, pane_x:get(), pane_y:get()
            return
        end
        pane_x:set(math.floor(math.max(0, math.min(WIN_W - PANE_W, grab.from_x + x - grab.x)) + 0.5))
        pane_y:set(math.floor(math.max(0, math.min(WIN_H - PANE_H, grab.from_y + y - grab.y)) + 0.5))
    end,
    children = {
        column {
            align_h = "Center",
            align_v = "Center",
            spacing = 4,
            children = {
                -- Red, so a pill visibly covers it: white under translucent white composites to
                -- the same white either way.
                label("Frosted pane", "#ff3b3b", theme.font.lg),
                label("drag me anywhere", INK_DIM, theme.font.xs),
            },
        },
    },
}

---------------------------------------------------------------------------------------------------
-- Once a second: the renderer's CPU, and a new palette when the wallpaper changed.

local cpu = state("fx_cpu", "renderer CPU …")
local last_ticks, last_picture
local function sample()
    local stat = ""
    -- This instance's renderer, not whichever `mantle-renderer` pgrep finds first.
    process.run("sh", { "-c", "cat /proc/$(pgrep -P " .. mantle.pid .. " -x mantle-renderer)/stat" },
        function(line) stat = line end, function()
            -- utime and stime, the 14th and 15th fields, counted after the parenthesised name.
            local fields = {}
            for field in stat:gsub("^.*%) ", ""):gmatch("%S+") do
                fields[#fields + 1] = field
            end
            local ticks = (tonumber(fields[12]) or 0) + (tonumber(fields[13]) or 0)
            if last_ticks then
                cpu:set(string.format("renderer CPU %.0f%%", ticks - last_ticks))
            end
            last_ticks = ticks
        end)
    if picture:get() ~= last_picture then
        last_picture = picture:get()
        quantize()
    end
    timer(1000, sample)
end
timer(1000, sample)

---------------------------------------------------------------------------------------------------
-- Window: a compositor-moved toplevel (Super+drag); Hyprland floats it by its app_id.

return { window {
    id = "fx_demo",
    title = "Mantle effects demo",
    app_id = "mantle-fx-demo",
    on_close = function() process.detach("mantle", { "stop", "--pid", tostring(mantle.pid) }) end,
    min_size = { width = WIN_W, height = WIN_H },
    background = theme.CRUST,
    child = rect {
        width = "Fill",
        height = "Fill",
        children = {
            image { source = picture, width = "Fill", height = "Fill", fit = "cover", async = true },
            column {
                width = "Fill",
                height = "Fill",
                padding = PAD,
                spacing = GAP,
                children = {
                    row {
                        width = "Fill",
                        height = HEADER_H,
                        align_v = "Center",
                        spacing = theme.spacing.md,
                        children = {
                            glass {
                                radius = 999,
                                padding = { left = 14, right = 14, top = 5, bottom = 5 },
                                children = { label("Mantle effects demo", INK, theme.font.md) },
                            },
                            rect { width = "Fill" },
                            badge(cpu),
                        },
                    },
                    row { width = "Fill", spacing = GAP, children = { shader_island, shadow_island, gradient_island } },
                    row { width = "Fill", spacing = GAP, children = { capture_island, palette_island, windows_island } },
                },
            },
            pane,
        },
    },
} }
