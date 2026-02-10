# 1. Environment
fish_add_path -a /mnt/Work/0Coding/Exercism
fish_add_path -a $HOME/.cache/.bun/bin

# 2. Context-Aware History
if set -q TERMINAL_EMULATOR
    set -gx fish_history phpstorm
else if set -q VSCODE_INJECTION
    set -gx fish_history vscode
else if set -q ZED_TERM
    set -gx fish_history zed
else
    set -gx fish_history fish
end
set -Ux MANPATH (man -w)

function fish_should_add_to_history
    string match -qr '^/mnt/Work/Downloads' -- $PWD; and return 1
    string match -qr '^\s|mnt/Work/Downloads|SDL_VIDEODRIVER=wayland' -- $argv; and return 1
    return 0
end

if status is-interactive
    # 3. Tool Initialization
    type -q zoxide; and zoxide init fish --cmd cd | source
    type -q starship; and starship init fish | source

    # 5. Smart Greeting
    function fish_greeting
        test "$fish_history" = fish; and type -q fastfetch; and fastfetch -c $HOME/.config/fastfetchTheme.jsonc
    end

    # 6. Abbreviations
    if type -q pacman
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

    abbr art 'php artisan'
    abbr gl 'git pull'
    abbr gp 'git push'
    abbr ola 'docker exec -it ollama ollama'
    abbr dots 'cd $DOTFILES'
    abbr .. 'cd ..'
    abbr ... 'cd ../..'
    abbr .... 'cd ../../..'
    abbr ..... 'cd ../../../..'
    alias fastfetchy 'fastfetch -c $HOME/.config/fastfetchTheme.jsonc'
    alias cat 'bat -pP'
    abbr tb 'nc termbin.com 9999'
    abbr errors 'journalctl -p 3 -xb'
    abbr hw 'hwinfo --short'
    
    # PostgreSQL environment variables
    set -gx PGHOST 127.0.0.1
    set -gx PGPORT 5432
    set -gx PGUSER root
end
