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

-- A player's own process owns its streams. Name matching is the fallback: Chromium plays from a
-- utility process, and a sandboxed app's streams report a pid from inside its sandbox.
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
    local by_pid, by_name = {}, {}
    for _, app in ipairs(audio.apps) do
        if not app.recording and app.pid == player.pid then
            by_pid[#by_pid + 1] = app
        elseif not app.recording and util.find({ "binary", "process_name", "name", "icon" }, function(field)
                return app[field] and names[app[field]:lower()]
            end) then
            by_name[#by_name + 1] = app
        end
    end
    local matched = #by_pid > 0 and by_pid or by_name
    -- A browser publishes one player for every tab; the playing tab's stream names its title.
    local playing = {}
    for _, app in ipairs(matched) do
        if player.title ~= "" and app.media_name and app.media_name:find(player.title, 1, true) then
            playing[#playing + 1] = app
        end
    end
    return #playing > 0 and playing or matched
end, {})

action("media.control", function(command)
    local player = media.selected:get()
    if player then
        mantle.mpris:control(player.id, command)
    end
end)

return media
