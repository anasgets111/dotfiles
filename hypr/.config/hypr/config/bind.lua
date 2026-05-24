local Bind = {}

local function as_list(value)
    if type(value) == "table" then
        return value
    end

    return { value }
end

local function bind_keys(keys, action, options)
    for _, binding_key in ipairs(as_list(keys)) do
        hl.bind(binding_key, action, options)
    end
end

function Bind.leader_key(leader, keys, action, options)
    local prefixed = {}

    for _, binding_key in ipairs(as_list(keys)) do
        table.insert(prefixed, leader .. " + " .. binding_key)
    end

    bind_keys(prefixed, action, options)
end

function Bind.keys(rows)
    for _, binding in ipairs(rows) do
        bind_keys(binding[1], binding[2], binding[3])
    end
end

return Bind
