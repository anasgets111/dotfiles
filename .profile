#!/usr/bin/env sh

# ─── XDG Base Dirs ─────────────────────────────────
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DOWNLOAD_DIR="/mnt/Work/Downloads"

# ─── User Info ──────────────────────────────────────────────────────────────────
FULL_NAME="$( getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)"
export FULL_NAME

# ─── Tool Homes & App Settings ─────────────────────────────────────────────────
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export CARGOBIN="$CARGO_HOME/bin"
export FNM_PATH="$XDG_DATA_HOME/fnm"
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
export MYSQL_HOST="127.0.0.1"
export BIN="$HOME/.local/bin"
export GTK2_RC_FILES="$XDG_CONFIG_HOME/gtk-2.0/gtkrc-2.0"
export LESSHISTFILE="$XDG_CACHE_HOME/less_history"

# ─── PATH ───────────────────────────────────────────────────────────────────────
export PATH="$CARGOBIN:$BIN:$XDG_CONFIG_HOME/composer/vendor/bin:$PATH"

eval "$( fnm env --use-on-cd --version-file-strategy=recursive --resolve-engines )"
# ─── FALL INTO FISH ONCE YOUR ENV IS SET ────────────────────────────────────────
# If this is an interactive login (tty or GUI), and we're not already in fish…
if [ -t 1 ] && [ -z "$FISH_VERSION" ]; then
  exec fish --login
fi
