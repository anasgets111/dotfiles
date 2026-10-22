-- Wallpaper colours for the shell and apps. The first screen's wallpaper, quantized and scored, gives
-- one seed; `theme.roles` turns it into Material roles that fill `templates/` for GTK, Qt/KDE, kitty
-- and Hyprland, then `config/wallpaper_colours.lua` for the shell, whose write reloads it.
-- `store.colour_scheme` picks dark or light and is pushed to the portal, so every toolkit follows it.
-- Writes skip unchanged bytes, so the reload settles in one round. Nothing running flashes: GTK3 and
-- Qt switch to a second copy of the colours instead of passing through a stand-in theme or scheme.
local store = require("lib.store")
local theme = require("config.theme")
local wallpaper = require("lib.wallpaper")

local HOME = os.getenv("HOME") or ""
local TEMPLATES = mantle.config_dir .. "/templates/"
-- Catppuccin mauve, for a wallpaper that cannot be quantized (the shipped SVG).
local FALLBACK_SEED = "#CBA6F7"
local INTERFACE = "org.gnome.desktop.interface"
-- `out` gets the rendered template; `reload` runs when its bytes changed, and `gtk4` asks for
-- libadwaita's refresh. `compositor` writes only under that compositor, so the other's config
-- directory is never created. GTK3 and Qt have their own writers below.
local TARGETS = {
    { template = "gtk4.css",         out = "~/.config/gtk-4.0/gtk.css",                   gtk4 = true },
    { template = "gtk4-colours.css", out = "~/.config/gtk-4.0/mantle-colours.css",        gtk4 = true },
    { template = "kitty.conf",       out = "~/.config/kitty/mantle-colours.conf",         reload = { "pkill", { "-USR1", "-x", "kitty" } } },
    { template = "hypr.lua",         out = "~/.config/hypr/config/wallpaper_colours.lua", reload = { "hyprctl", { "reload" } },            compositor = "hyprland" },
    -- niri reloads included files live.
    { template = "niri.kdl",         out = "~/.config/niri/wallpaper-colours.kdl",        compositor = "niri" },
    -- GtkSourceView never rescans its schemes, so a running GNOME Text Editor keeps the old one.
    {
        template = "sourceview.xml",
        out = "~/.local/share/gtksourceview-5/styles/mantle.xml",
        reload = { "gsettings", { "set", "org.gnome.TextEditor", "style-scheme", "mantle" } }
    },
    -- Vencord watches its themes directory, not Quick CSS: a file watch dies on an atomic write.
    { template = "vesktop.css", out = "~/.config/vesktop/themes/mantle.css" },
    -- Zed reloads its themes directory live; its settings name `Mantle` for both modes.
    { template = "zed.json",    out = "~/.config/zed/themes/mantle.json" },
}

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
        return format == "bare" and hex:sub(2, 7) or hex:sub(1, 7)
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

-- An app holding `Mantle-A` reloads only when pointed at `Mantle-B`, and back. `in_use` names the copy
-- in use, or nothing on a first run. `is_current(name, reply)` replies whether that copy already holds
-- the new colours; otherwise `write(name, written)` fills the other. `done(name)` gets the copy to use.
local function alternate(in_use, is_current, write, done)
    local current = in_use and in_use:match("Mantle%-[AB]")
    local other = current == "Mantle-A" and "Mantle-B" or "Mantle-A"
    local function switch()
        write(other, function() done(other) end)
    end
    if not current then
        return switch()
    end
    is_current(current, function(same)
        if same then
            return done(current)
        end
        switch()
    end)
end

-- GTK3 re-reads a theme only when its name changes. Each copy imports adw-gtk3 and replaces its named
-- colours; dark mode reads `gtk-dark.css`, and GTK4 apps without libadwaita the `gtk-4.0` copy.
local function write_gtk_theme(template, roles, done)
    local themes = HOME .. "/.local/share/themes/"
    roles.gtk = "gtk-3.0"
    local gtk3 = render(template, roles)
    roles.gtk = "gtk-4.0"
    local gtk4 = render(template, roles)
    process.capture("gsettings", { "get", INTERFACE, "gtk-theme" }, function(in_use)
        alternate(in_use, function(current, reply)
            file.read(themes .. current .. "/gtk-3.0/gtk.css", function(old) reply(old == gtk3) end)
        end, function(name, written)
            file.write(themes .. name .. "/gtk-3.0/gtk-dark.css", gtk3, function()
                file.write(themes .. name .. "/gtk-4.0/gtk.css", gtk4, function()
                    file.write(themes .. name .. "/gtk-3.0/gtk.css", gtk3, function() written() end)
                end)
            end)
        end, function(name)
            gsettings(INTERFACE, "gtk-theme", name, done)
        end)
    end)
end

-- KSharedConfig caches a KDE scheme by path, so Qt and Kirigami apps reload only under a new name.
-- qt6ct's directory watch sees the atomic rewrite of its config.
local function write_qt_scheme(text, done)
    local schemes, qt6ct = HOME .. "/.local/share/color-schemes/", "~/.config/qt6ct/qt6ct.conf"
    file.read(qt6ct, function(conf)
        conf = conf or ""
        alternate(conf:match("color_scheme_path=[^\n]*"), function(current, reply)
            file.read(schemes .. current .. ".colors", function(old) reply(old == text) end)
        end, function(name, written)
            file.write(schemes .. name .. ".colors", text, function()
                local path = "color_scheme_path=" .. schemes .. name .. ".colors"
                local updated, count = conf:gsub("color_scheme_path=[^\n]*", path, 1)
                -- Breeze paints with the palette; a Kvantum theme keeps its own colours.
                updated = updated:gsub("\nstyle=kvantum[^\n]*", "\nstyle=Breeze")
                if count == 0 then
                    updated = updated .. "\n[Appearance]\n" .. path .. "\ncustom_palette=true\nstyle=Breeze\n"
                end
                file.write(qt6ct, updated, function() written() end)
            end)
        end, function() done() end)
    end)
end

-- GTK4 re-parses `gtk.css`, imports included, when a portal preference changes. Reduced motion is the
-- one whose 50 ms flip changes nothing visible; the user's value is restored.
local function refresh_libadwaita(done)
    local schema = "org.gnome.desktop.a11y.interface"
    process.capture("gsettings", { "get", schema, "reduced-motion" }, function(value)
        local was = value and value:match("'reduce'") and "reduce" or "no-preference"
        gsettings(schema, "reduced-motion", was == "reduce" and "no-preference" or "reduce", function()
            timer(50, function()
                gsettings(schema, "reduced-motion", was, done)
            end)
        end)
    end)
end

-- One run at a time, so an older run's writes never land after a newer one's. A change during a run
-- waits for it: the shell-file write reloads the shell, whose fresh `sync` sees it, or `finish` re-syncs.
local running, rerun = false, false
local sync

local function apply(seed, dark)
    local roles = theme.roles(seed, dark)
    -- kitty's black and white swap on light so prompts stay readable.
    roles.ansi_black = dark and roles.surface_container_highest or roles.on_surface_variant
    roles.ansi_white = dark and roles.on_surface_variant or roles.surface_container_highest
    roles.adw = dark and "adw-gtk3-dark" or "adw-gtk3"
    roles.appearance = dark and "dark" or "light"
    -- Discord's white button text needs a deep fill on dark too.
    roles.brand_fill = dark and roles.primary_container or roles.primary
    running = true
    local workspaces = mantle.workspaces:get()
    local compositor = workspaces and workspaces.compositor
    local targets = {}
    for _, target in ipairs(TARGETS) do
        if target.compositor == nil or target.compositor == compositor then
            targets[#targets + 1] = target
        end
    end
    local pending, gtk4_changed = #targets + 2, false
    -- Last, since this write reloads the shell and drops every callback still pending.
    local function finish()
        file.write(mantle.config_dir .. "/config/wallpaper_colours.lua",
            string.format("-- Generated by lib/app_colours.lua.\nreturn { seed = %q, dark = %s }\n", seed, dark),
            function()
                -- Unchanged, so no reload re-runs `sync`: catch up with a change made meanwhile.
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
                return refresh_libadwaita(finish)
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
    with_template("gtk-theme.css", function(template) write_gtk_theme(template, roles, settle) end)
    with_template("mantle.colors", function(template) write_qt_scheme(render(template, roles), settle) end)
    for _, target in ipairs(targets) do
        with_template(target.template, function(template)
            file.write(target.out, render(template, roles), function(written, write_error)
                if write_error then
                    log.warn("app colours:", write_error)
                elseif written then
                    gtk4_changed = gtk4_changed or target.gtk4 == true
                    if target.reload then
                        process.run(target.reload[1], target.reload[2], function() end, function() end)
                    end
                end
                settle()
            end)
        end)
    end
end

local last, quantizing
function sync()
    local screens = mantle.screens:get()
    if mantle.storage:get() == nil or screens == nil or screens[1] == nil then
        return
    end
    local path = wallpaper.path_in(store.wallpapers:get(), screens[1].name, mantle.folders:get())
    local dark = store.colour_scheme:get() ~= "light"
    if running then
        rerun = true
        return
    end
    local workspaces = mantle.workspaces:get()
    -- The compositor is part of the key: its border file waits until `workspaces` names it.
    local key = path .. tostring(dark) .. tostring(workspaces and workspaces.compositor)
    if last == key then
        return
    end
    last = key
    if quantizing then
        quantizing:cancel()
    end
    if path:match("%.svg$") then
        return apply(FALLBACK_SEED, dark)
    end
    quantizing = palette.quantize(path, { depth = 7 }, function(found)
        apply(found and palette.score(found)[1] or FALLBACK_SEED, dark)
    end)
end

-- `mantle.storage` pushes every store write, wallpapers included; store keys have no `on_change`.
for _, signal in ipairs({ mantle.storage, mantle.screens, mantle.folders, mantle.workspaces }) do
    signal:on_change(sync)
end
sync()

-- `mantle call colours.mode` flips dark and light.
action("colours.mode", function()
    store:set("colour_scheme", store.colour_scheme:get() == "light" and "dark" or "light")
end)
