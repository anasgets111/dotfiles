# Shared global color variables
set -g GREEN (set_color green)
set -g BLUE (set_color blue)
set -g CYAN (set_color cyan)
set -g RED (set_color red)
set -g YELLOW (set_color yellow)
set -g RESET (set_color normal)

# set -g fish_key_bindings fish_vi_key_bindings

# Fish Greeting
function fish_greeting
    if not set -q ZED_TERM; and not set -q VSCODE_INJECTION; and not set -q TERMINAL_EMULATOR
        fastfetchy
    end
end

# choose history file per terminal type
if set -q ZED_TERM
    set -gx fish_history zed
else if set -q VSCODE_INJECTION
    set -gx fish_history vscode
else if set -q TERMINAL_EMULATOR
    set -gx fish_history phpstorm
else
    set -gx fish_history fish
end

# Aliases
# Alias to drop caches
abbr drop-cache 'sudo paccache -rk3; and paru -Sc --aur --noconfirm'
abbr orphans 'pacman -Qdtq | sudo pacman -Rns -'
abbr mirror 'sudo rate-mirrors --protocol https --allow-root --save /etc/pacman.d/mirrorlist --disable-comments-in-file arch'
abbr mirror-aur 'sudo rate-mirrors --disable-comments-in-file --protocol=https --allow-root --save /etc/pacman.d/chaotic-mirrorlist chaotic-aur'
abbr exercism "/mnt/Work/0Coding/exercism-3.5.4-linux-x86_64/exercism"
abbr ola "docker exec -it ollama ollama"
abbr fixpacman "sudo rm /var/lib/pacman/db.lck"
abbr art 'php artisan'
abbr pacin 'sudo pacman -S'
abbr pacinn 'sudo pacman -S --needed'
abbr pacre 'sudo pacman -R'
abbr pacrem 'sudo pacman -Rsn'
abbr gl 'git pull'
abbr gp 'git push'
abbr hw 'hwinfo --short' # Hardware Info
abbr big "expac -H M '%m\t%n' | sort -h | nl" # Sort installed packages according to size in MB
abbr .. 'cd ..'
abbr ... 'cd ../..'
abbr .... 'cd ../../..'
abbr ..... 'cd ../../../..'
abbr ...... 'cd ../../../../..'
alias fastfetchy="fastfetch -c $XDG_CONFIG_HOME/fastfetchTheme.jsonc"
abbr errors "journalctl -p 3 -xb"
abbr tb 'nc termbin.com 9999'
abbr rip "expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
alias cd z
abbr dots 'cd $DOTFILES; and stow '

# Initialization for Tools
zoxide init fish | source
starship init fish | source
