-- Dots/nvim/.config/nvim/lua/sudo_write.lua
-- Smart sudo-write module (atomic).
-- Write flow:
-- 1. If file is writable normally, use regular :write
-- 2. Otherwise, write buffer contents to a tmp file in the target directory
--    using `sudo tee tmpfile` (password passed on stdin), then `sudo mv tmpfile target`
--    to make the replacement atomic (rename on same filesystem).
-- 3. Provides user commands `:W` and `:WQ` and safe cnoreabbrev for `:w`/`:wq`.
--
-- Usage:
--   local sudo_write = require("sudo_write")
--   sudo_write.setup()                  -- registers commands/abbrevs with defaults
--   -- or:
--   sudo_write.setup({ max_tries = 2 }) -- customize behavior
--
-- Exported:
--   sudo_write.sudo_write() -- can be called directly

-- Dots/nvim/.config/nvim/lua/sudo_write.lua

local M = {}

local default_opts = {
    max_tries            = 3,
    tmp_prefix           = ".nvim_sudo_tmp_",
    notify_success_level = vim.log.levels.INFO,
    notify_warn_level    = vim.log.levels.WARN,
    notify_error_level   = vim.log.levels.ERROR,
}

math.randomseed(os.time() + vim.fn.getpid())

local function _is_writable(path)
    if not path or path == "" then return false end
    local ok, fd = pcall(function()
        return vim.uv.fs_open(path, "r+", 438)
    end)
    if not ok or not fd then return false end
    pcall(vim.uv.fs_close, fd)
    return true
end

local function _get_buffer_content(bufnr)
    bufnr = bufnr or 0
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local content = table.concat(lines, "\n")
    if vim.bo[bufnr].eol then
        content = content .. "\n"
    end
    return content
end

local function _make_tmp_name(dir, prefix)
    return string.format(
        "%s/%s%d_%d_%d",
        dir, prefix,
        vim.fn.getpid(),
        os.time(),
        math.random(10000, 99999)
    )
end

-- Single sudo call: tee to tmp then mv into place atomically
-- Avoids credential-caching issues between separate subprocess calls
local function _sudo_write_atomic(tmp, filepath, stdin)
    local cmd = string.format(
        "tee %s > /dev/null && mv %s %s",
        vim.fn.shellescape(tmp),
        vim.fn.shellescape(tmp),
        vim.fn.shellescape(filepath)
    )
    vim.fn.system({ "sudo", "-S", "sh", "-c", cmd }, stdin)
    return vim.v.shell_error == 0
end

local function _sudo_rm(tmp)
    pcall(function() vim.fn.system({ "sudo", "rm", "-f", tmp }) end)
end

function M.sudo_write(opts)
    opts = vim.tbl_extend("force", default_opts, opts or {})

    local filepath = vim.api.nvim_buf_get_name(0)
    if not filepath or filepath == "" then
        vim.notify("No file name", opts.notify_warn_level)
        return
    end

    if _is_writable(filepath) then
        pcall(vim.cmd, "write")
        return
    end

    local content = _get_buffer_content(0)
    local dir = vim.fn.fnamemodify(filepath, ":h")
    if dir == "" or dir == "." then dir = vim.fn.getcwd() end

    local tmp = _make_tmp_name(dir, opts.tmp_prefix)
    local max_tries = tonumber(opts.max_tries) or default_opts.max_tries

    for attempt = 1, max_tries do
        local label = attempt > 1
            and string.format("🔒 sudo password (attempt %d/%d): ", attempt, max_tries)
            or "🔒 sudo password: "

        local password = vim.fn.inputsecret(label)
        if not password or password == "" then
            vim.notify("Write cancelled", opts.notify_warn_level)
            return
        end

        if _sudo_write_atomic(tmp, filepath, password .. "\n" .. content) then
            pcall(function() vim.bo.modified = false end)
            pcall(vim.cmd, "edit!")
            vim.notify("✓ Saved (sudo): " .. filepath, opts.notify_success_level)
            return
        else
            _sudo_rm(tmp)
            local is_last = attempt == max_tries
            local msg = is_last
                and ("✗ sudo write failed after " .. max_tries .. " attempts")
                or string.format("✗ Wrong password (%d/%d)", attempt, max_tries)
            vim.notify(msg, is_last and opts.notify_error_level or opts.notify_warn_level)
        end
    end
end

function M.setup(opts)
    opts = opts or {}
    local wrapped = function() M.sudo_write(opts) end

    vim.api.nvim_create_user_command("W", wrapped, {})
    vim.api.nvim_create_user_command("WQ", function()
        wrapped()
        if not vim.bo.modified then pcall(vim.cmd, "quit") end
    end, {})

    vim.cmd([[cnoreabbrev <expr> w  getcmdtype() == ":" && getcmdline() == "w"  ? "W"  : "w"]])
    vim.cmd([[cnoreabbrev <expr> wq getcmdtype() == ":" && getcmdline() == "wq" ? "WQ" : "wq"]])
end

return M
