-- Wallpaper colours for the shell and apps. The first screen's wallpaper, quantized and scored, gives
-- one seed; `theme.roles` turns it into Material roles that fill `templates/`, then
-- `config/wallpaper_colours.lua` for the shell, whose write reloads it. `store.colour_scheme` picks
-- dark or light and is pushed to the portal, so every toolkit follows it. Writes skip unchanged
-- bytes, so the reload settles in one round. Nothing running flashes: GTK3 and Qt switch to a second
-- copy of the colours instead of passing through a stand-in theme or scheme.
local store = require("lib.store")
local theme = require("config.theme")
local wallpaper = require("lib.wallpaper")
local util = require("lib.util")
local presets = require("config.colour_presets")

local app_colours = {
    -- Up to four seeds Score found in the first screen's wallpaper, best first, for the picker's swatches.
    candidates = state("colour_candidates", {}),
    -- The seed in use: a chosen candidate, else the best.
    seed = state("colour_seed", ""),
}

local HOME = os.getenv("HOME") or ""
local TEMPLATES = mantle.config_dir .. "/templates/"
-- Catppuccin mauve, for a wallpaper that cannot be quantized (the shipped SVG).
local FALLBACK_SEED = "#CBA6F7"
-- A preset's accents, in swatch order.
local PRESET_ACCENTS = { "mauve", "blue", "teal", "green", "yellow", "peach", "red", "pink" }
local INTERFACE = "org.gnome.desktop.interface"
local QT6CT = "~/.config/qt6ct/qt6ct.conf"
local SCHEMES = HOME .. "/.local/share/color-schemes/"
-- `out` gets the rendered template; `reload` is detached when its bytes changed, so the shell
-- reload this run ends in cannot kill it. `gtk4` asks for libadwaita's refresh. `compositor` writes
-- only under that compositor, so the other's config directory is never created; both reload
-- included files themselves. GTK3 and Qt have their own writers below.
local TARGETS = {
    { template = "gtk4.css",         out = "~/.config/gtk-4.0/gtk.css",                   gtk4 = true },
    { template = "gtk4-colours.css", out = "~/.config/gtk-4.0/mantle-colours.css",        gtk4 = true },
    { template = "kitty.conf",       out = "~/.config/kitty/mantle-colours.conf",         reload = { "pkill", { "-USR1", "-x", "kitty" } } },
    -- SIGUSR2 makes btop re-read its config, theme included; its `color_theme` names `mantle`.
    { template = "btop.theme",       out = "~/.config/btop/themes/mantle.theme",          reload = { "pkill", { "-USR2", "-x", "btop" } } },
    { template = "hypr.lua",         out = "~/.config/hypr/config/wallpaper_colours.lua", compositor = "hyprland" },
    { template = "niri.kdl",         out = "~/.config/niri/wallpaper-colours.kdl",        compositor = "niri" },
    -- GtkSourceView never rescans its schemes, so a running GNOME Text Editor keeps the old one.
    {
        template = "sourceview.xml",
        out = "~/.local/share/gtksourceview-5/styles/mantle.xml",
        reload = { "gsettings", { "set", "org.gnome.TextEditor", "style-scheme", "mantle" } },
    },
    { template = "vesktop.css",   out = "~/.config/vesktop/themes/mantle.css" },
    -- Zed reloads its themes directory live; its settings name `Mantle` for both modes.
    { template = "zed.json",      out = "~/.config/zed/themes/mantle.json" },
    -- Starship and fish re-read at the next prompt; fish through `conf.d/mantle_theme.fish`.
    { template = "starship.toml", out = "~/.config/starship.toml" },
    { template = "fish.theme",    out = "~/.config/fish/themes/mantle.theme" },
    -- Every Neovim already on `mantle` re-sources it.
    {
        template = "nvim.lua",
        out = "~/.local/share/nvim/site/colors/mantle.lua",
        reload = { "sh", { "-c", [[
for server in "$XDG_RUNTIME_DIR"/nvim.*; do
nvim --server "$server" --remote-expr "execute(get(g:, 'colors_name', '') == 'mantle' ? 'colorscheme mantle' : '')"
done >/dev/null 2>&1]] } }
    },
}
-- GTK4 re-parses `gtk.css` with its imports when a portal preference changes. Reduced motion is the
-- one whose 50 ms flip shows nothing; detached, so a shell reload cannot strand the user's value.
local LIBADWAITA_REFRESH = [[k="org.gnome.desktop.a11y.interface reduced-motion"; v=$(gsettings get $k)
gsettings set $k "$([ "$v" = "'reduce'" ] && echo no-preference || echo reduce)"; sleep 0.05; gsettings set $k "$v"]]

-- `{{role}}` is `#RRGGBB`, `{{role.rgb}}` is `r, g, b` (KDE), `{{role.bare}}` is `RRGGBB` (Hyprland).
-- A role that is not a colour is inserted as is.
local function render(template, roles)
    return (template:gsub("{{%s*([%w_]+)%.?(%w*)%s*}}", function(role, format)
        local hex = roles[role]
        if not hex or hex:sub(1, 1) ~= "#" then
            return hex
        end
        if format == "rgb" then
            return string.format("%d, %d, %d", tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16),
                tonumber(hex:sub(6, 7), 16))
        end
        return format == "bare" and hex:sub(2) or hex
    end))
end

-- Writes only a changed value: every write makes Electron apps redraw.
local function gsettings(schema, key, value, after)
    process.capture("gsettings", { "get", schema, key }, function(current)
        if current and current:match("^'(.*)'") == value then
            return after()
        end
        process.capture("gsettings", { "set", schema, key, value }, function() after() end)
    end)
end

-- Writes `{ path, text }` pairs in order, then `done(true)`; a failed write stops with `done(false)`,
-- so nothing is pointed at a half-written copy.
local function write_files(files, done, index)
    index = index or 1
    if not files[index] then
        return done(true)
    end
    file.write(files[index][1], files[index][2], nil, function(_, write_error)
        if write_error then
            log.warn("app colours:", write_error)
            return done(false)
        end
        write_files(files, done, index + 1)
    end)
end

-- An app holding `Mantle-A` reloads only when pointed at `Mantle-B`, and back. `in_use` names the copy
-- in use; when `path_of(that copy)` already holds `text` it stays, else `write(other, done)` fills the
-- other. `done(name)` gets the copy to point at, or nothing after a failed write.
local function alternate(in_use, path_of, text, write, done)
    local current = in_use and in_use:match("Mantle%-[AB]")
    local other = current == "Mantle-A" and "Mantle-B" or "Mantle-A"
    local function switch()
        write(other, function(ok) done(ok and other or nil) end)
    end
    if not current then
        return switch()
    end
    file.read(path_of(current), function(old)
        if old == text then
            return done(current)
        end
        switch()
    end)
end

-- GTK3 re-reads a theme only when its name changes. Each copy imports adw-gtk3 and replaces its named
-- colours, libadwaita's from `colours` as `@define-color`; dark mode reads `gtk-dark.css`, and GTK4
-- apps without libadwaita the `gtk-4.0` files.
local function write_gtk_theme(template, colours, roles, done)
    local themes = HOME .. "/.local/share/themes/"
    local defines = {}
    for name, value in render(colours, roles):gmatch("%-%-([%w-]+): ([^;]+);") do
        defines[#defines + 1] = string.format("@define-color %s %s;", (name:gsub("-", "_")), value)
    end
    roles.adw_colours = table.concat(defines, "\n")
    roles.gtk = "gtk-3.0"
    local gtk3 = render(template, roles)
    roles.gtk = "gtk-4.0"
    local gtk4 = render(template, roles)
    process.capture("gsettings", { "get", INTERFACE, "gtk-theme" }, function(in_use)
        alternate(in_use, function(name) return themes .. name .. "/gtk-3.0/gtk.css" end, gtk3, function(name, written)
            local dir = themes .. name
            -- `gtk-3.0/gtk.css` last: it is the file a later run compares.
            write_files({
                { dir .. "/gtk-3.0/gtk-dark.css", gtk3 },
                { dir .. "/gtk-4.0/gtk-dark.css", gtk4 },
                { dir .. "/gtk-4.0/gtk.css",      gtk4 },
                { dir .. "/gtk-3.0/gtk.css",      gtk3 },
            }, written)
        end, function(name)
            if not name then
                return done()
            end
            gsettings(INTERFACE, "gtk-theme", name, done)
        end)
    end)
end

-- KSharedConfig caches a KDE scheme by path, so Qt and Kirigami apps reload only under a new name.
-- qt6ct's directory watch sees the atomic rewrite of its config.
local function write_qt_scheme(text, done)
    file.read(QT6CT, function(conf, read_error)
        if not conf and not tostring(read_error):match("No such file") then
            log.warn("app colours:", read_error)
            return done()
        end
        conf = conf or ""
        alternate(conf:match("color_scheme_path=[^\n]*"), function(name) return SCHEMES .. name .. ".colors" end, text,
            function(name, written)
                local path = "color_scheme_path=" .. SCHEMES .. name .. ".colors"
                local updated, count = conf:gsub("color_scheme_path=[^\n]*", path, 1)
                -- Breeze paints with the palette; a Kvantum theme keeps its own colours.
                updated = updated:gsub("\nstyle=kvantum[^\n]*", "\nstyle=Breeze"):gsub("custom_palette=false",
                    "custom_palette=true")
                if count == 0 then
                    updated = updated .. "\n[Appearance]\n" .. path .. "\ncustom_palette=true\nstyle=Breeze\n"
                end
                write_files({ { SCHEMES .. name .. ".colors", text }, { QT6CT, updated } }, written)
            end, function() done() end)
    end)
end

-- One run at a time, so an older run's writes never land after a newer one's. A change during a run
-- waits for it: the shell-file write reloads the shell, whose fresh `sync` sees it, or `finish` re-syncs.
local running, rerun = false, false
local sync

-- `record` is the Lua table `config/wallpaper_colours.lua` returns, so the shell rebuilds the same roles.
local function apply(roles, dark, record, compositor)
    -- kitty's black and white swap on light so prompts stay readable.
    roles.ansi_black = dark and roles.surface_container_highest or roles.on_surface_variant
    roles.ansi_white = dark and roles.on_surface_variant or roles.surface_container_highest
    roles.adw = dark and "adw-gtk3-dark" or "adw-gtk3"
    roles.appearance = dark and "dark" or "light"
    -- A tone step away from the ground for kitty's bright colours; `inverse_` sits on `on_surface`,
    -- as Material's `inverse_primary` does, for starship's light segments; `tint_` is a muted line
    -- ground under `on_surface`, for Neovim's diff and search.
    for _, name in ipairs({ "primary", "red", "peach", "yellow", "green", "teal", "blue", "tertiary" }) do
        local hct = palette.hct(roles[name])
        roles["bright_" .. name] = palette.from_hct { hue = hct.hue, chroma = hct.chroma,
            tone = math.max(0, math.min(100, hct.tone + (dark and 8 or -8))) }
        roles["inverse_" .. name] = palette.from_hct { hue = hct.hue, chroma = hct.chroma, tone = dark and 40 or 80 }
        roles["tint_" .. name] = palette.from_hct { hue = hct.hue, chroma = hct.chroma / 2, tone = dark and 25 or 90 }
    end
    -- Bars and frames sit a step out from the content: darkest in dark mode, a darker container in
    -- light, where `surface_container_lowest` is the whitest.
    roles.chrome = roles[dark and "surface_container_lowest" or "surface_container_high"]
    -- Text on a status fill: the scheme's darkest or lightest ink, whichever reads.
    for _, name in ipairs({ "red", "yellow", "green" }) do
        roles["on_" .. name] = theme.text_contrast(roles[name], dark and roles.surface or roles.on_surface,
            dark and roles.on_surface or roles.surface)
    end
    -- Discord's button text is white in both modes, so its fill sits at tone 40.
    local accent = palette.hct(roles.primary)
    roles.brand_fill = palette.from_hct { hue = accent.hue, chroma = accent.chroma, tone = 40 }
    running = true
    -- Plus the GTK theme and the Qt scheme.
    local pending, gtk4_changed = #TARGETS + 2, false
    -- Last, since this write reloads the shell and drops every callback still pending.
    local function finish()
        file.write(mantle.config_dir .. "/config/wallpaper_colours.lua",
            "-- Generated by lib/app_colours.lua.\nreturn " .. record .. "\n", nil,
            function(changed)
                -- Changed reloads the shell, whose fresh `sync` sees anything that moved meanwhile.
                if changed then
                    return
                end
                running = false
                if rerun then
                    rerun = false
                    sync()
                end
            end)
    end
    local function settle()
        pending = pending - 1
        if pending > 0 then
            return
        end
        gsettings(INTERFACE, "color-scheme", dark and "prefer-dark" or "prefer-light", function()
            if gtk4_changed then
                process.detach("sh", { "-c", LIBADWAITA_REFRESH })
            end
            finish()
        end)
    end
    local function with_template(name, use)
        file.read(TEMPLATES .. name, function(template, read_error)
            if not template then
                log.warn("app colours:", read_error)
                return settle()
            end
            use(template)
        end)
    end
    with_template("gtk4-colours.css", function(colours)
        with_template("gtk-theme.css", function(template) write_gtk_theme(template, colours, roles, settle) end)
    end)
    with_template("mantle.colors", function(template) write_qt_scheme(render(template, roles), settle) end)
    for _, target in ipairs(TARGETS) do
        if target.compositor ~= nil and target.compositor ~= compositor then
            settle()
        else
            with_template(target.template, function(template)
                file.write(target.out, render(template, roles), nil, function(written, write_error)
                    if write_error then
                        log.warn("app colours:", write_error)
                    elseif written then
                        gtk4_changed = gtk4_changed or target.gtk4 == true
                        if target.reload then
                            process.detach(target.reload[1], target.reload[2])
                        end
                    end
                    settle()
                end)
            end)
        end
    end
end

local function first_path(screens)
    return wallpaper.path_in(store.wallpapers:get(), screens[1].name, mantle.folders:get())
end

local last, quantizing
function sync()
    if running then
        rerun = true
        return
    end
    local screens, workspaces = mantle.screens:get(), mantle.workspaces:get()
    if mantle.storage:get() == nil or screens == nil or screens[1] == nil then
        return
    end
    local path, dark, variant = first_path(screens), store.colour_scheme:get() ~= "light", store.colour_style:get()
    local contrast = store.colour_contrast:get() or 0
    local source = store.colour_source:get() or "wallpaper"
    local preset = presets[source]
    local chosen = (store[preset and "colour_preset_accents" or "colour_accents"]:get() or {})
        [preset and source or path]
    -- The compositor is part of the key: its border file waits until `workspaces` names it.
    local compositor = workspaces and workspaces.compositor
    -- A preset ignores the style and contrast, so changing them there is no new key.
    local key = table.concat({ source, path, tostring(dark), preset and "" or variant .. contrast, tostring(chosen),
        tostring(compositor) }, "|")
    if last == key then
        return
    end
    last = key
    if quantizing then
        quantizing:cancel()
    end
    if preset then
        local flavour = preset[dark and "dark" or "light"]
        local accent = flavour[chosen] and chosen or preset.default_accent
        -- A colour repeated across slots is one swatch.
        local candidates = {}
        for _, name in ipairs(PRESET_ACCENTS) do
            if not util.find(candidates, function(hex) return hex == flavour[name] end) then
                candidates[#candidates + 1] = flavour[name]
            end
        end
        app_colours.candidates:set(candidates)
        app_colours.seed:set(flavour[accent])
        return apply(theme.preset_roles(source, dark, accent), dark,
            string.format("{ preset = %q, accent = %q, dark = %s }", source, accent, dark), compositor)
    end
    local function start(candidates)
        local seed = chosen or candidates[1]
        -- A grey seed under any other variant takes an arbitrary hue at full chroma.
        local style = palette.hct(seed).chroma < 5 and "monochrome" or variant
        app_colours.candidates:set(candidates)
        app_colours.seed:set(seed)
        apply(theme.roles(seed, dark, style, contrast), dark,
            string.format("{ seed = %q, dark = %s, variant = %q, contrast = %s }", seed, dark, style, contrast),
            compositor)
    end
    if path:match("%.svg$") then
        return start({ FALLBACK_SEED })
    end
    quantizing = palette.quantize(path, { depth = 7 }, function(found)
        if not found or not found[1] then
            return start({ FALLBACK_SEED })
        end
        local seeds = palette.score(found)
        -- Score's stand-in when no swatch is chromatic; a grey wallpaper keeps its own commonest grey.
        if seeds[1] == "#4285F4" and not util.find(found, function(swatch) return swatch.color:upper() == "#4285F4" end) then
            seeds = { found[1].color }
        end
        start(seeds)
    end)
end

for _, signal in ipairs({ store.wallpapers, store.colour_source, store.colour_style, store.colour_contrast, store.colour_scheme,
    store.colour_accents, store.colour_preset_accents, mantle.screens, mantle.folders, mantle.workspaces }) do
    signal:on_change(sync)
end
sync()

-- `mantle call colours.mode` flips dark and light.
action("colours.mode", function()
    store:set("colour_scheme", store.colour_scheme:get() == "light" and "dark" or "light")
end)

---Keeps `seed` as the accent: by name for the preset in use, else for the first screen's wallpaper.
---The next run picks it up.
---@param seed string
function app_colours.set_accent(seed)
    local source, screens = store.colour_source:get() or "wallpaper", mantle.screens:get()
    local preset = presets[source]
    if preset then
        local flavour = preset[store.colour_scheme:get() == "light" and "light" or "dark"]
        local name = util.find(PRESET_ACCENTS, function(accent) return flavour[accent] == seed end)
        if name then
            store:set("colour_preset_accents", util.with(store.colour_preset_accents:get() or {}, source, name))
        end
    elseif screens and screens[1] then
        store:set("colour_accents", util.with(store.colour_accents:get() or {}, first_path(screens), seed))
    end
end

return app_colours
