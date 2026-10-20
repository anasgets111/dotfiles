-- The one player the media panel, the bar and the media keys act on. A pick is kept by id, so a
-- player quitting never shifts the choice onto another. A player that starts playing takes over
-- unless the chosen one is playing too.
local util = require("lib.util")

local media = {}

local chosen = state("media_player_id", "")

local function pick(players, id)
    return util.find(players, function(player) return player.id == id end)
        or util.find(players, function(player) return player.play_state == "playing" end)
        or players[1]
        or false
end

media.selected = computed({ mantle.mpris, chosen }, function(mpris, id)
    return pick(mpris.players, id)
end, false)

function media.select(id)
    chosen:set(id)
end

local was_playing = {}
mantle.mpris:on_change(function(mpris)
    local players = (mpris and mpris.players) or {}
    local current = pick(players, chosen:get())
    local now = {}
    for _, player in ipairs(players) do
        now[player.id] = player.play_state == "playing"
        if now[player.id] and not was_playing[player.id] and not (current and current.play_state == "playing") then
            current = player
            chosen:set(player.id)
        end
    end
    was_playing = now
end)

-- ponytail: MPRIS names no pid, so a player matches its PipeWire streams by app name. Two instances
-- of one browser share every stream. Upgrade: match `apps[].pid` once `PlayerState` carries one.
media.streams = computed({ media.selected, mantle.audio }, function(player, audio)
    if not player then
        return {}
    end
    local names = {}
    for _, name in ipairs({ player.desktop_entry, player.id:match("^[^.]+"), player.identity }) do
        if name ~= "" then
            names[name:lower()] = true
        end
    end
    local matched = {}
    for _, app in ipairs(audio.apps) do
        if not app.recording and util.find({ "binary", "process_name", "name", "icon" }, function(field)
                return app[field] and names[app[field]:lower()]
            end) then
            matched[#matched + 1] = app
        end
    end
    return matched
end, {})

action("media.control", function(command)
    local player = media.selected:get()
    if player then
        mantle.mpris:control(player.id, command)
    end
end)

return media
