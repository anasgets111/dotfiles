-- `position` is valid only at `position_updated_at` and nothing polls it, so the bar would sit still
-- between pushes. That stamp is `CLOCK_MONOTONIC`, which `mantle.system.monotonic` is not. `on_change`
-- is the one place a clock reading and a payload are simultaneous, so it anchors each push and `system`
-- ticks the elapsed term once a second. A `:map` may not `:set`, so it cannot record the anchor.
--
-- A quiet player, such as a browser, may never report a seek, so a drag adopts its target as the
-- reading until the next real one. Controls disable reactively from `PlayerState` capability flags.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local glyph = require("components.glyph")
local slider = require("components.slider")
local panel_header = require("components.panel_header")
local panel_action_icon = require("components.panel_action_icon")
local panel_empty_state = require("components.panel_empty_state")
local store = require("lib.store")

local SEEK_STEP_US = 5 * 1000 * 1000
local NEXT_LOOP = { None = "Playlist", Playlist = "Track", Track = "None" }
local LOOP_ICONS = { Track = icons.repeat_one, Playlist = icons.repeat_all }

-- `players` is longest-running first and stable across position updates. The list shrinks without
-- notice, so the index wraps on read instead of clamping on write.
local chosen = state("media_player", 1)

local selected = computed({ mantle.mpris, chosen }, function(mpris, index)
    local players = (mpris and mpris.players) or {}
    if #players == 0 then
        return false
    end
    return players[(index - 1) % #players + 1]
end)

local anchor = state("media_anchor", 0)

--- Stamps the anchor from the same clock `position_us` adds elapsed time against. Every writer goes
--- through this: a seek that stamped a different clock would jump the position by the two epochs.
local function anchor_now()
    anchor:set((mantle.system:get() or {}).monotonic or 0)
end

-- Keyed on the `position` value, not the push. A browser answers `Position` with the same number all
-- track, which would reset the elapsed term on every push.
local anchored_position

-- The last seek target, or `-1` while the player's reading holds. A browser often emits neither
-- `Seeked` nor `PropertiesChanged`, so the target stands until a fresh reading replaces it.
local seek_base = state("media_seek_base", -1)

mantle.mpris:on_change(function()
    local player = selected:get()
    -- `nil` is "this player has never answered `Position`", not a reading, so it must not become an
    -- anchor to count from.
    local position = player and player.position
    if position == nil or position == anchored_position then
        return
    end
    anchored_position = position
    seek_base:set(-1)
    anchor_now()
end)

-- No clock read of its own: a `computed` must answer the same for the same inputs. Before
-- `mantle.system`'s first tick there is no "now", so the elapsed term is zero.
local position_us = computed({ selected, mantle.system, anchor, seek_base }, function(player, system, anchored, base)
    if not player then
        return -1
    end
    -- `nil` is "never answered". Returning `-1` lets `clock` draw `--:--` instead of a confident
    -- `0:00` that a retained anchor would then count upward from.
    local reported = player.position
    if base < 0 and reported == nil then
        return -1
    end
    local position = base >= 0 and base or reported
    local now = (system and system.monotonic) or 0
    if player.play_state == "Playing" and anchored > 0 and now > anchored then
        position = position + (now - anchored) * 1000 * 1000
    end
    -- A `nil` length is a stream, which has no end to clamp to.
    local length = player.length
    return length and length > 0 and math.min(position, length) or position
end)

-- Minutes and zero-padded seconds, and never a negative or a fabricated zero for the `nil` a
-- stream reports or the `-1` of `position_us`.
local function clock(microseconds)
    if microseconds == nil or microseconds < 0 then
        return "--:--"
    end
    local seconds = math.floor(microseconds / 1000000)
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local has_player = selected:map(function(player)
    return player ~= false
end)

local cannot_seek = selected:map(function(player)
    return not (player and player.can_seek)
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

local function with_player(fn)
    return function()
        local player = selected:get()
        if player then fn(player) end
    end
end

-- `offset` seeks through `seek_relative`, since only the player knows where the track is.
-- `seek_base` is the estimate the bar shows meanwhile.
local function transport(slot, icon, command, offset, size, disabled)
    return panel_action_icon(icon, with_player(function(player)
        if offset then
            local length = player.length
            local estimate = position_us:get() + offset
            estimate = math.max(0, length and length > 0 and math.min(estimate, length) or estimate)
            seek_base:set(math.floor(estimate))
            anchor_now()
            mantle.mpris:seek_relative(player.id, offset)
        elseif command then
            mantle.mpris:control(player.id, command)
        end
    end), { slot = slot, size = size, disabled = disabled })
end

local body = {
    panel_header {
        title = "Media",
        icon = icons.media,
        active = has_player,
        subtitle = util.label(selected, function(player)
            return first_nonempty(player and player.identity, "No player open")
        end),
        trailing = {
            -- Swaps the bar's visualizer; the glyph names the one a click switches to.
            panel_action_icon(store.media_visualizer:map(function(kind)
                return kind == "bars" and icons.waveform or icons.chart_bar
            end), function()
                store:set("media_visualizer", store.media_visualizer:get() == "bars" and "wave" or "bars")
            end, { slot = "media-visualizer", visible = has_player }),
            panel_action_icon(icons.raise, function()
                local player = selected:get()
                if player and player.can_raise then
                    mantle.mpris:raise(player.id)
                end
            end, {
                slot = "media-raise",
                visible = selected:map(function(player)
                    return player ~= false and player.can_raise
                end),
            }),
            panel_action_icon(icons.player_switch, function()
                chosen:set(chosen:get() + 1)
            end, {
                slot = "media-switch",
                visible = mantle.mpris:map(function(mpris)
                    return #((mpris and mpris.players) or {}) > 1
                end),
            }),
        },
    },
    row {
        width = "Fill",
        spacing = theme.spacing.md,
        visible = has_player,
        children = {
            rect {
                width = theme.media_artwork,
                height = theme.media_artwork,
                radius = theme.radius.md,
                background = theme.GLASS_CONTROL,
                align_v = "Start",
                children = {
                    -- An empty `image.source` draws nothing, so the note shows until a cover lands.
                    glyph(icons.media, theme.DIM, theme.icon.xl, { align = "Center", align_v = "Center" }),
                    image {
                        source = selected:map(function(player)
                            return (player and player.album_art_path) or ""
                        end),
                        fit = "cover",
                        -- An inline decode would stall the frame that opens the card.
                        async = true,
                        width = "Fill",
                        height = "Fill",
                    },
                },
            },
            column {
                width = "Fill",
                spacing = theme.spacing.xs,
                children = {
                    -- An empty title is normal between tracks, not a failure.
                    cell(util.bold(util.label(selected, function(player)
                        return first_nonempty(player and player.title, player and player.identity, "Unknown track")
                    end)), theme.FG, theme.font.lg, { width = "Fill" }),
                    -- PlayerState exposes album: show artist and album, falling back cleanly.
                    cell(util.label(selected, function(player)
                        if not player then
                            return "Unknown artist"
                        end
                        if player.artist ~= "" and player.album ~= "" then
                            return player.artist .. " • " .. player.album
                        end
                        return first_nonempty(player.artist, player.album, player.identity, "Unknown artist")
                    end), theme.DIM, theme.font.sm, { width = "Fill" }),
                    row {
                        width = "Fill",
                        -- Main-axis on a `row`, so the controls centre in the column, not against the artwork.
                        align_h = "Center",
                        spacing = theme.spacing.xs,
                        children = {
                            panel_action_icon(icons.shuffle, with_player(function(player)
                                mantle.mpris:set_shuffle(player.id, not player.shuffle)
                            end), {
                                slot = "media-shuffle",
                                active = selected:map(function(player)
                                    return player ~= false and player.shuffle
                                end),
                            }),
                            transport("media-previous", icons.previous, "previous", nil, nil, selected:map(function(p)
                                return not (p and p.can_go_previous)
                            end)),
                            transport("media-rewind", icons.rewind, nil, -SEEK_STEP_US, nil, cannot_seek),
                            transport("media-playpause", selected:map(function(player)
                                return (player and player.play_state == "Playing") and icons.pause or icons.play
                            end), "play_pause", nil, "md", selected:map(function(p)
                                if not p then
                                    return true
                                end
                                return (p.play_state == "Playing" and not p.can_pause)
                                    or (p.play_state ~= "Playing" and not p.can_play)
                            end)),
                            transport("media-stop", icons.stop, "stop", nil, nil, selected:map(function(p)
                                return not p or p.play_state == "Stopped"
                            end)),
                            transport("media-forward", icons.fast_forward, nil, SEEK_STEP_US, nil, cannot_seek),
                            transport("media-next", icons.next, "next", nil, nil, selected:map(function(p)
                                return not (p and p.can_go_next)
                            end)),
                            panel_action_icon(selected:map(function(player)
                                return LOOP_ICONS[player and player.loop_status] or icons.repeat_off
                            end), with_player(function(player)
                                mantle.mpris:set_loop_status(player.id, NEXT_LOOP[player.loop_status] or "Playlist")
                            end), {
                                slot = "media-loop",
                                active = selected:map(function(player)
                                    return player ~= false and LOOP_ICONS[player.loop_status] ~= nil
                                end),
                            }),
                        },
                    },
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
                            seek_base:set(target)
                            anchor_now()
                            mantle.mpris:seek(player.id, target)
                        end,
                        steps = 0,
                        height = theme.spacing.md,
                        background = theme.GLASS_CONTROL,
                        -- A stream reports a `nil` length, so it has no fraction to drag to.
                        fill_visible = selected:map(function(player)
                            return player ~= false and player.can_seek and (player.length or 0) > 0
                        end),
                    },
                    row {
                        width = "Fill",
                        children = {
                            cell(position_us:map(clock), theme.DIM, theme.font.xs, { width = "Fill" }),
                            cell(selected:map(function(player)
                                return clock(player and player.length or nil)
                            end), theme.DIM, theme.font.xs),
                        },
                    },
                },
            },
        },
    },
    panel_empty_state("Play something to control it here", has_player:map(function(on)
        return not on
    end), { icon = icons.media }),
}

return { kind = "media", body = body, spacing = theme.spacing.xs }
