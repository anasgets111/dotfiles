-- Voxtype's dictation: `phase` follows `voxtype status --follow`, and while it records `levels`
-- holds BARS mic peaks in 0..1, oldest first, read from the daemon's own level socket.
local dictation = {}

dictation.BARS = 20
local RETRY_MS = 3000

-- `idle`, `recording`, `transcribing`, or `""` before the first line or without the daemon.
dictation.phase = state("dictation_phase", "")
dictation.levels = state("dictation_levels", {})
local began_at = state("dictation_began_at", 0)

dictation.active = dictation.phase:map(function(phase)
    return phase ~= "" and phase ~= "idle"
end)

dictation.elapsed_text = computed({ mantle.system, began_at }, function(system, began)
    local seconds = math.max(0, ((system and system.monotonic) or 0) - began)
    return string.format("%d:%02d", seconds // 60, seconds % 60)
end)

-- `audio.sock` streams 16-byte native frames `{ u32 seq, f32 min, f32 max, f32 peak_dbfs }` at
-- 100 Hz. The loudest peak of every three, -30..-6 dBFS as 0..100, joins a rolling window per line.
-- ponytail: tuned to a quiet room (-39..-29) at 27% mic gain; another mic or gain moves both ends.
local BRIDGE = [[
import os, socket, struct, sys
bars = [0] * int(sys.argv[1])
s = socket.socket(socket.AF_UNIX)
s.connect(os.environ["XDG_RUNTIME_DIR"] + "/voxtype/audio.sock")
f = s.makefile("rb")
while len(chunk := f.read(48)) == 48:
    loud = max(struct.unpack("@" + "Ifff" * 3, chunk)[3::4])
    bars = bars[1:] + [round(min(max((loud + 30) / 24, 0), 1) * 100)]
    print(*bars, flush=True)
]]

local meter
local function sync_meter(on)
    if meter then
        meter:kill()
    end
    dictation.levels:set({})
    if not on then
        return
    end
    meter = process.run("python3", { "-c", BRIDGE, tostring(dictation.BARS) }, function(line, stream)
        if stream == "stderr" then
            log.warn("dictation meter:", line)
            return
        end
        local frame = {}
        for digits in line:gmatch("%d+") do
            frame[#frame + 1] = tonumber(digits) / 100
        end
        dictation.levels:set(frame)
    end, function()
        meter = nil
    end)
end

dictation.phase:on_change(function(phase, previous)
    if (phase == "recording") == (previous == "recording") then
        return
    end
    if phase == "recording" then
        began_at:set(((mantle.system:get() or {}).monotonic) or 0)
    end
    sync_meter(phase == "recording")
end)
-- A reload mid-recording keeps `phase` and `began_at` but not this generation's bridge.
sync_meter(dictation.phase:get() == "recording")

local function follow()
    process.run("voxtype", { "status", "--follow", "--format", "json" }, function(line, stream)
        local phase = stream == "stdout" and line:match('"alt":%s*"(%w+)"')
        if phase then
            dictation.phase:set(phase)
        end
    end, function(code)
        -- `nil` is a reload's kill or a failed spawn; anything else is the daemon going away.
        if code ~= nil then
            dictation.phase:set("")
            timer(RETRY_MS, follow)
        end
    end)
end
follow()

return dictation
