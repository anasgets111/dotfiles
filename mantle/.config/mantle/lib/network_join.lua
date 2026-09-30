-- Credential state shared by the network panel and keyboard binding.
-- hidden_draft holds live text; hidden_ssid holds the submitted name. Passwords stay native.
local M = {}

local hidden_prompt = state("network_hidden_prompt", false)
M.hidden_draft = state("network_hidden_draft", "")
M.hidden_ssid = state("network_hidden_ssid", "")

-- Listed-network password prompts take precedence. Only errors for this SSID count;
-- another join may have left an error behind.
-- Completion is read, not latched: reaching the submitted SSID ends the sheet without a write.
M.credential_step = computed({ hidden_prompt, M.hidden_ssid, mantle.network }, function(active, name, network)
    if network and network.password_ssid ~= nil then
        return "password"
    end
    if not active then
        return ""
    end
    if name == "" then
        return "name"
    end
    if network and network.ssid == name then
        return ""
    end
    if network and network.connect_error ~= nil and network.connect_error.ssid == name then
        return "failed"
    end
    return "waiting"
end)

-- A hidden join's sheet replaces the access point list; a password for a listed row leaves it up.
M.hidden_join = computed({ hidden_prompt, M.credential_step }, function(active, step)
    return active and step ~= ""
end)

-- cancel_connect is a no-op without a parked prompt, so every closing path can call this.
function M.clear_network_prompts()
    hidden_prompt:set(false)
    M.hidden_draft:set("")
    M.hidden_ssid:set("")
    mantle.network:cancel_connect()
end

-- Cancel also stops a join in flight; closing the panel does not, so a join survives it.
function M.cancel_network_join()
    mantle.network:abort_connect()
    M.clear_network_prompts()
end

function M.open_hidden_prompt()
    M.clear_network_prompts()
    hidden_prompt:set(true)
end

return M
