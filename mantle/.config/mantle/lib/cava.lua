-- Cava's spectrum while a player plays: `levels` holds BARS numbers in 0..1, zeros otherwise, and
-- `levels.frame` counts frames so a shader can move with the music and stop with it.
local cava = {}

-- `config/cava` sets the same count; both `shaders/cava_*.frag` pack it four to a `vec4`.
cava.BARS = 256
local RETRY_MS = 3000
-- ponytail: the drift jumps once per wrap (55 min at 30 fps), so the shader's float32 phase keeps
-- sub-milliradian steps. A phase computed in Lua modulo each line's period is the upgrade.
local FRAME_WRAP = 100000

local ZERO = {}
for index = 1, cava.BARS do
    ZERO[index] = 0
end

-- A table seed never re-seeds, so a reload keeps the last frame until `sync` writes.
cava.levels = state("cava_levels", ZERO)

local function playing(mpris)
    for _, player in ipairs((mpris and mpris.players) or {}) do
        if player.play_state == "Playing" then
            return true
        end
    end
    return false
end
cava.playing = mantle.mpris:map(playing)

local child
local frames = 0

local function sync(on)
    if not on then
        if child then
            child:kill()
        end
        cava.levels:set(ZERO)
        return
    end
    if child then
        return
    end
    child = process.run("cava", { "-p", mantle.config_dir .. "/config/cava" }, function(line, stream)
        if stream == "stderr" then
            log.warn("cava:", line)
            return
        end
        local frame, count = {}, 0
        for digits in line:gmatch("%d+") do
            count = count + 1
            frame[count] = tonumber(digits) / 1000
        end
        if count == cava.BARS then
            frames = frames % FRAME_WRAP + 1
            frame.frame = frames
            cava.levels:set(frame)
        end
    end, function(code)
        child = nil
        cava.levels:set(ZERO)
        -- `nil` is a kill or a failed spawn, which the engine logs; a nonzero exit retries.
        if code ~= nil then
            log.warn("cava exited with", code)
            timer(RETRY_MS, function() sync(playing(mantle.mpris:get())) end)
        end
    end)
end

mantle.mpris:on_change(function(mpris) sync(playing(mpris)) end)
sync(playing(mantle.mpris:get()))

return cava
