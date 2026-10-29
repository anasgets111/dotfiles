-- `position` is valid only at `position_updated_at` and nothing polls it, so the bar extrapolates from
-- that stamp, which shares `CLOCK_MONOTONIC` with `mantle.clock`. The engine keeps the stamp while a
-- player repeats a reading and restamps on play and pause, so the pair is all a clock needs.
--
-- A quiet player, such as a browser, may never report a seek, so a drag adopts its target until a
-- reading stamped after it arrives. Controls disable reactively from `PlayerState` capability flags.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local glyph = require("components.glyph")
local slider = require("components.slider")
local panel_header = require("components.panel_header")
local panel_action_icon = require("components.panel_action_icon")
local panel_empty_state = require("components.panel_empty_state")
local panel_row = require("components.panel_row")
local icon_button = require("components.icon_button")
local disclosure = require("lib.disclosure")
local media = require("lib.media")
local store = require("lib.store")

local NEXT_LOOP = { none = "playlist", playlist = "track", track = "none" }
local LOOP_ICONS = { track = icons.repeat_one, playlist = icons.repeat_all }

local selected = media.selected

-- The last seek: its player, target and the clock second it was made.
local seek = state("media_seek_target", { id = "", position = 0, at = 0 })

-- `album_art_path` is local covers only; a remote one (Spotify's) arrives as `art_url`. Each player's
-- latest is downloaded into one file named for it and moved into place whole, so the image never
-- reads half a cover. A newer cover kills the download it replaces.
local ART_DIR = (os.getenv("XDG_CACHE_HOME") or ((os.getenv("HOME") or "") .. "/.cache")) .. "/mantle/art"
local FETCH = 'curl -fsSL --max-time 10 --create-dirs -o "$1.part" "$2" && mv "$1.part" "$1"'
local held = state("media_remote_art", {}) -- player id -> the `art_url` its file holds
local downloads = {}                       -- player id -> { url, handle } of its latest download

mantle.mpris:on_change(function(mpris)
    for _, player in ipairs((mpris and mpris.players) or {}) do
        local id, url = player.id, player.art_url or ""
        local current = downloads[id]
        if url:match("^https?://") and not (current and current.url == url) then
            if current then
                current.handle:kill()
            end
            local path = ART_DIR .. "/" .. id
            downloads[id] = {
                url = url,
                handle = process.run("sh", { "-c", FETCH, "sh", path, url }, function() end,
                    function(code)
                        if code == 0 then
                            held:set(util.with(held:get(), id, url))
                        end
                    end)
            }
        end
    end
end)

local artwork = computed({ selected, held }, function(player, fetched)
    if not player then
        return ""
    end
    if player.album_art_path ~= "" then
        return player.album_art_path
    end
    -- Only this track's cover, never the last one while the new one downloads.
    return player.art_url and fetched[player.id] == player.art_url and ART_DIR .. "/" .. player.id or ""
end)

-- `system.monotonic` ticks once a second, so the clock and bar advance in whole seconds.
local position_us = computed({ selected, mantle.clock, seek }, function(player, system, sought)
    if not player then
        return -1
    end
    local position, at = player.position, player.position_updated_at / 1e6
    if sought.id == player.id and sought.at > at then
        position, at = sought.position, sought.at
    end
    -- `nil` is "never answered": `-1` draws `--:--`, not a confident `0:00`.
    if position == nil then
        return -1
    end
    if player.play_state == "playing" then
        local rate = player.rate > 0 and player.rate or 1
        position = position + math.max(0, system.monotonic - at) * rate * 1e6
    end
    -- A `nil` length is a stream, which has no end to clamp to.
    local length = player.length
    return length and length > 0 and math.min(position, length) or position
end, -1)

-- Minutes and zero-padded seconds, and never a negative or a fabricated zero for the `nil` a
-- stream reports or the `-1` of `position_us`.
local function clock(microseconds)
    if microseconds == nil or microseconds < 0 then
        return "--:--"
    end
    local seconds = math.floor(microseconds / 1000000)
    if seconds >= 3600 then
        return string.format("%d:%02d:%02d", seconds // 3600, seconds // 60 % 60, seconds % 60)
    end
    return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local has_player = selected:map(function(player)
    return player ~= false
end)

-- `identity` is the empty-string sentinel, so fallbacks test `""`, not a plain `or` chain.
local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local candidate = select(index, ...)
        if candidate and candidate ~= "" then
            return candidate
        end
    end
    return ""
end

local function player_name(player)
    return first_nonempty(player.identity, player.desktop_entry, player.id:match("^[^.]+"))
end

local player_count = mantle.mpris:map(function(mpris)
    return #mpris.players
end, 0)

-- Steps to the next player in `players` order, wrapping.
local function next_player()
    local players = mantle.mpris:get().players
    local current = selected:get()
    for index, player in ipairs(players) do
        if current and player.id == current.id then
            return media.select(players[index % #players + 1].id)
        end
    end
end

-- A player without `LoopStatus`, such as a browser, ignores shuffle too. The buttons stay, dimmed,
-- so the row keeps one shape across players.
local no_modes = selected:map(function(player)
    return not (player and player.loop_status ~= nil)
end)

-- One level for the player across all its streams: a browser opens one per tab.
local volume = media.streams:map(function(streams)
    local stream = streams[1]
    return stream and { level = stream.volume, muted = stream.muted } or false
end)

local queue_open = disclosure.state("media_queue_open", false)
local QUEUE_ROW_HEIGHT = theme.control.lg

local tracks = selected:map(function(player)
    if not player then
        return {}
    end
    local current = player.track_list.current_track
    local out = {}
    for index, track in ipairs(player.track_list.tracks) do
        out[index] = { id = track.id, title = track.title, artist = track.artist, current = track.id == current }
    end
    return out
end)

local function with_player(fn)
    return function()
        local player = selected:get()
        if player then fn(player) end
    end
end

local function transport(slot, icon, command, disabled)
    return panel_action_icon(icon, with_player(function(player)
        mantle.mpris:control(player.id, command)
    end), { slot = slot, disabled = disabled })
end

local play_disabled = selected:map(function(player)
    if not player then
        return true
    end
    return (player.play_state == "playing" and not player.can_pause) or
        (player.play_state ~= "playing" and not player.can_play)
end)

local body = {
    -- The player is the subject: its name heads the panel, and with several open the switch steps through them.
    panel_header {
        title = util.label(selected, function(player)
            return player and player_name(player) or "Media"
        end),
        icon = icons.media,
        active = has_player,
        subtitle = computed({ selected, player_count }, function(player, count)
            if not player then
                return "No player open"
            end
            local state = player.play_state:sub(1, 1):upper() .. player.play_state:sub(2)
            if count < 2 then
                return state
            end
            local players = mantle.mpris:get().players
            for index, other in ipairs(players) do
                if other.id == player.id then
                    return string.format("%s · %d of %d players", state, index, count)
                end
            end
            return state
        end),
        trailing = {
            panel_action_icon(icons.player_switch, next_player, {
                slot = "media-switch",
                visible = player_count:map(function(count)
                    return count > 1
                end),
            }),
            -- Swaps the bar's visualizer; the glyph names the one a click switches to.
            panel_action_icon(store.media_visualizer:map(function(kind)
                return kind == "bars" and icons.waveform or icons.chart_bar
            end), function()
                store:set("media_visualizer", store.media_visualizer:get() == "bars" and "wave" or "bars")
            end, { slot = "media-visualizer", visible = has_player }),
            panel_action_icon(icons.raise, with_player(function(player)
                mantle.mpris:raise(player.id)
            end), {
                slot = "media-raise",
                visible = selected:map(function(player)
                    return player ~= false and player.can_raise
                end),
            }),
        },
    },
    -- Cover and the track's names, the text centred on the cover's height.
    row {
        width = "fill",
        spacing = theme.spacing.md,
        align_v = "center",
        visible = has_player,
        children = {
            rect {
                width = theme.media_artwork,
                height = theme.media_artwork,
                radius = theme.radius.md,
                background = theme.GLASS_CONTROL,
                clip = "rounded",
                children = {
                    -- An empty `image.source` draws nothing, so the note shows until a cover lands.
                    glyph(icons.media, theme.DIM, theme.icon.xl, { align = "center", align_v = "center" }),
                    image {
                        source = artwork,
                        fit = "cover",
                        -- An inline decode would stall the frame that opens the card.
                        async = true,
                        width = "fill",
                        height = "fill",
                    },
                },
            },
            column {
                width = "fill",
                align_v = "center",
                spacing = theme.spacing.xs,
                children = {
                    -- An empty title is normal between tracks, not a failure.
                    cell(util.bold(util.label(selected, function(player)
                        return first_nonempty(player and player.title, player and player.identity, "Unknown track")
                    end)), theme.FG, theme.font.lg, { width = "fill" }),
                    cell(util.label(selected, function(player)
                        if not player then
                            return "Unknown artist"
                        end
                        if player.artist ~= "" and player.album ~= "" then
                            return player.artist .. " • " .. player.album
                        end
                        return first_nonempty(player.artist, player.album, player.identity, "Unknown artist")
                    end), theme.DIM, theme.font.sm, { width = "fill" }),
                },
            },
        },
    },
    -- Full width, the times on the bar's own line.
    row {
        width = "fill",
        spacing = theme.spacing.sm,
        align_v = "center",
        visible = has_player,
        children = {
            cell(position_us:map(clock), theme.DIM, theme.font.xs),
            slider {
                name = "media_seek",
                signal = position_us,
                read = function(microseconds)
                    local player = selected:get()
                    local length = player and player.length
                    if not (player and player.can_seek) or not length or length <= 0 or microseconds < 0 then
                        return nil
                    end
                    return microseconds / length
                end,
                on_commit = function(fraction)
                    local player = selected:get()
                    if not player or not player.can_seek then
                        return
                    end
                    local length = player.length
                    if not length or length <= 0 then
                        return
                    end
                    -- Clamps as `clamp_seek_target` does, so the Supervisor never moves a target the
                    -- config allowed.
                    local target = math.floor(math.min(math.max(0, fraction * length), length))
                    -- A `SetPosition` briefly costs this browser its length metadata, so skip a no-op drag.
                    if math.abs(target - position_us:get()) < 5000 then
                        return
                    end
                    seek:set({ id = player.id, position = target, at = mantle.clock:now() })
                    mantle.mpris:seek(player.id, target)
                end,
                steps = 0,
                width = "fill",
                height = theme.spacing.sm,
                background = theme.GLASS_CONTROL,
                align_v = "center",
                -- A stream reports a `nil` length, so it has no fraction to drag to.
                fill_visible = selected:map(function(player)
                    return player ~= false and player.can_seek and (player.length or 0) > 0
                end),
            },
            cell(selected:map(function(player)
                return clock(player and player.length or nil)
            end), theme.DIM, theme.font.xs),
        },
    },
    -- A spacer and the volume zone fill equally, so the transport stays centred.
    row {
        width = "fill",
        spacing = theme.spacing.md,
        align_v = "center",
        visible = has_player,
        children = {
            rect { width = "fill" },
            row {
                align_v = "center",
                spacing = theme.spacing.xs,
                children = {
                    panel_action_icon(icons.shuffle, with_player(function(player)
                        mantle.mpris:set_shuffle(player.id, not player.shuffle)
                    end), {
                        slot = "media-shuffle",
                        disabled = no_modes,
                        active = selected:map(function(player)
                            return player ~= false and player.shuffle
                        end),
                    }),
                    transport("media-previous", icons.previous, "previous", selected:map(function(player)
                        return not (player and player.can_go_previous)
                    end)),
                    icon_button(selected:map(function(player)
                        return (player and player.play_state == "playing") and icons.pause or icons.play
                    end), with_player(function(player)
                        if not play_disabled:get() then
                            mantle.mpris:control(player.id, "play_pause")
                        end
                    end), {
                        slot = "media-playpause",
                        size = theme.control.lg,
                        icon_size = theme.icon.md,
                        border = false,
                        background = theme.ACCENT,
                        opacity = util.choose(play_disabled, theme.opacity.disabled, 1),
                    }),
                    transport("media-stop", icons.stop, "stop", selected:map(function(player)
                        return not player or player.play_state == "stopped"
                    end)),
                    transport("media-next", icons.next, "next", selected:map(function(player)
                        return not (player and player.can_go_next)
                    end)),
                    panel_action_icon(selected:map(function(player)
                        return LOOP_ICONS[player and player.loop_status] or icons.repeat_off
                    end), with_player(function(player)
                        mantle.mpris:set_loop_status(player.id, NEXT_LOOP[player.loop_status] or "playlist")
                    end), {
                        slot = "media-loop",
                        disabled = no_modes,
                        active = selected:map(function(player)
                            return player ~= false and LOOP_ICONS[player.loop_status] ~= nil
                        end),
                    }),
                },
            },
            row {
                width = "fill",
                -- Packs the volume against the far edge.
                align_h = "end",
                align_v = "center",
                spacing = theme.spacing.xs,
                children = {
                    panel_action_icon(volume:map(function(level)
                        return level and level.muted and icons.vol_muted or icons.vol_high
                    end), function()
                        local muted = not (volume:get() or {}).muted
                        for _, stream in ipairs(media.streams:get()) do
                            mantle.audio:set_app_muted(stream.id, muted)
                        end
                    end, {
                        slot = "media-mute",
                        visible = volume:map(function(level)
                            return level ~= false
                        end),
                    }),
                    slider {
                        name = "media_volume",
                        signal = volume,
                        read = function(level)
                            return level and level.level
                        end,
                        on_commit = function(value)
                            for _, stream in ipairs(media.streams:get()) do
                                mantle.audio:set_app_volume(stream.id, value)
                            end
                        end,
                        max = 100,
                        steps = 20,
                        width = "fill",
                        height = theme.spacing.xs,
                        align_v = "center",
                        background = theme.GLASS_CONTROL,
                        visible = volume:map(function(level)
                            return level ~= false
                        end),
                        color = volume:map(function(level)
                            return level and level.muted and theme.INACTIVE or theme.ACCENT_MEDIUM
                        end),
                    },
                },
            },
        },
    },
    panel_row {
        slot = "media-queue",
        icon = icons.queue,
        title = "Up next",
        subtitle = util.label(tracks, function(list)
            return #list == 1 and "1 track" or string.format("%d tracks", #list)
        end),
        expanded = queue_open,
        visible = tracks:map(function(list)
            return #list > 0
        end),
        details = list {
            width = "fill",
            max_height = tracks:map(function(list)
                return util.fit_height(list, theme.panel_list_height, theme.spacing.xs, function()
                    return QUEUE_ROW_HEIGHT
                end)
            end),
            scroll = scroll("media_queue"),
            animate = { scroll = theme.scroll_ease },
            spacing = theme.spacing.xs,
            items = tracks,
            each = function(track)
                return panel_row {
                    title = first_nonempty(track.title, "Unknown track"),
                    subtitle = track.artist ~= "" and track.artist or nil,
                    height = QUEUE_ROW_HEIGHT,
                    selected = track.current,
                    on_activate = with_player(function(player)
                        mantle.mpris:track_list_go_to(player.id, track.id)
                    end),
                }
            end,
            key = function(track)
                return track.id
            end,
        },
    },
    panel_empty_state("Play something to control it here", has_player:map(function(on)
        return not on
    end), { icon = icons.media }),
}

return { kind = "media", body = body, spacing = theme.spacing.sm }
