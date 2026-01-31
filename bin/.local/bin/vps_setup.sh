#!/usr/bin/env bash

# vps_setup.sh
# Simplified VPS setup: Starship, Fish (Dark Theme), Bash->Fish switch

set -e

echo "Starting VPS environment setup..."

# 0. Install Dependencies
echo "Installing dependencies (sudo required)..."
sudo apt update
sudo apt install -y fish starship


# 1. Directory Structure
CONFIG_DIR="$HOME/.config"
FISH_DIR="$CONFIG_DIR/fish"
THEME_DIR="$FISH_DIR/themes"

mkdir -p "$CONFIG_DIR"
mkdir -p "$FISH_DIR/conf.d"
mkdir -p "$THEME_DIR"

echo "Directories created."

# 2. Starship Configuration
echo "Writing starship.toml..."
cat << 'EOF' > "$CONFIG_DIR/starship.toml"
# @schema https://starship.rs/config-schema.json
add_newline = false
# Toggle between "dark", "light", and "dark_inverted"
palette = "dark"

format = """
[╭─](mauve)$os$shell$username$hostname$directory$git_branch$git_status$cmd_duration$fill\
$nodejs$python$php$rust$golang$time$line_break\
[╰─](mauve)$character"""

# DARK MODE (Original Custom - Light Grey End)
[palettes.dark]
mauve = "#CBA6F7"
green_success = "#a3daa8"
red_error = "#ef5350"
text_light = "#E0DEF4"
surface_dark = "#444859"
overlay_grey = "#C6C3CE"
base_dark = "#1E1E2E"
red_root = "#F38BA8"
# High-Contrast Git Colors
git_red = "#B71C1C"
git_green = "#1B5E20"
git_orange = "#E65100"
git_teal = "#004D40"
git_blue = "#0D47A1"
git_purple = "#4A148C"

[character]
success_symbol = "[ ](green_success)"
error_symbol = "[ ](red_error)"
format = "$symbol"

[fill]
symbol = " "

[os]
format = "[](surface_dark)[$symbol ](text_light bg:surface_dark)"
disabled = false
[os.symbols]
Arch = ""
Fedora = ""
Debian = ""
Ubuntu = ""
NixOS = ""
Macos = ""
Windows = ""

[shell]
format = "[$indicator](text_light bg:surface_dark)[](fg:surface_dark bg:overlay_grey)"
disabled = false
bash_indicator = " "
zsh_indicator = " "
nu_indicator = " "
fish_indicator = " "
unknown_indicator = " "

[username]
show_always = true
format = "[ $user](base_dark bg:overlay_grey)"
style_user = "base_dark"
style_root = "red_root"

[hostname]
ssh_only = false
format = "[:$hostname ](base_dark bg:overlay_grey)[](fg:overlay_grey bg:text_light)"
ssh_symbol = ""

[directory]
style = "base_dark bg:text_light"
truncation_length = 4
truncate_to_repo = true
home_symbol = ""
read_only = " "
format = "[  $path]($style)[$read_only]($style)"

[git_branch]
style = "base_dark bg:text_light"
symbol = " "
format = "[| $symbol$branch]($style)"

[git_status]
style = "base_dark bg:text_light"
format = "[$ahead_behind$all_status]($style)"
ignore_submodules = true
modified = "[ $count](git_red bg:text_light)"
staged = "[ $count](git_green bg:text_light)"
untracked = "[ $count](git_orange bg:text_light)"
stashed = "[ $count](git_teal bg:text_light)"
behind = "[ ⇣$count](git_red bg:text_light)"
ahead = "[ ⇡$count](git_blue bg:text_light)"
conflicted = "[ $count](git_purple bg:text_light)"
deleted = "[ $count](git_purple bg:text_light)"
renamed = "[ $count](git_purple bg:text_light)"

[cmd_duration]
show_milliseconds = true
min_time = 0
format = "[](fg:text_light bg:mauve)[  $duration ](base_dark bg:mauve)[](mauve)"

[nodejs]
format = "[](mauve)[ $version](base_dark bg:mauve)[](mauve) "
version_format = "${major}.${minor}"
detect_files = ["package.json"]

[python]
format = "[](text_light)[ $virtualenv $version](base_dark bg:text_light)[](text_light) "
version_format = "${major}"

[php]
format = "[](text_light)[ $version](base_dark bg:text_light)[](text_light) "
version_format = "${major}.${minor}"

[rust]
format = "[](text_light)[ $version](base_dark bg:text_light)[](text_light) "
version_format = "${major}"

[golang]
format = "[](text_light)[ $version](base_dark bg:text_light)[](text_light) "
version_format = "${major}"

[time]
disabled = false
format = "[](overlay_grey)[  $time ](base_dark bg:overlay_grey)[](overlay_grey)"
use_12hr = true
time_format = "%I:%M %p"
EOF

# 3. Fish Theme (Catppuccin Mocha - Dark Only)
echo "Writing Fish theme..."
cat << 'EOF' > "$THEME_DIR/Catppuccin Mocha.theme"
# name: 'Catppuccin Mocha'
# url: 'https://github.com/catppuccin/fish'

# preferred_background: 1e1e2e
fish_color_normal cdd6f4
fish_color_command 89b4fa
fish_color_param f2cdcd
fish_color_keyword cba6f7
fish_color_quote a6e3a1
fish_color_redirection f5c2e7
fish_color_end fab387
fish_color_comment 7f849c
fish_color_error f38ba8
fish_color_gray 6c7086
fish_color_selection --background=313244
fish_color_search_match --background=313244
fish_color_option a6e3a1
fish_color_operator f5c2e7
fish_color_escape eba0ac
fish_color_autosuggestion 6c7086
fish_color_cancel f38ba8
fish_color_cwd f9e2af
fish_color_user 94e2d5
fish_color_host 89b4fa
fish_color_host_remote a6e3a1
fish_color_status f38ba8
fish_pager_color_progress 6c7086
fish_pager_color_prefix f5c2e7
fish_pager_color_completion cdd6f4
fish_pager_color_description 6c7086
EOF

# 4. Fish Configuration
echo "Writing config.fish..."
cat << 'EOF' > "$FISH_DIR/config.fish"
# 1. Environment
# Local paths removed

# 2. History
set -gx fish_history fish

# 3. Tool Initialization
type -q starship; and starship init fish | source

# 4. Theme
fish_config theme choose "Catppuccin Mocha"

# 5. Greeting
set -U fish_greeting ""

# 6. Abbreviations

# --- Navigation ---
abbr .. 'cd ..'
abbr ... 'cd ../..'
abbr .... 'cd ../../..'
abbr ..... 'cd ../../../..'

# --- Git ---
abbr gl 'git pull'
abbr gp 'git push'
abbr gs 'git status'
abbr gd 'git diff'
abbr gc 'git commit'

# --- Utilities ---
abbr tb 'nc termbin.com 9999'
abbr errors 'journalctl -p 3 -xb'
abbr ll 'ls -lah'
EOF

# 5. Bashrc Modification
echo "Configuring .bashrc to execute fish..."
if ! grep -q "exec fish --login" "$HOME/.bashrc"; then
    # Ensure there is a newline before appending
    echo "" >> "$HOME/.bashrc"
    cat << 'EOF' >> "$HOME/.bashrc"

# If this is an interactive non-login bash, exec fish
if [ -t 1 ] && [ -z "$FISH_VERSION" ] && [ -z "$STAY" ]; then
  exec fish --login
fi
EOF
    echo "Added fish switch to .bashrc"
else
    echo ".bashrc already configured for fish"
fi

echo "--------------------------------------------------------"
echo "Setup complete!"
echo "Make sure 'fish' and 'starship' are installed."
