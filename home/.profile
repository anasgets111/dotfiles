#!/usr/bin/env sh

# ─── XDG Base Dirs ──────────────────────────────────────────────────────────────
export XDG_DOWNLOAD_DIR="/mnt/Work/Downloads"
export EDITOR="nvim"

# ─── User Info ──────────────────────────────────────────────────────────────────
FULL_NAME="$( getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)"
export FULL_NAME

# ─── Tool Homes ─────────────────────────────────────────────────────────────────
export CARGO_HOME="$HOME/.local/share/cargo"
export CARGOBIN="$CARGO_HOME/bin"
export FNM_PATH="$HOME/.local/share/fnm"
export GNUPGHOME="$HOME/.local/share/gnupg"
export MYSQL_HOST="127.0.0.1"
export BIN="$HOME/.local/bin"
export GTK2_RC_FILES="$HOME/.config/gtk-2.0/gtkrc-2.0"
export LESSHISTFILE="$HOME/.cache/less_history"

# ─── NVIDIA (conditional) ───────────────────────────────────────────────────────
if command -v nvidia-smi >/dev/null 2>&1; then
  export LIBVA_DRIVER_NAME="nvidia"
  export NVD_BACKEND="direct"
  export GBM_BACKEND="nvidia-drm"
  export __GL_GSYNC_ALLOWED="1"
  export __GLX_VENDOR_LIBRARY_NAME="nvidia"
  export EGL_PLATFORM="wayland"
fi

# ─── Wayland Toolkits ───────────────────────────────────────────────────────────
export QT_QPA_PLATFORM="wayland"
export GDK_BACKEND="wayland"
export CLUTTER_BACKEND="wayland"
export MOZ_ENABLE_WAYLAND="1"
export ELECTRON_OZONE_PLATFORM_HINT="auto"
export ELECTRON_ENABLE_FEATURES="UseOzonePlatform,WaylandWindowDecorations,WaylandLinuxDrmSyncobj"

# ─── Scaling ────────────────────────────────────────────────────────────────────
export GDK_SCALE="1"
export QT_SCALE_FACTOR="1"
export QT_AUTO_SCREEN_SCALE_FACTOR="1"

# ─── Qt Theming ─────────────────────────────────────────────────────────────────
export QT_QPA_PLATFORMTHEME="qt6ct"


# ─── PATH ───────────────────────────────────────────────────────────────────────
export PATH="$CARGOBIN:$BIN:$HOME/.config/composer/vendor/bin:$PATH"

# ─── Dotfiles & Secrets ─────────────────────────────────────────────────────────
export DOTFILES="/mnt/Work/1Progs/Dots"
CRED_FILE="$DOTFILES/.local_secrets/credentials.sh"
if [ -n "$DOTFILES" ] && [ -r "$CRED_FILE" ]; then
  # shellcheck disable=SC1090
  . "$CRED_FILE" || printf 'Warning: failed to source %s\n' "$CRED_FILE" >&2
fi

# ─── fnm (Node version manager) ─────────────────────────────────────────────────
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --shell=bash --use-on-cd --version-file-strategy=recursive --resolve-engines 2>/dev/null || true)"
fi

# ─── Drop into Fish ─────────────────────────────────────────────────────────────