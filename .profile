#!/usr/bin/env sh

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
export FNM_PATH="$XDG_DATA_HOME/fnm"
export MYSQL_HOST="127.0.0.1"
export PATH="$CARGOBIN:$BIN:$XDG_CONFIG_HOME/composer/vendor/bin:$PATH"




# export DISPLAY=:0

# ==========================================
# XDG Base Directory Specification
# ==========================================

# export XDG_CONFIG_HOME="$HOME/.config"
# export XDG_DATA_HOME="$HOME/.local/share"
# export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DESKTOP_PORTAL=1

# ==========================================
# User Information
# ==========================================
# export FULL_NAME=$(getent passwd $USER | cut -d: -f5 | cut -d, -f1)


# Other history files (shell-agnostic)
export LESSHISTFILE="$XDG_CACHE_HOME/less_history"

# ==========================================
# Path Configuration
# ==========================================


# GUI applications
export GTK2_RC_FILES="$XDG_CONFIG_HOME/gtk-2.0/gtkrc-2.0"
#export WGETRC="$XDG_CONFIG_HOME/wget/wgetrc"

# Development tools
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
# export CARGO_HOME="$XDG_DATA_HOME/cargo"
# export CARGOBIN="$CARGO_HOME/bin"
# export FNM_PATH="$XDG_DATA_HOME/fnm"
#export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
#export WINEPREFIX="$XDG_DATA_HOME/wineprefixes/default"

# Commented development paths
# export NUGET_PACKAGES="$XDG_CACHE_HOME/NuGetPackages"
# export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/pythonrc"
# export GOPATH="$XDG_DATA_HOME/go"
# export GOBIN="$GOPATH/bin"
# export GOMODCACHE="$XDG_CACHE_HOME/go/mod"
# export GRADLE_USER_HOME="$XDG_DATA_HOME/gradle"
# export _JAVA_OPTIONS=-Djava.util.prefs.userRoot="$XDG_CONFIG_HOME/java"
# export _JAVA_AWT_WM_NONREPARENTING=1
# export PARALLEL_HOME="$XDG_CONFIG_HOME/parallel"
# export FFMPEG_DATADIR="$XDG_CONFIG_HOME/ffmpeg"

# ==========================================
# Tool Configuration
# ==========================================
# FZF
export FZF_DEFAULT_OPTS="--style minimal --color 16 --layout=reverse --height 30% --preview='bat -p --color=always {}'"
export FZF_CTRL_R_OPTS="--style minimal --color 16 --info inline --no-sort --no-preview"

# Man pages
export MANPAGER="less -R --use-color -Dd+r -Du+b"
