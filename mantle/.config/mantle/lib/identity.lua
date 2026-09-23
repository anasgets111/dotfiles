-- Who is logged in: GECOS from `getent passwd`, host from `uname -n`, read once per session.
-- Callers draw `$USER` and "localhost" until they answer. Named state so a reload spawns nothing.
local util = require("lib.util")

local identity = state("lock_identity", { name = "", host = "" })

local USER = os.getenv("USER") or "user"

local function remember(field, value)
    value = util.trim(value)
    -- Field at a time: the two processes finish in either order.
    if value ~= "" then
        identity:set(util.with(identity:get(), field, value))
    end
end

if identity:get().name == "" then
    -- Field five is GECOS; its first comma-separated part is the full name.
    process.run("getent", { "passwd", USER }, function(line)
        local fields = {}
        for field in (line .. ":"):gmatch("([^:]*):") do
            fields[#fields + 1] = field
        end
        remember("name", (fields[5] or ""):match("^[^,]*") or "")
    end, function() end)
end

if identity:get().host == "" then
    process.run("uname", { "-n" }, function(line)
        remember("host", line)
    end, function() end)
end

return {
    user = USER,
    full_name = identity:map(function(who)
        return who.name ~= "" and who.name or USER
    end),
    account = identity:map(function(who)
        return string.format("%s@%s", USER, who.host ~= "" and who.host or "localhost")
    end),
    -- First letters of the first two words: "Anas Khalifa" is "AK".
    initials = identity:map(function(who)
        local name = who.name ~= "" and who.name or USER
        local letters = ""
        local taken = 0
        for word in name:gmatch("%S+") do
            -- One codepoint, not one byte. `upper` is byte-oriented, so a non-ASCII initial keeps its case.
            local stop = utf8.offset(word, 2)
            letters = letters .. word:sub(1, stop and stop - 1 or #word):upper()
            taken = taken + 1
            if taken == 2 then
                break
            end
        end
        return letters ~= "" and letters or "U"
    end),
}
