-- Core
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

-- Options
for option, value in pairs({
	termguicolors = true,
	number = true,
	relativenumber = true,
	signcolumn = "yes",
	tabstop = 2,
	shiftwidth = 2,
	expandtab = true,
	textwidth = 80,
	mouse = "a",
	undofile = true,
	ignorecase = true,
	smartcase = true,
	updatetime = 250,
	cursorline = true,
	confirm = true,
	breakindent = true,
	clipboard = "unnamedplus",
	background = "dark",
}) do
	vim.opt[option] = value
end
vim.diagnostic.config({
	virtual_text = true,
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "",
			[vim.diagnostic.severity.WARN] = "",
			[vim.diagnostic.severity.INFO] = "",
			[vim.diagnostic.severity.HINT] = "",
		},
	},
})

-- Plugin Specs
vim.pack.add({
	"https://github.com/folke/which-key.nvim",
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/nvim-tree/nvim-web-devicons",
	"https://github.com/nvim-telescope/telescope.nvim",
	"https://github.com/nvim-telescope/telescope-ui-select.nvim",
	"https://github.com/stevearc/conform.nvim",
	"https://github.com/NMAC427/guess-indent.nvim",
	"https://github.com/folke/todo-comments.nvim",
	"https://github.com/lewis6991/gitsigns.nvim",
	"https://github.com/saghen/blink.cmp",
	"https://github.com/neovim/nvim-lspconfig",
	"https://github.com/mason-org/mason.nvim",
	"https://github.com/mason-org/mason-lspconfig.nvim",
}, { confirm = false })

-- Autocmds
vim.api.nvim_create_autocmd("FileType", {
	callback = function(args)
		local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
		if lang then
			pcall(vim.treesitter.start, args.buf, lang)
		end
	end,
})
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
	callback = function()
		vim.hl.on_yank()
	end,
})

-- UI
vim.cmd.colorscheme("catppuccin")
for _, group in ipairs({ "Normal", "NormalFloat" }) do
	vim.api.nvim_set_hl(0, group, { bg = "none" })
end

-- Core Keymaps
for _, keymap in ipairs({
	{ "n", "<Esc>", "<cmd>nohlsearch<CR>", "Clear search highlights" },
	{ "n", "<leader>q", vim.diagnostic.setloclist, "Open diagnostic [Q]uickfix list" },
	{ "t", "<Esc><Esc>", "<C-\\><C-n>", "Exit terminal mode" },
	{ "n", "<C-h>", "<C-w><C-h>", "Move focus to the left window" },
	{ "n", "<C-j>", "<C-w><C-j>", "Move focus to the lower window" },
	{ "n", "<C-k>", "<C-w><C-k>", "Move focus to the upper window" },
	{ "n", "<C-l>", "<C-w><C-l>", "Move focus to the right window" },
}) do
	vim.keymap.set(keymap[1], keymap[2], keymap[3], { desc = keymap[4] })
end

-- Which Key
require("which-key").setup({
	delay = 0,
	icons = { mappings = vim.g.have_nerd_font },
	spec = { { "<leader>s", group = "[S]earch" } },
})

-- Telescope
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

for _, keymap in ipairs({
	{ "<leader>sh", builtin.help_tags, "[S]earch [H]elp" },
	{ "<leader>sk", builtin.keymaps, "[S]earch [K]eymaps" },
	{ "<leader>sf", builtin.find_files, "[S]earch [F]iles" },
	{ "<leader>ss", builtin.builtin, "[S]earch [S]elect Telescope" },
	{ "<leader>sw", builtin.grep_string, "[S]earch current [W]ord" },
	{ "<leader>sg", builtin.live_grep, "[S]earch by [G]rep" },
	{ "<leader>sd", builtin.diagnostics, "[S]earch [D]iagnostics" },
	{ "<leader>sr", builtin.resume, "[S]earch [R]esume" },
	{ "<leader>s.", builtin.oldfiles, "[S]earch Recent Files" },
	{ "<leader><leader>", builtin.buffers, "[ ] Find existing buffers" },
}) do
	vim.keymap.set("n", keymap[1], keymap[2], { desc = keymap[3] })
end

-- Formatting
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

-- Editing Helpers
require("guess-indent").setup({})

require("todo-comments").setup({ signs = true })

-- Git
require("gitsigns").setup({
	signs = {
		add = { text = "+" },
		change = { text = "~" },
		delete = { text = "_" },
		topdelete = { text = "‾" },
		changedelete = { text = "~" },
	},
})

-- Completion
require("blink.cmp").setup({
	fuzzy = {
		implementation = "prefer_rust_with_warning",
		prebuilt_binaries = {
			download = true,
			force_version = "v1.10.2",
		},
	},
})

-- LSP
local lsp_servers = {
	lua_ls = { Lua = { workspace = { library = vim.api.nvim_get_runtime_file("lua", true) } } },
	rust_analyzer = {},
	intelephense = {},
}
local lsp_server_names = vim.tbl_keys(lsp_servers)

require("mason").setup()

for server, config in pairs(lsp_servers) do
	vim.lsp.config(server, {
		settings = config,
		on_attach = function(_, bufnr)
			vim.keymap.set("n", "grd", vim.lsp.buf.definition, { buffer = bufnr })
		end,
	})
end

require("mason-lspconfig").setup({
	ensure_installed = lsp_server_names,
	automatic_enable = lsp_server_names,
})
local ok, sudo_write = pcall(require, "sudo_write")
if ok and sudo_write and sudo_write.setup then
	sudo_write.setup()
end
