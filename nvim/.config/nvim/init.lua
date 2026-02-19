-- Leader Keys
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

-- Standard Options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.textwidth = 80
vim.opt.mouse = "a"
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.updatetime = 250
vim.opt.cursorline = true
vim.opt.confirm = true
vim.diagnostic.config({ virtual_text = true })

-- System Clipboard Integration
vim.opt.clipboard = "unnamedplus"

-- Plugin Management (Nvim 0.11+ Native)
vim.pack.add({
    "https://github.com/nvim-treesitter/nvim-treesitter",
    "https://github.com/saghen/blink.cmp",
    "https://github.com/neovim/nvim-lspconfig",
    "https://github.com/mason-org/mason.nvim",
    "https://github.com/mason-org/mason-lspconfig.nvim",
    "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim",
    "https://github.com/catppuccin/nvim",
    "https://github.com/folke/which-key.nvim",
    "https://github.com/nvim-telescope/telescope.nvim",
    "https://github.com/nvim-telescope/telescope-ui-select.nvim",
    "https://github.com/nvim-tree/nvim-web-devicons",
    "https://github.com/stevearc/conform.nvim",
    "https://github.com/NMAC427/guess-indent.nvim",
    "https://github.com/nvim-lua/plenary.nvim",
    "https://github.com/folke/todo-comments.nvim",
    "https://github.com/lewis6991/gitsigns.nvim",
}, { confirm = false })

-- Treesitter 1.0 Setup (configs module is deprecated/removed)
local ts = require("nvim-treesitter")
ts.setup({ auto_install = true })

-- Enable Native Highlighting for all TS-supported files
vim.api.nvim_create_autocmd("FileType", {
    callback = function()
        local lang = vim.treesitter.language.get_lang(vim.bo.filetype)
        if lang then pcall(vim.treesitter.start) end
    end,
})

-- Colorscheme Setup
require("catppuccin").setup({
    flavour = "mocha",
    transparent_background = true,
})
vim.cmd.colorscheme("catppuccin")

-- Keymaps
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlights" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

-- Autocmds
vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight when yanking (copying) text",
    group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
    callback = function()
        vim.hl.on_yank()
    end,
})

-- Which Key Setup
require("which-key").setup({
    delay = 0,
    icons = {
        mappings = vim.g.have_nerd_font,
    },
})

-- Telescope Setup
local telescope = require("telescope")
local builtin = require("telescope.builtin")

telescope.setup({
    extensions = {
        ["ui-select"] = {
            require("telescope.themes").get_dropdown(),
        },
    },
})
pcall(telescope.load_extension, "ui-select")

-- Telescope Keymaps
vim.keymap.set("n", "<leader>sh", builtin.help_tags, { desc = "[S]earch [H]elp" })
vim.keymap.set("n", "<leader>sk", builtin.keymaps, { desc = "[S]earch [K]eymaps" })
vim.keymap.set("n", "<leader>sf", builtin.find_files, { desc = "[S]earch [F]iles" })
vim.keymap.set("n", "<leader>ss", builtin.builtin, { desc = "[S]earch [S]elect Telescope" })
vim.keymap.set("n", "<leader>sw", builtin.grep_string, { desc = "[S]earch current [W]ord" })
vim.keymap.set("n", "<leader>sg", builtin.live_grep, { desc = "[S]earch by [G]rep" })
vim.keymap.set("n", "<leader>sd", builtin.diagnostics, { desc = "[S]earch [D]iagnostics" })
vim.keymap.set("n", "<leader>sr", builtin.resume, { desc = "[S]earch [R]esume" })
vim.keymap.set("n", "<leader>s.", builtin.oldfiles, { desc = "[S]earch Recent Files" })
vim.keymap.set("n", "<leader><leader>", builtin.buffers, { desc = "[ ] Find existing buffers" })

-- Conform Setup
require("conform").setup({
    formatters_by_ft = {
        lua = { "stylua" },
        python = { "black" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        json = { "prettier" },
        markdown = { "prettier" },
    },
    format_on_save = {
        timeout_ms = 500,
        lsp_format = "fallback",
    },
})

vim.keymap.set("n", "<leader>f", function()
    require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "[F]ormat buffer" })

-- Guess Indent Setup
require("guess-indent").setup()

-- Todo Comments Setup
require("todo-comments").setup({
    signs = true,
})

-- Gitsigns Setup
require("gitsigns").setup({
    signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
    },
})

-- Completion Setup
require("blink.cmp").setup({ fuzzy = { implementation = "lua" } })

-- LSP Configurations
local lsp_servers = {
    lua_ls = {
        Lua = {
            workspace = { library = vim.api.nvim_get_runtime_file("lua", true) }
        }
    },
    rust_analyzer = {},
    intelephense = {},
}

-- Mason Setup
require("mason").setup()
require("mason-lspconfig").setup()
require("mason-tool-installer").setup({
    ensure_installed = vim.tbl_keys(lsp_servers),
})

-- Nvim 0.11+ Modern LSP Config
for server, config in pairs(lsp_servers) do
    vim.lsp.config(server, {
        settings = config,
        on_attach = function(_, bufnr)
            vim.keymap.set("n", "grd", vim.lsp.buf.definition, { buffer = bufnr })
        end,
    })
    -- Enable the server
    vim.lsp.enable(server)
end
local ok, sudo_write = pcall(require, "sudo_write")
if ok and sudo_write and sudo_write.setup then
    sudo_write.setup()
end
