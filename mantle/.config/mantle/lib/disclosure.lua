-- Bar panels share an always-mapped surface, so reset_on_close cannot reset their disclosures.
-- Reset on the next open; closing must leave the current content intact through its exit tween.
local disclosure = {}
local entries = {}

---@generic T
---@param name string
---@param initial T
---@return StateSignal<T>
function disclosure.state(name, initial)
    local signal = state(name, initial)
    entries[#entries + 1] = { signal, initial }
    return signal
end

function disclosure.reset()
    for _, entry in ipairs(entries) do
        entry[1]:set(entry[2])
    end
end

return disclosure
