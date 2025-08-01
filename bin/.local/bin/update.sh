#!/usr/bin/env bash
set -euo pipefail

# ——————————————————————————————————————————————————————————————
# Terminal title
# ——————————————————————————————————————————————————————————————
printf '\033]2;Global Updates\007'

# ——————————————————————————————————————————————————————————————
# ANSI color codes
# ——————————————————————————————————————————————————————————————
BLUE="\033[34m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BOLD="\033[1m"
RESET="\033[0m"

# ——————————————————————————————————————————————————————————————
# Logging functions
# ——————————————————————————————————————————————————————————————
log_info ()    { echo -e "${BLUE}${BOLD}[INFO]${RESET}  $*"; }
log_success () { echo -e "${GREEN}${BOLD}[ OK ]${RESET}  $*"; }
log_error ()   { echo -e "${RED}${BOLD}[FAIL]${RESET}  $*"; }

# ——————————————————————————————————————————————————————————————
# 1) System update
# ——————————————————————————————————————————————————————————————
log_info "Updating system packages (paru -Syu)…"
if paru -Syu --noconfirm; then
  log_success "System packages up to date."
else
  log_error "paru -Syu encountered an error."
fi

# ——————————————————————————————————————————————————————————————
# 2) Composer globals
# ——————————————————————————————————————————————————————————————
log_info "Updating Composer global packages…"
if composer global update; then
  log_success "Composer packages updated."
else
  log_error "composer global update failed."
fi

# ——————————————————————————————————————————————————————————————
# 3) fnm (Node LTS)
# ——————————————————————————————————————————————————————————————
log_info "Installing latest Node LTS via fnm…"
if fnm use lts-latest --install-if-missing --silent-if-unchanged && fnm default lts-latest; then
  log_success "fnm LTS install succeeded."
else
  log_error "fnm install lts-latest failed."
fi

# ——————————————————————————————————————————————————————————————
# 4) Cargo packages
# ——————————————————————————————————————————————————————————————
log_info "Updating Rust cargo binaries…"
if cargo install-update -a; then
  log_success "Cargo binaries updated."
else
  log_error "cargo update failed."
fi

# ——————————————————————————————————————————————————————————————
# 5) Rust toolchain
# ——————————————————————————————————————————————————————————————
log_info "Updating Rust toolchain (rustup)…"
if rustup update; then
  log_success "rustup update completed."
else
  log_error "rustup update failed."
fi

# ——————————————————————————————————————————————————————————————
# Done
# ——————————————————————————————————————————————————————————————
echo
read -n1 -p $'\033[35m\033[1m[ DONE ] Press any key to close…\033[0m'
echo
