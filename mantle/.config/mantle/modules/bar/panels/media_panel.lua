-- Artwork beside the track, a transport row, and a seek bar with elapsed and total either side.
--
-- `position` is only valid at `position_updated_at` and nothing polls it, so the bar would jump once
-- a track and sit still between. Both that stamp and `mantle.system.monotonic` are
-- `CLOCK_MONOTONIC`, so `on_change` -- the one place a clock reading and a payload are known
-- simultaneous -- anchors the push and `system` ticks the elapsed term once a second. A `:map` would
-- re-record the anchor, since the engine may rerun a map on the same inputs.
--
-- A drag adopts its own target as the reading, because a quiet player (a browser, indefinitely)
-- would otherwise leave the bar counting from the pre-seek position; the next real reading corrects
-- it. Nothing here checks whether a player can skip or seek: `PlayerState` carries no such flags.
local theme = require("config.theme")
local icons = require("config.icons")
local util = require("lib.util")
local cell = require("components.cell")
local glyph = require("components.glyph")
local slider = require("components.slider")
local panel_header = require("components.panel_header")
local panel_action_icon = require("components.panel_action_icon")
local panel_empty_state = require("components.panel_empty_state")

local KIND = "media"

local SEEK_STEP_US = 5 * 1000 * 1000

-- Which player the panel drives. `players` is longest-running first and stable across position
-- updates; wrap the index on read, not clamp it on write, because the list shrinks without telling
-- us.
local chosen = state("media_player", 1)

-- Reading `chosen:get()` inside a `:map` hides a dependency: selection changes while declared
-- inputs stay fixed, so switching players would move the index without redrawing.
local selected = computed({ mantle.mpris, chosen }, function(m, index)
    local players = (m and m.players) or {}
    if #players == 0 then
        return false
    end
    return players[(index - 1) % #players + 1]
end)

-- Keyed on the `position` value, not the push: a browser answering `Position` with the same number
-- all track would otherwise reset the elapsed term on every push. A repeat means "no news".
local anchor = state("media_anchor", 0)

--- Stamps the anchor from the same clock `position_us` adds elapsed time against. Every writer goes
--- through this: a seek that stamped a different clock would jump the position by the two epochs.
local function anchor_now()
    anchor:set((mantle.system:get() or {}).monotonic or 0)
end

local anchored_position = -1

-- Where we last asked the track to move to, or `-1` while the player's own reading is
-- authoritative. A browser often emits neither `Seeked` nor `PropertiesChanged`, so waiting for one
-- means never re-anchoring; adopt the requested position and let the first fresh reading take it
-- back.
local seek_base = state("media_seek_base", -1)

mantle.mpris:on_change(function()
    local player = selected:get()
    -- `-1` is "this player has never answered `Position`", not a reading, so it must not become an
    -- anchor to count from.
    local position = (player and player.position) or -1
    if position == anchored_position or position < 0 then
        return
    end
    anchored_position = position
    seek_base:set(-1)
    anchor_now()
end)

-- No clock read of its own: a `computed` must answer the same for the same inputs. Before
-- `mantle.system`'s first tick there is no "now", so the elapsed term is zero.
local position_us = computed({ selected, mantle.system, anchor, seek_base }, function(player, s, anchored, base)
    if not player then
        return -1
    end
    -- `-1` is "never answered". Passing it through lets `clock` draw `--:--` instead of a confident
    -- `0:00` that a retained anchor would then count upward from.
    local reported = player.position or -1
    if base < 0 and reported < 0 then
        return -1
    end
    local position = base >= 0 and base or reported
    local now = (s and s.monotonic) or 0
    if player.play_state == "Playing" and anchored > 0 and now > anchored then
        position = position + (now - anchored) * 1000 * 1000
    end
    -- A `-1` length is a stream, which has no end to clamp to.
    local length = player.length or -1
    if length > 0 then
        return math.min(position, length)
    end
    return position
end)

-- Minutes and zero-padded seconds, and never a negative or a fabricated zero for the `-1` a
-- stream reports.
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

-- `identity` is the empty-string sentinel, so fallbacks test `""`, not a plain `or` chain.
local function first_nonempty(...)
    for _, candidate in ipairs({ ... }) do
        if candidate ~= nil and candidate ~= "" then
            return candidate
        end
    end
    return ""
end

---One transport control. `command` runs `control`; `offset` seeks by that many microseconds through
---`seek_relative`, since only the player knows where the track actually is. `seek_base` is the
---estimate the bar shows meanwhile.
---@param slot string
---@param icon string|Bound
---@param command PlayerCommand?
---@param offset integer?
---@param size "sm"|"md"?
local function transport(slot, icon, command, offset, size)
    return panel_action_icon(icon, function()
        local player = selected:get()
        if not player then
            return
        end
        if offset then
            local length = player.length or -1
            local estimate = position_us:get() + offset
            estimate = math.max(0, length > 0 and math.min(estimate, length) or estimate)
            seek_base:set(math.floor(estimate))
            anchor_now()
            mantle.mpris:invoke("seek_relative", player.id, offset)
        elseif command then
            mantle.mpris:invoke("control", player.id, command)
        end
    end, { slot = slot, size = size })
end

local artwork = rect {
    width = theme.media_artwork,
    height = theme.media_artwork,
    radius = theme.radius.md,
    background = theme.GLASS_CONTROL,
    align_v = "Start",
    children = {
        -- The note shows through until a cover lands: an empty `image.source` draws nothing, so the
        -- glyph needs no gate of its own.
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
}

local transport_row = row {
    width = "Fill",
    -- `align_h` on a `row` is main-axis distribution: six controls narrower than the column sit in
    -- its middle, not against the artwork.
    align_h = "Center",
    spacing = theme.spacing.sm,
    children = {
        transport("media-previous", icons.previous, "previous"),
        transport("media-rewind", icons.rewind, nil, -SEEK_STEP_US),
        transport("media-playpause", selected:map(function(player)
            return (player and player.play_state == "Playing") and icons.pause or icons.play
        end), "play_pause", nil, "md"),
        transport("media-forward", icons.fast_forward, nil, SEEK_STEP_US),
        transport("media-next", icons.next, "next"),
    },
}

local seek_bar = slider {
    name = "media_seek",
    signal = position_us,
    read = function(microseconds)
        local player = selected:get()
        local length = (player and player.length) or -1
        if length <= 0 or microseconds < 0 then
            return 0
        end
        return microseconds / length
    end,
    on_commit = function(fraction)
        local player = selected:get()
        local length = (player and player.length) or -1
        if not player or length <= 0 then
            return
        end
        -- `clamp_seek_target` admits a zero length, so this clamps as it does; the two disagreeing
        -- meant a target the config allowed and the Supervisor then moved.
        local target = math.floor(math.min(math.max(0, fraction * length), length))
        -- A drag landing where the track already is is not worth a `SetPosition`, which on this
        -- browser costs the length metadata briefly.
        if math.abs(target - position_us:get()) < 5000 then
            return
        end
        seek_base:set(target)
        anchor_now()
        mantle.mpris:invoke("seek", player.id, target)
    end,
    steps = 0,
    height = theme.spacing.md,
    radius = theme.radius.sm,
    track = theme.GLASS_CONTROL,
    -- The bar is draggable only when the track has a known length; a stream reports `-1` and has no
    -- fraction to drag to.
    fill_visible = selected:map(function(player)
        return player ~= false and (player.length or -1) > 0
    end),
}

local times = row {
    width = "Fill",
    children = {
        cell(position_us:map(clock), theme.DIM, theme.font.xs, { width = "Fill" }),
        cell(selected:map(function(player)
            return clock(player and player.length or -1)
        end), theme.DIM, theme.font.xs),
    },
}

local body = {
    panel_header {
        title = "Media",
        icon = icons.media,
        active = has_player,
        subtitle = util.label(selected, function(player)
            return first_nonempty(player and player.identity, "No media player running")
        end),
        trailing = {
            panel_action_icon(icons.player_switch, function()
                chosen:set(chosen:get() + 1)
            end, {
                slot = "media-switch",
                visible = mantle.mpris:map(function(m)
                    return #((m and m.players) or {}) > 1
                end),
            }),
        },
    },
    row {
        width = "Fill",
        spacing = theme.spacing.md,
        visible = has_player,
        children = {
            artwork,
            column {
                width = "Fill",
                spacing = theme.spacing.xs,
                children = {
                    -- An empty title is normal between tracks, not a failure.
                    cell(util.bold(util.label(selected, function(player)
                        return first_nonempty(player and player.title, player and player.identity, "Unknown track")
                    end)), theme.FG, theme.font.lg, { width = "Fill" }),
                    -- Fallback is artist, album, identity; `PlayerState` has no album, so use
                    -- artist then identity.
                    cell(util.label(selected, function(player)
                        return first_nonempty(player and player.artist, player and player.identity, "Unknown artist")
                    end), theme.DIM, theme.font.sm, { width = "Fill" }),
                    transport_row,
                    seek_bar,
                    times,
                },
            },
        },
    },
    panel_empty_state("Nothing playing", has_player:map(function(on)
        return not on
    end), { icon = icons.media }),
}

return { kind = KIND, body = body }
