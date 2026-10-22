-- Colour scheme presets for `lib/app_colours.lua`, each on Catppuccin's slot names so one mapping
-- (`theme.preset_roles`) serves all: eight surfaces and text tones, then eight accents. A scheme
-- without a slot repeats its nearest official colour there.
return {
    catppuccin = {
        label = "Catppuccin",
        default_accent = "mauve",
        -- Mocha and Latte, catppuccin/palette v1.8.0.
        dark = { base = "#1e1e2e", mantle = "#181825", crust = "#11111b", surface0 = "#313244", surface1 = "#45475a", overlay0 = "#6c7086", subtext0 = "#a6adc8", text = "#cdd6f4", red = "#f38ba8", peach = "#fab387", yellow = "#f9e2af", green = "#a6e3a1", teal = "#94e2d5", blue = "#89b4fa", mauve = "#cba6f7", pink = "#f5c2e7" },
        light = { base = "#eff1f5", mantle = "#e6e9ef", crust = "#dce0e8", surface0 = "#ccd0da", surface1 = "#bcc0cc", overlay0 = "#9ca0b0", subtext0 = "#6c6f85", text = "#4c4f69", red = "#d20f39", peach = "#fe640b", yellow = "#df8e1d", green = "#40a02b", teal = "#179299", blue = "#1e66f5", mauve = "#8839ef", pink = "#ea76cb" },
    },
    rosepine = {
        label = "Rosé Pine",
        default_accent = "mauve",
        -- Main and Dawn, rose-pine/palette. Main has nothing darker than base; green is pine, teal and
        -- blue are both foam, peach and pink both rose, as its kitty port does.
        dark = { base = "#191724", mantle = "#191724", crust = "#191724", surface0 = "#26233a", surface1 = "#403d52", overlay0 = "#6e6a86", subtext0 = "#908caa", text = "#e0def4", red = "#eb6f92", peach = "#ebbcba", yellow = "#f6c177", green = "#31748f", teal = "#9ccfd8", blue = "#9ccfd8", mauve = "#c4a7e7", pink = "#ebbcba" },
        light = { base = "#faf4ed", mantle = "#f2e9e1", crust = "#dfdad9", surface0 = "#dfdad9", surface1 = "#cecacd", overlay0 = "#9893a5", subtext0 = "#797593", text = "#464261", red = "#b4637a", peach = "#d7827e", yellow = "#ea9d34", green = "#286983", teal = "#56949f", blue = "#56949f", mauve = "#907aa9", pink = "#d7827e" },
    },
    gruvbox = {
        label = "Gruvbox",
        default_accent = "yellow",
        -- Medium contrast, morhetz/gruvbox: bright colours on dark, faded on light; pink repeats purple.
        dark = { base = "#282828", mantle = "#1d2021", crust = "#1d2021", surface0 = "#3c3836", surface1 = "#504945", overlay0 = "#928374", subtext0 = "#d5c4a1", text = "#ebdbb2", red = "#fb4934", peach = "#fe8019", yellow = "#fabd2f", green = "#b8bb26", teal = "#8ec07c", blue = "#83a598", mauve = "#d3869b", pink = "#d3869b" },
        light = { base = "#fbf1c7", mantle = "#f2e5bc", crust = "#ebdbb2", surface0 = "#d5c4a1", surface1 = "#bdae93", overlay0 = "#928374", subtext0 = "#504945", text = "#3c3836", red = "#9d0006", peach = "#af3a03", yellow = "#b57614", green = "#79740e", teal = "#427b58", blue = "#076678", mauve = "#8f3f71", pink = "#8f3f71" },
    },
    tokyonight = {
        label = "Tokyo Night",
        default_accent = "blue",
        -- Night and Day, folke/tokyonight.nvim extras; pink is magenta2.
        dark = { base = "#1a1b26", mantle = "#16161e", crust = "#0c0e14", surface0 = "#292e42", surface1 = "#3b4261", overlay0 = "#565f89", subtext0 = "#a9b1d6", text = "#c0caf5", red = "#f7768e", peach = "#ff9e64", yellow = "#e0af68", green = "#9ece6a", teal = "#1abc9c", blue = "#7aa2f7", mauve = "#bb9af7", pink = "#ff007c" },
        light = { base = "#e1e2e7", mantle = "#d0d5e3", crust = "#c1c9df", surface0 = "#c4c8da", surface1 = "#a8aecb", overlay0 = "#848cb5", subtext0 = "#6172b0", text = "#3760bf", red = "#f52a65", peach = "#b15c00", yellow = "#8c6c3e", green = "#587539", teal = "#118c74", blue = "#2e7de9", mauve = "#9854f1", pink = "#d20065" },
    },
    dracula = {
        label = "Dracula",
        default_accent = "mauve",
        -- Dracula and Alucard, draculatheme.com/spec; blue repeats cyan, and dark subtext0 mixes
        -- comment and foreground, since the spec has no secondary text.
        dark = { base = "#282a36", mantle = "#21222c", crust = "#191a21", surface0 = "#343746", surface1 = "#424450", overlay0 = "#6272a4", subtext0 = "#adb5cb", text = "#f8f8f2", red = "#ff5555", peach = "#ffb86c", yellow = "#f1fa8c", green = "#50fa7b", teal = "#8be9fd", blue = "#8be9fd", mauve = "#bd93f9", pink = "#ff79c6" },
        light = { base = "#fffbeb", mantle = "#ece9df", crust = "#dedccf", surface0 = "#ceccc0", surface1 = "#bcbab3", overlay0 = "#6c664b", subtext0 = "#2c2b31", text = "#1f1f1f", red = "#cb3a2a", peach = "#a34d14", yellow = "#846e15", green = "#14710a", teal = "#036a96", blue = "#036a96", mauve = "#644ac9", pink = "#a3144d" },
    },
}
