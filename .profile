# Get full name from /etc/passwd
FULL_NAME=$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)
export FULL_NAME

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_DOWNLOAD_DIR="/mnt/Work/Downloads/"
export BIN="$HOME/.local/bin"
export GTK2_RC_FILES="$XDG_CONFIG_HOME/gtk-2.0"

export CARGO_HOME="$XDG_DATA_HOME/cargo"
export CARGOBIN="$CARGO_HOME/bin"
export FNM_Path="$XDG_DATA_HOME/fnm"
export MYSQL_HOST="127.0.0.1"
export PATH="$CARGOBIN:$BIN:$XDG_CONFIG_HOME/composer/vendor/bin:$PATH"
