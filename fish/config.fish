# Shared global color variables
set -g GREEN (set_color green)
set -g BLUE (set_color blue)
set -g CYAN (set_color cyan)
set -g RED (set_color red)
set -g YELLOW (set_color yellow)
set -g RESET (set_color normal)

set -x MYSQL_HOST 127.0.0.1

# set -g fish_key_bindings fish_vi_key_bindings

# Fish Greeting
function fish_greeting
    if not set -q ZED_TERM; and not set -q VSCODE_INJECTION; and not set -q TERMINAL_EMULATOR
        fastfetchy
    end
end

# if fish is open by vscode terminal then use a different history file
if set -q ZED_TERM
    set -gx fish_history "zed"
else if set -q VSCODE_INJECTION

    set -gx fish_history "vscode"
else if set -q TERMINAL_EMULATOR
    set -gx fish_history  "phpstorm"

else
    set -gx fish_history "fish"
end


# Define a list of new paths
set -l new_paths \
    "$CARGOBIN/"\
    "$HOME/.local/bin" \
    "$XDG_CONFIG_HOME/composer/vendor/bin"

# Prepend the new paths to PATH
set -gx PATH $new_paths $PATH



# Aliases
# Alias to drop caches
alias drop-cache 'sudo paccache -rk3; and paru -Sc --aur --noconfirm'
alias orphans 'pacman -Qdtq | sudo pacman -Rns -'
alias mirror 'rate-mirrors  --disable-comments-in-file --protocol=https arch | sudo tee /etc/pacman.d/mirrorlist'
alias mirror-aur 'rate-mirrors chaotic-aur | sudo tee /etc/pacman.d/chaotic-mirrorlist'
alias exercism "/mnt/Work/0Coding/exercism-3.5.4-linux-x86_64/exercism"
alias ola="docker exec -it ollama ollama"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias update='paru'
alias art='php artisan'
alias pacin='sudo pacman -S'
alias pacinn='sudo pacman -S --needed'
alias pacre='sudo pacman -R'
alias pacrem='sudo pacman -Rsn'
alias gl='git pull'
alias hw='hwinfo --short'  # Hardware Info
alias big="expac -H M '%m\t%n' | sort -h | nl"  # Sort installed packages according to size in MB
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias fastfetchy="fastfetch --load-config $HOME/.config/fastfetchTheme.jsonc"
alias gedit="gnome-text-editor"
alias errors="journalctl -p 3 -xb"
alias tb='nc termbin.com 9999'
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
alias grep='rg'
alias ls="eza --icons --hyperlink"
alias cat="bat"
alias cd="z"

# Initialization for Tools
zoxide init fish | source
#starship init fish | source
fnm env --use-on-cd --version-file-strategy=recursive --resolve-engines | source
oh-my-posh init fish --config $HOME/.config/standard.omp.toml | source
