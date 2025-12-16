#!/usr/bin/env bash
set -euo pipefail
export LANG=C
export LC_ALL=C

# ——————————————————————————————————————————————————————————————
# CLI flags
# ——————————————————————————————————————————————————————————————
POLKIT=0
for arg in "$@"; do
  case "$arg" in
    --polkit) POLKIT=1 ;;
  esac
done

# ——————————————————————————————————————————————————————————————
# Helpers
# ——————————————————————————————————————————————————————————————
has_cmd () { command -v "$1" >/dev/null 2>&1; }

get_aur_helper() {
  if has_cmd yay; then
    echo "yay"
  elif has_cmd paru; then
    echo "paru"
  else
    echo ""
  fi
}

print_header() {
  printf "\n▶ %s\n" "$1"
}

run_cmd() {
  local desc=$1
  local cmd=$2
  print_header "$desc"
  # Run command, piping stdout/stderr to stdout so Quickshell captures it
  if bash -c "$cmd"; then
    printf "[ OK ] %s\n" "$desc"
  else
    printf "[FAIL] %s\n" "$desc"
  fi
}

step_if() {
  local desc=$1
  local cond=$2
  local cmd=$3
  if bash -c "$cond" >/dev/null 2>&1; then
    run_cmd "$desc" "$cmd"
  else
    printf "[SKIP] %s (precondition not met)\n" "$desc"
  fi
}

# ——————————————————————————————————————————————————————————————
# Updates
# ——————————————————————————————————————————————————————————————

AUR_HELPER=$(get_aur_helper)

if [ "$POLKIT" = "1" ]; then
  step_if \
    "Update system packages (pkexec pacman)" \
    "command -v pkexec && command -v pacman" \
    "stdbuf -oL -eL pkexec pacman -Syu --noconfirm"
else
  step_if \
    "Update system packages ($AUR_HELPER)" \
    "[ -n \"$AUR_HELPER\" ]" \
    "stdbuf -oL -eL $AUR_HELPER -Syu --noconfirm"
fi

if [ "$POLKIT" = "1" ]; then
  step_if \
    "Update AUR packages ($AUR_HELPER)" \
    "[ -n \"$AUR_HELPER\" ]" \
    "stdbuf -oL -eL $AUR_HELPER -Sua --noconfirm"
fi

step_if \
  "Update Composer global packages" \
  "command -v composer" \
  "composer global update"

step_if \
  "Install/use latest Node LTS via fnm" \
  "command -v fnm" \
  "fnm use lts-latest --install-if-missing --silent-if-unchanged && fnm default lts-latest"

step_if \
  "Update Rust Cargo binaries" \
  "command -v cargo && command -v cargo-install-update" \
  "cargo install-update -a"

step_if \
  "Update Rust toolchain (rustup)" \
  "command -v rustup" \
  "rustup update"

printf "\nDone.\n"

