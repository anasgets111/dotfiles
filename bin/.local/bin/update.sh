#!/usr/bin/env bash
set -euo pipefail

# ——————————————————————————————————————————————————————————————
# Terminal title
# ——————————————————————————————————————————————————————————————
printf '\033]2;Global Updates\007'

# ——————————————————————————————————————————————————————————————
# CLI flags
#   --quiet     Reduce noise: show only step results, and dump output on failure (default: verbose)
# ——————————————————————————————————————————————————————————————
QUIET=${QUIET:-0}
for arg in "$@"; do
  case "$arg" in
  --quiet) QUIET=1 ;;
  esac
done

# ——————————————————————————————————————————————————————————————
# Capability detection
# ——————————————————————————————————————————————————————————————
is_tty() { [ -t 1 ]; }
has_cmd () { command -v "$1" >/dev/null 2>&1; }

supports_color() {
  if ! is_tty; then return 1; fi
  if has_cmd tput; then
    local colors
    colors=$(tput colors 2>/dev/null || echo 0)
    [ "${colors}" -ge 8 ]
  else
    return 1
  fi
}

# ——————————————————————————————————————————————————————————————
# Theme
# ——————————————————————————————————————————————————————————————
if supports_color; then
  BLUE=$'\033[34m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; MAGENTA=$'\033[35m'
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  BLUE=""; GREEN=""; YELLOW=""; RED=""; MAGENTA=""; BOLD=""; DIM=""; RESET=""
fi

OK_TAG="${GREEN}${BOLD}[ OK ]${RESET}"
FAIL_TAG="${RED}${BOLD}[FAIL]${RESET}"
SKIP_TAG="${YELLOW}${BOLD}[SKIP]${RESET}"
INFO_TAG="${BLUE}${BOLD}[INFO]${RESET}"

bullet="•"
arrow="▶"

# ——————————————————————————————————————————————————————————————
# Layout helpers
# ——————————————————————————————————————————————————————————————
term_cols() {
  local cols
  if is_tty && has_cmd tput; then
    cols=$(tput cols 2>/dev/null || echo 80)
  else
    cols=${COLUMNS:-80}
  fi
  echo "${cols}"
}

# Fixed column to align the status tags; adapt to terminal width
calc_leader_col() {
  local cols; cols=$(term_cols)
  local target=60
  if [ "$cols" -lt 70 ]; then
    target=$(( cols - 12 ))
    if [ "$target" -lt 30 ]; then target=30; fi
  fi
  echo "$target"
}

LEADER_COL=$(calc_leader_col)

print_header() {
  local title=$1
  printf "\n%s%s %s%s\n" "$MAGENTA$BOLD" "$arrow" "$title" "$RESET"
}

print_line() {
  # Arguments: description, status_tag
  local desc=$1
  local status=$2
  local prefix="  ${bullet} ${desc}"
  local prefix_len=${#prefix}
  local fill=""
  if [ "$prefix_len" -lt "$LEADER_COL" ]; then
    local dots=$(( LEADER_COL - prefix_len ))
    fill=$(printf '%*s' "$dots" '' | tr ' ' '.')
  else
    fill=" "
  fi
  printf "%s%s %b\n" "$prefix" "$fill" "$status"
}

info() { printf "%b  %s %s%b\n" "$INFO_TAG" "$bullet" "$*" "$RESET"; }

# ——————————————————————————————————————————————————————————————
# Step runner
# ——————————————————————————————————————————————————————————————
OK_COUNT=0; FAIL_COUNT=0; SKIP_COUNT=0

run_step() {
  # Usage: run_step "Description" "command to run"
  local desc=$1
  local cmd=$2
  local tmp; tmp=$(mktemp)

  if [ "$QUIET" = "1" ]; then
    # Quiet run, show output on failure
    set +e
    bash -o pipefail -c "$cmd" >"$tmp" 2>&1
    local rc=$?
    set -e
    if [ $rc -eq 0 ]; then
      print_line "$desc" "$OK_TAG"
      : $(( OK_COUNT++ ))
      rm -f "$tmp"
      return 0
    else
      print_line "$desc" "$FAIL_TAG"
      : $(( FAIL_COUNT++ ))
      echo
      sed -e 's/^/    │ /' "$tmp" || true
      echo
      rm -f "$tmp"
      return $rc
    fi
  else
    print_line "$desc" "$INFO_TAG"
    # Verbose: live output
    set +e
    bash -o pipefail -c "$cmd"
    local rc=$?
    set -e
    if [ $rc -eq 0 ]; then
      print_line "$desc" "$OK_TAG"
      : $(( OK_COUNT++ ))
      return 0
    else
      print_line "$desc" "$FAIL_TAG"
      : $(( FAIL_COUNT++ ))
      return $rc
    fi
  fi
}

skip_step() {
  # Usage: skip_step "Description" "reason"
  local desc=$1
  local reason=$2
  print_line "$desc" "$SKIP_TAG"
  : $(( SKIP_COUNT++ ))
  printf "%s%s\n\n" "$DIM" "    ↳ ${reason}${RESET}"
}

step_if() {
  # Usage: step_if "Description" "precondition command" "command to run" "skip reason"
  local desc=$1
  local cond=$2
  local cmd=$3
  local reason=${4:-"precondition not met"}

  if bash -c "$cond" >/dev/null 2>&1; then
    run_step "$desc" "$cmd"
  else
    skip_step "$desc" "$reason"
  fi
}

# ——————————————————————————————————————————————————————————————
# Sections / Steps
# ——————————————————————————————————————————————————————————————
print_header "System packages (paru -Syu)"
step_if \
  "Update system packages" \
  "command -v paru" \
  "paru -Syu --noconfirm" \
  "paru is not installed, skipping system update."

print_header "Composer globals"
step_if \
  "Update Composer global packages" \
  "command -v composer" \
  "composer global update" \
  "composer is not installed, skipping composer update."

print_header "Node LTS (fnm)"
step_if \
  "Install/use latest Node LTS via fnm" \
  "command -v fnm" \
  "fnm use lts-latest --install-if-missing --silent-if-unchanged && fnm default lts-latest" \
  "fnm is not installed, skipping Node LTS install."

print_header "Cargo binaries"
step_if \
  "Update Rust Cargo binaries" \
  "command -v cargo && command -v cargo-install-update" \
  "cargo install-update -a" \
  "cargo or cargo-install-update is not installed, skipping Cargo binaries update."

print_header "Rust toolchain"
step_if \
  "Update Rust toolchain (rustup)" \
  "command -v rustup" \
  "rustup update" \
  "rustup is not installed, skipping Rust toolchain update."

# ——————————————————————————————————————————————————————————————
# Summary & Exit
# ——————————————————————————————————————————————————————————————
printf "\n%sSummary%s  %sOK%s:%s%d%s  %sFAIL%s:%s%d%s  %sSKIP%s:%s%d%s\n" \
  "$BOLD" "$RESET" \
  "$GREEN" "$RESET" "$BOLD" "$OK_COUNT" "$RESET" \
  "$RED" "$RESET" "$BOLD" "$FAIL_COUNT" "$RESET" \
  "$YELLOW" "$RESET" "$BOLD" "$SKIP_COUNT" "$RESET"

if is_tty; then
  # Read a single key silently; if it's an escape, drain remaining bytes (e.g., arrow keys emit ESC [ A)
  k=""
  IFS= read -r -n1 -s -p $'\033[35m\033[1m[ DONE ] Press any key to close…\033[0m' k || true
  if [[ ${k:-} == $'\e' ]]; then
    # Drain the rest of a possible escape sequence without blocking
    read -r -s -t 0.05 -n 10 _rest || true
  fi
  echo
else
  info "Done."
fi
