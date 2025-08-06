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
source ./catppuccin_mocha.nu
source ./packages.nu

$env.config.buffer_editor = "nvim"
$env.config.show_banner = false

$env.config.keybindings ++= [
  {
    name: ctrl_delete_kill_line
    modifier: control
    keycode: delete
    mode: [emacs, vi_insert]
    event: { edit: KillLine }
  }
  {
    name: delete_kill_word
    modifier: none
    keycode: delete
    mode: [emacs, vi_insert]
    event: { edit: DeleteWord }
  }
  {
    name: alt_delete_kill_word
    modifier: alt
    keycode: backspace
    mode: [emacs, vi_insert]
    event: { edit: CutFromLineStart }
  }
]

def sail [...argv] {
  if ("sail" | path exists) {
    sail ...$argv
  } else if ("vendor/bin/sail" | path exists) {
    vendor/bin/sail ...$argv
  } else {
    print "no sail found"
  }
}

def errors [] {
  journalctl -p 3 -xb --no-pager
  | parse "{month} {day} {time} {host} {app}[{pid}]: {message}"
  | select month day time host app pid message
}

alias fastfetchy = fastfetch --load-config $"($env.XDG_CONFIG_HOME)/fastfetchTheme.jsonc"

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

fastfetchy

oh-my-posh init nu