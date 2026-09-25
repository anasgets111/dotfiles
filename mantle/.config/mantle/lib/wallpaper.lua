-- File and fit per output, stored as one `{ path, fit }` table per output under `wallpapers`.
-- Drawing and picking live in `modules/global/wallpaper{,_picker}.lua`. The `mantle.files` watches
-- start during evaluation, so the picker and the bar's right-click have their listings before they open.
local store = require("lib.store")
local util = require("lib.util")

local wallpaper = {}

wallpaper.FOLDER = "/mnt/Work/1Wallpapers/Main"
-- `image.fit` values; the engine draws neither `center` nor `tile`.
wallpaper.FITS = {
    { value = "cover",   label = "Fill" },
    { value = "contain", label = "Fit" },
    { value = "stretch", label = "Stretch" },
}
-- The engine supplies cross-dissolve and fragment-shader support but knows nothing of this folder.
wallpaper.SHADER_FOLDER = mantle.config_dir .. "/shaders"
wallpaper.NO_SHADER = "fade"

-- A shader with no row here, such as anything dropped into the folder, runs with every uniform at
-- zero. A row gives it knobs.
local function random_center()
    return { center_x = math.random(), center_y = math.random(), softness = 0.1 }
end

local RANDOM_PARAMS = {
    wipe = function()
        return { direction = math.floor(math.random() * 4), softness = 0.1 }
    end,
    disc = random_center,
    portal = random_center,
    stripes = function()
        return { count = math.random(4, 24), angle = math.random() * 360, softness = 0.1 }
    end,
    pixelate = function()
        return { softness = 0.35 }
    end,
}

---Effect names from one `mantle.files` push: the built-in first, then a name per `.frag`.
---@param files FilesState|nil
---@return string[]
function wallpaper.effects_in(files)
    local names = { wallpaper.NO_SHADER }
    ---@type Folder?
    local folder = files and files.folders and files.folders[wallpaper.SHADER_FOLDER]
    for _, entry in ipairs(folder and folder.entries or {}) do
        names[#names + 1] = (entry.name:gsub("%.frag$", ""))
    end
    return names
end

function wallpaper.effects()
    return mantle.files:map(wallpaper.effects_in)
end

-- The stored effect if the folder still holds it, else the built-in.
function wallpaper.effect()
    return computed({ store.wallpaper_transition, mantle.files }, function(stored, files)
        for _, name in ipairs(wallpaper.effects_in(files)) do
            if name == stored then
                return name
            end
        end
        return wallpaper.NO_SHADER
    end)
end

function wallpaper.set_effect(name)
    if type(name) == "string" and name ~= "" and store.wallpaper_transition:get() ~= name then
        store:set("wallpaper_transition", name)
    end
end

---The `transition` table for the wallpaper `image`. It depends on the stored wallpapers too, so
---every change draws fresh parameters; a run under way keeps the spec the engine copied.
function wallpaper.transition()
    return computed({ wallpaper.effect(), store.wallpapers }, function(effect)
        -- Not `InOutCubic`: 99.6% done at t=0.9, so its last 150ms stalls.
        local spec = { duration = 1500, easing = "InOutSine" }
        if effect ~= wallpaper.NO_SHADER then
            local params = RANDOM_PARAMS[effect]
            spec.shader = wallpaper.SHADER_FOLDER .. "/" .. effect .. ".frag"
            spec.params = params and params() or nil
        end
        return spec
    end)
end

local function is_fit(value)
    for _, fit in ipairs(wallpaper.FITS) do
        if fit.value == value then
            return true
        end
    end
    return false
end

-- ponytail: a deleted file draws only the ground; the VM has no `io`, so only `FOLDER` is checked.
local function missing_in(files, path)
    local folder = wallpaper.folder_in(files)
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
---@param wallpapers table|nil The `wallpapers` table, or `nil` before the first push.
---@param output string
---@param files FilesState|nil
---@return string
function wallpaper.path_in(wallpapers, output, files)
    local stored = wallpapers and wallpapers[output] and wallpapers[output].path
    if type(stored) == "string" and stored ~= "" and not missing_in(files, stored) then
        return stored
    end
    -- Shipped beside `shell.lua`.
    return mantle.config_dir .. "/wallpaper.svg"
end

function wallpaper.fit_in(wallpapers, output)
    local stored = wallpapers and wallpapers[output] and wallpapers[output].fit
    if type(stored) == "string" and is_fit(stored) then
        return stored
    end
    return "cover"
end

function wallpaper.path_of(output)
    return computed({ store.wallpapers, mantle.files }, function(wallpapers, files)
        return wallpaper.path_in(wallpapers, output, files)
    end)
end

function wallpaper.fit_of(output)
    return store.wallpapers:map(function(wallpapers)
        return wallpaper.fit_in(wallpapers, output)
    end)
end

---Set all outputs in one write: the stored signal updates only on the next push.
local function write(outputs, key, value, read)
    local stored = store.wallpapers:get() or {}
    local next_value = stored
    for _, output in ipairs(outputs) do
        local selected = type(value) == "function" and value() or value
        if read(stored, output) ~= selected then
            next_value = util.with(next_value, output, util.with(next_value[output], key, selected))
        end
    end
    if next_value ~= stored then
        store:set("wallpapers", next_value)
    end
end

function wallpaper.set(outputs, path)
    if path == "" or missing_in(mantle.files:get(), path) then
        return
    end
    write(outputs, "path", path, wallpaper.path_in)
end

function wallpaper.set_fit(outputs, fit)
    if not is_fit(fit) then
        return
    end
    write(outputs, "fit", fit, wallpaper.fit_in)
end

---Watched folder from the last `mantle.files` push, or `nil` before the first.
---@param files FilesState|nil
---@return Folder|nil
function wallpaper.folder_in(files)
    return files and files.folders and files.folders[wallpaper.FOLDER] or nil
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
    write(wallpaper.outputs(), "path", function()
        return entries[math.random(#entries)].path
    end, wallpaper.path_in)
end

-- `mantle call wallpaper.set [PATH]` sets PATH on every screen, or a random wallpaper per screen.
action("wallpaper.set", function(path)
    if not path then
        return wallpaper.randomize_all()
    end
    wallpaper.set(wallpaper.outputs(), path)
end)

-- `gif` animates (ADR-0233); one too long for the engine's frame budget draws as a still.
mantle.files:watch(wallpaper.FOLDER, { "jpg", "jpeg", "png", "webp", "gif" })
mantle.files:watch(wallpaper.SHADER_FOLDER, { "frag" })

return wallpaper
