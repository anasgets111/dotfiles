-- Atomic, attribute-preserving sudo-write: :W / :WQ, with :w / :wq remapped.
-- Unwritable files are staged to a temp via Neovim's own writer (exact encoding/
-- eol/format), then replaced through a privileged same-dir mktemp + mv.
-- Caveat: a root 0600 file you can't read opens empty, so saving clobbers it —
-- use sudoedit for those.

local M = {}

local DEFAULT_TRIES = 3

-- Writable without sudo: existing writable file, or new file in a writable dir.
local function is_writable(path)
    if path == "" then return false end
    if vim.fn.filewritable(path) == 1 then return true end
    if vim.uv.fs_stat(path) then return false end
    return vim.fn.filewritable(vim.fs.dirname(path)) == 2
end

-- Privileged atomic replace ($1=target, $2=src, passed as argv so the paths
-- never touch shell parsing): mktemp a sibling (root-owned, so no name can be
-- pre-planted), seed the target's attrs onto it, write src's bytes, then rename.
-- `set -eu` aborts on any real failure; the trap clears the temp on exit.
local REPLACE_SCRIPT = [[
set -eu
target=$1 src=$2
tmp=$(mktemp -- "$(dirname -- "$target")/.nvim_sudo_tmp_XXXXXX")
trap 'rm -f -- "$tmp"' EXIT
if [ -e "$target" ]; then cp -a --attributes-only -- "$target" "$tmp"; else chmod 0644 "$tmp"; fi
cat -- "$src" > "$tmp"
mv -f -- "$tmp" "$target"
]]

-- Run REPLACE_SCRIPT as root over `target`/`src`. Cached creds / NOPASSWD run via
-- `sudo -n`; otherwise the password feeds one `sudo -S` (stdin = password only).
local function sudo_run(target, src, tries)
    local argv = { "sh", "-c", REPLACE_SCRIPT, "sh", target, src }
    if vim.system({ "sudo", "-n", "true" }):wait().code == 0 then
        local run = vim.system(vim.list_extend({ "sudo", "-n" }, argv)):wait()
        if run.code ~= 0 then vim.notify("✗ sudo write failed: " .. vim.trim(run.stderr or ""), vim.log.levels.ERROR) end
        return run.code == 0
    end
    for attempt = 1, tries do
        local password = vim.fn.inputsecret(attempt == 1 and "🔒 sudo password: "
            or string.format("🔒 sudo password (attempt %d/%d): ", attempt, tries))
        if password == "" then
            vim.notify("Write cancelled", vim.log.levels.WARN)
            return false
        end
        local run = vim.system(vim.list_extend({ "sudo", "-S", "-p", "" }, argv), { stdin = password .. "\n" }):wait()
        if run.code == 0 then return true end
        -- Password accepted (creds now cached) but the run still failed => real error, not a typo.
        if vim.system({ "sudo", "-n", "true" }):wait().code == 0 then
            vim.notify("✗ sudo write failed: " .. vim.trim(run.stderr or ""), vim.log.levels.ERROR)
            return false
        end
        local is_last = attempt == tries
        vim.notify(is_last and "✗ sudo write failed (wrong password?)"
            or string.format("✗ Wrong password (%d/%d)", attempt, tries),
            is_last and vim.log.levels.ERROR or vim.log.levels.WARN)
    end
    return false
end

function M.sudo_write(opts, bang)
    local bufnr = vim.api.nvim_get_current_buf()
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname == "" then
        vim.notify("No file name", vim.log.levels.WARN)
        return false
    end
    -- Write through symlinks, like Vim's default.
    local target = vim.fn.resolve(vim.fn.fnamemodify(bufname, ":p"))

    if is_writable(target) then
        local ok, err = pcall(vim.api.nvim_cmd, { cmd = "write", bang = bang }, {})
        if not ok then vim.notify("✗ Write failed: " .. tostring(err), vim.log.levels.ERROR) end
        return ok
    end

    -- Fire save hooks, then stage the buffer ourselves (root reads the temp via cat).
    pcall(vim.api.nvim_exec_autocmds, "BufWritePre", { buffer = bufnr, modeline = false })
    local staged_path = vim.fn.tempname()
    local staged = pcall(vim.api.nvim_cmd,
        { cmd = "write", bang = true, args = { staged_path }, mods = { noautocmd = true, keepalt = true } }, {})
    if not staged then
        vim.fn.delete(staged_path)
        vim.notify("✗ Could not stage buffer to a temp file", vim.log.levels.ERROR)
        return false
    end

    local ok = sudo_run(target, staged_path, tonumber(opts and opts.max_tries) or DEFAULT_TRIES)
    vim.fn.delete(staged_path)
    if not ok then return false end

    vim.bo[bufnr].modified = false
    vim.cmd("silent! checktime " .. bufnr) -- refresh mtime so :checktime won't nag (W11)
    pcall(vim.api.nvim_exec_autocmds, "BufWritePost", { buffer = bufnr, modeline = false })
    vim.notify("✓ Saved (sudo): " .. target, vim.log.levels.INFO)
    return true
end

-- Delegate `:w file` to the builtin (true if it did). nargs="?" also keeps the
-- abbrevs from throwing E488 before an argument.
local function passthrough(cmd, builtin)
    if cmd.args == "" then return false end
    local ok, err = pcall(vim.api.nvim_cmd, { cmd = builtin, args = cmd.fargs, bang = cmd.bang }, {})
    if not ok then vim.notify("✗ " .. tostring(err), vim.log.levels.ERROR) end
    return true
end

function M.setup(opts)
    opts = opts or {}

    vim.api.nvim_create_user_command("W", function(cmd)
        if not passthrough(cmd, "write") then M.sudo_write(opts, cmd.bang) end
    end, { nargs = "?", bang = true, complete = "file" })

    vim.api.nvim_create_user_command("WQ", function(cmd)
        if passthrough(cmd, "wq") then return end
        if M.sudo_write(opts, cmd.bang) then pcall(vim.api.nvim_cmd, { cmd = "quit" }, {}) end
    end, { nargs = "?", bang = true, complete = "file" })

    vim.cmd([[cnoreabbrev <expr> w  (getcmdtype() == ":" && getcmdline() == "w")  ? "W"  : "w"]])
    vim.cmd([[cnoreabbrev <expr> wq (getcmdtype() == ":" && getcmdline() == "wq") ? "WQ" : "wq"]])
end

return M
