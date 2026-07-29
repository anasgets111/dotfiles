if status is-login; and not set -q DOTFILES; and type -q bass
    bass source ~/.profile
end
