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


# Display
# export DISPLAY=":1"
# Qt & EGL selection
if command -v nvidia-smi >/dev/null 2>&1; then
  # NVIDIA drivers
  export LIBVA_DRIVER_NAME="nvidia"
  export __GLX_VENDOR_LIBRARY_NAME="nvidia"
  export NVD_BACKEND="direct"

  # Use EGLStreams plugin
  export QT_QPA_PLATFORM="wayland"
  export EGL_PLATFORM="wayland_egl"
else
  # Fallback to standard Wayland
  export QT_QPA_PLATFORM="wayland"
  export EGL_PLATFORM="wayland"
fi

# Common Wayland & Electron
export GDK_BACKEND="wayland"
export CLUTTER_BACKEND="wayland"
export MOZ_ENABLE_WAYLAND="1"
export ELECTRON_OZONE_PLATFORM_HINT="auto"
export ELECTRON_ENABLE_FEATURES="UseOzonePlatform,WaylandWindowDecorations,WaylandLinuxDrmSyncobj"
# Scaling
export GDK_SCALE="1"
export QT_SCALE_FACTOR="1"
export QT_AUTO_SCREEN_SCALE_FACTOR="1"
# Theming
export QT_QPA_PLATFORMTHEME="qt6ct"
# Input (fcitx)
export INPUT_METHOD="fcitx"
export QT_IM_MODULE="fcitx"
export XMODIFIERS="@im=fcitx"
export SDL_IM_MODULE="fcitx"
# Input (ibus)
export GLFW_IM_MODULE="ibus"

# ─── PATH ───────────────────────────────────────────────────────────────────────
export PATH="$CARGOBIN:$BIN:$XDG_CONFIG_HOME/composer/vendor/bin:$PATH"

# Dotfiles base directory
export DOTFILES="/mnt/Work/1Progs/Dots"

# Source credentials if present
CRED_FILE="$DOTFILES/.local_secrets/credentials.sh"
[ -f "$CRED_FILE" ] && . "$CRED_FILE"


eval "$( fnm env --shell=bash --use-on-cd --version-file-strategy=recursive --resolve-engines )"
# ─── FALL INTO FISH ONCE YOUR ENV IS SET ────────────────────────────────────────
# If this is an interactive login (tty or GUI), and we're not already in fish…
if [ -t 1 ] && [ -z "$FISH_VERSION" ]; then
  exec fish --login
fi

# Set git signingkey from SIGNINGKEY env var if available
if [ -n "$SIGNINGKEY" ]; then
  git config --global user.signingkey "$SIGNINGKEY"
fi
