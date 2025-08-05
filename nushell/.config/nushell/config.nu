# config.nu
#
# Installed by:
# version = "0.106.1"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings, 
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R

alias fastfetchy = fastfetch --load-config $"($env.XDG_CONFIG_HOME)/fastfetchTheme.jsonc"
alias errors = journalctl -p 3 -xb
alias fixpacman = sudo rm /var/lib/pacman/db.lck
alias exercism = /mnt/Work/0Coding/exercism-3.5.4-linux-x86_64/exercism
alias ola = docker exec -it ollama ollama
alias art = php artisan
alias pacinn = paru -S --needed
alias pacin = paru -S
alias pacre = paru -R
alias pacrem = paru -Rns
alias gl = git pull
alias gp = git push

oh-my-posh init nu
