# 1. Environment
fish_add_path -a /mnt/Work/0Coding/Exercism
fish_add_path -a $HOME/.cache/bun/bin

# 2. Context-Aware History (Ordered by priority: Generic -> Specific)
set -gx fish_history fish
set -q TERMINAL_EMULATOR; and set -gx fish_history phpstorm
set -q VSCODE_INJECTION; and set -gx fish_history vscode
set -q CURSOR_TRACE_ID; and set -gx fish_history cursor
string match -q Zed "$TERM_PROGRAM"; and set -gx fish_history zed

function fish_should_add_to_history
    # 1. Ignore commands executed while in specific directories
    string match -qr '^/mnt/Work/Downloads' -- $PWD; and return 1
    # 2. Ignore specific patterns in the command itself
    string match -qr '^\s|mnt/Work/Downloads|SDL_VIDEODRIVER=wayland' -- $argv; and return 1
    # 3. Allow everything else
    return 0
end

# 3. Tool Initialization
type -q zoxide; and zoxide init fish --cmd cd | source
type -q starship; and starship init fish | source

# 4. Theme
fish_config theme choose --color-theme=dark "Catppuccin Mocha"

# 5. Smart Greeting (Runs only in pure terminals)
function fish_greeting
    if test "$fish_history" = fish
        type -q fastfetch; and fastfetch -c $HOME/.config/fastfetchTheme.jsonc
    end
end

# 6. Abbreviations
if type -q pacman
    # --- Arch Maintenance ---
    abbr pacin 'sudo pacman -S'
    abbr pacinn 'sudo pacman -S --needed'
    abbr pacrem 'sudo pacman -Rns'
    abbr orphans 'pacman -Qdtq | sudo pacman -Rns -'
    abbr mirrors 'sudo rate-mirrors --protocol https --allow-root --save /etc/pacman.d/mirrorlist --disable-comments-in-file arch'
    abbr mirrors-aur 'sudo rate-mirrors --disable-comments-in-file --protocol=https --allow-root --save /etc/pacman.d/chaotic-mirrorlist chaotic-aur'

    abbr drop-cache 'sudo paccache -rk3; and sudo pacman -Sc --noconfirm'
    abbr fixpacman 'sudo rm /var/lib/pacman/db.lck'

    abbr big "expac -H M '%m\t%n' | sort -h | nl"
    abbr rip "expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
end

# --- Dev Stack ---
abbr art 'php artisan'
abbr gl 'git pull'
abbr gp 'git push'
abbr ola 'docker exec -it ollama ollama'
abbr dots 'cd $DOTFILES'

# --- Navigation ---
abbr .. 'cd ..'
abbr ... 'cd ../..'
abbr .... 'cd ../../..'
abbr ..... 'cd ../../../..'

# --- Utilities ---
alias fastfetchy 'fastfetch -c $HOME/.config/fastfetchTheme.jsonc'
abbr tb 'nc termbin.com 9999'
abbr errors 'journalctl -p 3 -xb'
abbr hw 'hwinfo --short'
