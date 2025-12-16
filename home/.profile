#!/usr/bin/env sh

# ─── User Info (dynamic) ────────────────────────────────────────────────────────
FULL_NAME="$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)"
export FULL_NAME

# ─── PATH (shell-managed) ───────────────────────────────────────────────────────
# CARGOBIN and BIN are set in environment.d
PATH="$(
  printf '%s' "${CARGOBIN:-}:${BIN:-}:$HOME/.config/composer/vendor/bin:$PATH" |
    sed 's/^://; s/::*/:/g'
)"
export PATH

# ─── NVIDIA (conditional) ───────────────────────────────────────────────────────
if command -v nvidia-smi >/dev/null 2>&1; then
  export LIBVA_DRIVER_NAME="nvidia"
  export NVD_BACKEND="direct"
  export GBM_BACKEND="nvidia-drm"
  export __GL_GSYNC_ALLOWED="1"
  export __GLX_VENDOR_LIBRARY_NAME="nvidia"
  export EGL_PLATFORM="wayland"
fi

# ─── Dotfiles & Secrets ─────────────────────────────────────────────────────────
# DOTFILES is set in environment.d
if [ -r "$DOTFILES/.local_secrets/credentials.sh" ]; then
  # shellcheck source=/dev/null
  . "$DOTFILES/.local_secrets/credentials.sh" || printf 'Warning: failed to source credentials\n' >&2
fi

# ─── fnm (shell hook) ──────────────────────────────────────────────────────────
if command -v fnm >/dev/null 2>&1; then
  eval "$(
    fnm env \
      --shell=bash \
      --use-on-cd \
      --version-file-strategy=recursive \
      --resolve-engines
  )"
fi

# ─── Drop into Fish ─────────────────────────────────────────────────────────────
if [ -t 1 ] && [ -z "$FISH_VERSION" ]; then
  exec fish --login
fi