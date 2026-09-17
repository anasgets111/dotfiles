-- Wallpaper state: file and fit per output, file source, and two writes. Drawing, picking, and the
-- bar button live in `modules/global/wallpaper.lua`,
-- `modules/global/wallpaper_picker.lua`, and `modules/bar/indicators/wallpaper_button.lua`.
-- One `wallpapers` key in `lib/store.lua`, a `{ path, fit }` table per output. It survives reload and reboot.
-- `mantle.files` watches `FOLDER` with inotify. Start watching during evaluation because
-- the folder is a setting, not state; picker and bar right-click need its list before opening.
local store = require("lib.store")

local wallpaper = {}

wallpaper.FOLDER = "/mnt/Work/1Wallpapers/Main"
-- Exclude `gif`: decoder supports none; folders often contain it.
wallpaper.EXTENSIONS = { "jpg", "jpeg", "png", "webp" }
-- Reduced to `image.fit`; omit `center` and `tile` because the engine draws
-- neither.
wallpaper.FITS = {
    { value = "cover",   label = "Fill" },
    { value = "contain", label = "Fit" },
    { value = "stretch", label = "Stretch" },
}
wallpaper.DEFAULT_FIT = "cover"
-- Transitions come from the config's shader files. The engine supplies cross-dissolve and
-- fragment-shader support and does not know this directory; `mantle.files` lists its
-- `.frag` files before the picker opens.
wallpaper.SHADER_FOLDER = mantle.config_dir .. "/shaders"
wallpaper.SHADER_EXTENSIONS = { "frag" }
wallpaper.NO_SHADER = "fade"
wallpaper.TRANSITION_MS = 1500
-- Not `InOutCubic`: 99.6% done at t=0.9, so its last 150ms stalls.
wallpaper.TRANSITION_EASING = "InOutSine"

-- A wipe picks a side; a disc and portal a centre; stripes pick a count and angle. A shader with
-- no row here -- anything dropped into the folder -- runs with every uniform at zero; adding a row
-- gives it knobs.
local RANDOM_PARAMS = {
    wipe = function()
        return { direction = math.floor(math.random() * 4), softness = 0.1 }
    end,
    disc = function()
        return { center_x = math.random(), center_y = math.random(), softness = 0.1 }
    end,
    portal = function()
        return { center_x = math.random(), center_y = math.random(), softness = 0.1 }
    end,
    stripes = function()
        return { count = math.random(4, 24), angle = math.random() * 360, softness = 0.1 }
    end,
    pixelate = function()
        return { softness = 0.35 }
    end,
}

---The watched shader folder from the last `mantle.files` push, or `nil` before the first.
---@param f FilesState|nil
---@return Folder|nil
function wallpaper.shader_folder_in(f)
    return f and f.folders and f.folders[wallpaper.SHADER_FOLDER] or nil
end

---Effect names from one `mantle.files` push: the built-in first, then a name per `.frag`. These
---files carry no affix to strip.
---@param f FilesState|nil
---@return string[]
function wallpaper.effects_in(f)
    local names = { wallpaper.NO_SHADER }
    local folder = wallpaper.shader_folder_in(f)
    for _, entry in ipairs(folder and folder.entries or {}) do
        names[#names + 1] = (entry.name:gsub("%.frag$", ""))
    end
    return names
end

---The stored effect if the folder still holds it, else the built-in.
---@param stored string|nil
---@param available string[]
---@return string
function wallpaper.effect_in(stored, available)
    for _, name in ipairs(available) do
        if name == stored then
            return name
        end
    end
    return wallpaper.NO_SHADER
end

function wallpaper.effects()
    return mantle.files:map(wallpaper.effects_in)
end

function wallpaper.effect()
    return computed({ store.wallpaper_transition, mantle.files }, function(stored, f)
        return wallpaper.effect_in(stored, wallpaper.effects_in(f))
    end)
end

---@param name string
function wallpaper.set_effect(name)
    if type(name) == "string" and name ~= "" and store.wallpaper_transition:get() ~= name then
        store:set("wallpaper_transition", name)
    end
end

---The `transition` table for the wallpaper `image`, as a signal.
---Depends on the stored wallpapers as well as the effect, so the parameters are drawn again on
---every wallpaper change the way `randomize` is called per change. A run already under way keeps
---the parameters it started with, because the engine copies the spec when it starts.
function wallpaper.transition()
    return computed({ wallpaper.effect(), store.wallpapers }, function(effect, _w)
        if effect == wallpaper.NO_SHADER then
            return { duration = wallpaper.TRANSITION_MS, easing = wallpaper.TRANSITION_EASING }
        end
        local params = RANDOM_PARAMS[effect]
        return {
            duration = wallpaper.TRANSITION_MS,
            easing = wallpaper.TRANSITION_EASING,
            shader = wallpaper.SHADER_FOLDER .. "/" .. effect .. ".frag",
            params = params and params() or nil,
        }
    end)
end

-- File shipped beside `shell.lua`.
wallpaper.DEFAULT = mantle.config_dir .. "/wallpaper.svg"

local function is_fit(value)
    for _, fit in ipairs(wallpaper.FITS) do
        if fit.value == value then
            return true
        end
    end
    return false
end

-- ponytail: a deleted file draws only the ground; the VM has no `io`, so only `FOLDER` is checked.
local function missing_in(f, path)
    local folder = wallpaper.folder_in(f)
    if not folder or not folder.ready or path:match("^(.*)/") ~= wallpaper.FOLDER then
        return false
    end
    for _, entry in ipairs(folder.entries) do
        if entry.path == path then
            return false
        end
    end
    return true
end

---Path for `output` from one stored `wallpapers` table. Pure for one `computed` over every screen.
---@param w table|nil The `wallpapers` table, or `nil` before the first push.
---@param output string
---@param f FilesState|nil
---@return string
function wallpaper.path_in(w, output, f)
    local stored = w and w[output] and w[output].path
    if type(stored) == "string" and stored ~= "" and not missing_in(f, stored) then
        return stored
    end
    return wallpaper.DEFAULT
end

---@param w table|nil
---@param output string
---@return string
function wallpaper.fit_in(w, output)
    local stored = w and w[output] and w[output].fit
    if type(stored) == "string" and is_fit(stored) then
        return stored
    end
    return wallpaper.DEFAULT_FIT
end

function wallpaper.all()
    return store.wallpapers
end

---@param output string
function wallpaper.path_of(output)
    return computed({ store.wallpapers, mantle.files }, function(w, f)
        return wallpaper.path_in(w, output, f)
    end)
end

---@param output string
function wallpaper.fit_of(output)
    return store.wallpapers:map(function(w)
        return wallpaper.fit_in(w, output)
    end)
end

---Merge `changes` into one output and store a copied whole table. Mutating the signal's last-pushed
---table would change `computed` input without marking the scene dirty.
---@param output string
---@param changes table
local function write(output, changes)
    local stored = store.wallpapers:get() or {}
    local merged = {}
    for name, entry in pairs(stored) do
        merged[name] = entry
    end
    local entry = {}
    for key, value in pairs(merged[output] or {}) do
        entry[key] = value
    end
    for key, value in pairs(changes) do
        entry[key] = value
    end
    merged[output] = entry
    store:set("wallpapers", merged)
end

---Skip unchanged writes because every write pushes.
---@param output string
---@param path string
function wallpaper.set(output, path)
    if path == "" or missing_in(mantle.files:get(), path) or wallpaper.path_in(store.wallpapers:get(), output) == path then
        return
    end
    write(output, { path = path })
end

---@param output string
---@param fit string
function wallpaper.set_fit(output, fit)
    if not is_fit(fit) or wallpaper.fit_in(store.wallpapers:get(), output) == fit then
        return
    end
    write(output, { fit = fit })
end

---Watched folder from the last `mantle.files` push, or `nil` before the first.
---@param f FilesState|nil
---@return Folder|nil
function wallpaper.folder_in(f)
    return f and f.folders and f.folders[wallpaper.FOLDER] or nil
end

---Connector names of every screen.
---@return string[]
function wallpaper.outputs()
    local names = {}
    for _, screen in ipairs(mantle.screens:get() or {}) do
        if screen.name and screen.name ~= "" then
            names[#names + 1] = screen.name
        end
    end
    return names
end

---One folder draw per screen. No-op before the listing lands or when it is empty.
function wallpaper.randomize_all()
    local folder = wallpaper.folder_in(mantle.files:get())
    local entries = folder and folder.entries or {}
    if #entries == 0 then
        return
    end
    for _, output in ipairs(wallpaper.outputs()) do
        wallpaper.set(output, entries[math.random(#entries)].path)
    end
end

-- `mantle call wallpaper.set [PATH]` sets PATH on every screen, or a random wallpaper per screen.
action("wallpaper.set", function(path)
    if not path then
        return wallpaper.randomize_all()
    end
    for _, output in ipairs(wallpaper.outputs()) do
        wallpaper.set(output, path)
    end
end)

mantle.files:invoke("watch", wallpaper.FOLDER, wallpaper.EXTENSIONS)
mantle.files:invoke("watch", wallpaper.SHADER_FOLDER, wallpaper.SHADER_EXTENSIONS)

return wallpaper
