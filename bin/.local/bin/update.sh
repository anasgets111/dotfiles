#!/usr/bin/env bash
set -euo pipefail

# ——————————————————————————————————————————————————————————————
# Terminal title
# ——————————————————————————————————————————————————————————————
printf '\033]2;Global Updates\007'

# ——————————————————————————————————————————————————————————————
# CLI flags
#   --quiet           Reduce noise: show only step results, and dump output on failure (default: verbose)
#   --stream          Stream verbose output live. If stderr is not a TTY, stream to stderr; otherwise keep
#                     the terminal clean (capture to logs only). Also enables split mode (compact stdout + logs).
#   --stream-to=PATH  Stream verbose output to PATH instead of stderr (implies --stream and split mode).
#   --polkit          Use pkexec + pacman for system packages (repo), and handle AUR separately via paru -Sua.
# ——————————————————————————————————————————————————————————————
QUIET=0
SPLIT=0
STREAM=0
POLKIT=0
STREAM_TO=""
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
  --stream) STREAM=1 ;;
  --polkit) POLKIT=1 ;;
  --stream-to=*) STREAM_TO="${arg#*=}"; STREAM=1 ;;
  esac
done

# If streaming is requested, ensure split mode is active so stdout stays compact
if [ "$STREAM" = "1" ]; then
  SPLIT=1
fi

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
# Logging helpers (per-step logs when SPLIT or QUIET)
# ——————————————————————————————————————————————————————————————
LOG_ROOT=""
STEP_INDEX=0

slugify() {
  # make a filesystem-friendly name from a description
  local s
  s=$(echo "$*" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_-')
  # ensure non-empty
  if [ -z "$s" ]; then s="step"; fi
  echo "$s"
}

ensure_log_root() {
  if [ -n "$LOG_ROOT" ]; then return 0; fi
  LOG_ROOT=$(mktemp -d -t update-logs.XXXXXX)
}

# ——————————————————————————————————————————————————————————————
# Step runner
# ——————————————————————————————————————————————————————————————
OK_COUNT=0; FAIL_COUNT=0; SKIP_COUNT=0

run_step() {
  # Usage: run_step "Description" "command to run"
  local desc=$1
  local cmd=$2
  : $(( STEP_INDEX++ ))
  local step_slug; step_slug=$(slugify "$desc")
  local step_log
  if [ "$SPLIT" = "1" ] || [ "$QUIET" = "1" ]; then
    ensure_log_root
    step_log="$LOG_ROOT/$(printf "%02d" "$STEP_INDEX")_${step_slug}.log"
  else
    step_log=""
  fi

  if [ "$QUIET" = "1" ]; then
    # Quiet run, show output on failure
    set +e
    if [ -n "$step_log" ]; then
      bash -o pipefail -c "$cmd" >"$step_log" 2>&1
    else
      # fallback (shouldn't happen in quiet)
      bash -o pipefail -c "$cmd" > /dev/null 2>&1
    fi
    local rc=$?
    set -e
    if [ $rc -eq 0 ]; then
      print_line "$desc" "$OK_TAG"
      : $(( OK_COUNT++ ))
      return 0
    else
      print_line "$desc" "$FAIL_TAG"
      : $(( FAIL_COUNT++ ))
      if [ -n "$step_log" ] && [ -f "$step_log" ]; then
        echo
        sed -e 's/^/    │ /' "$step_log" || true
        echo
      fi
      return $rc
    fi
  else
    print_line "$desc" "$INFO_TAG"
    # Verbose: live output
    set +e
    if [ "$SPLIT" = "1" ]; then
      if [ "$STREAM" = "1" ]; then
        # Stream command output to stderr and also tee into per-step log
        # Keep stdout clean for status lines
        if [ -n "$STREAM_TO" ]; then
          # Stream to file instead of terminal
          # Capture both stdout and stderr into step_log and STREAM_TO; suppress terminal output
          touch "$STREAM_TO" 2>/dev/null || true
          if [ -n "$step_log" ]; then
            bash -o pipefail -c "$cmd" \
              > >(tee -a "$step_log" -a "$STREAM_TO" > /dev/null) \
              2> >(tee -a "$step_log" -a "$STREAM_TO" > /dev/null)
          else
            bash -o pipefail -c "$cmd" \
              > >(tee -a "$STREAM_TO" > /dev/null) \
              2> >(tee -a "$STREAM_TO" > /dev/null)
          fi
        else
          # If stderr is not a TTY (e.g., UI captures it), stream to stderr; otherwise avoid spamming terminal
          if [ -t 2 ]; then
            # Stderr is a TTY; don't stream to terminal, just capture
            if [ -n "$step_log" ]; then
              bash -o pipefail -c "$cmd" >"$step_log" 2>&1
            else
              bash -o pipefail -c "$cmd" >/dev/null 2>&1
            fi
          else
            if [ -n "$step_log" ]; then
              bash -o pipefail -c "$cmd" \
                > >(tee -a "$step_log" >&2) \
                2> >(tee -a "$step_log" >&2)
            else
              bash -o pipefail -c "$cmd" >/dev/stderr 2>&1
            fi
          fi
        fi
      else
        # Do not stream; only capture to per-step log
        if [ -n "$step_log" ]; then
          bash -o pipefail -c "$cmd" >"$step_log" 2>&1
        else
          bash -o pipefail -c "$cmd" >/dev/null 2>&1
        fi
      fi
    else
      # legacy behavior: stream to stdout/stderr directly
      bash -o pipefail -c "$cmd"
    fi
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

# Variant that forces streaming regardless of --split-output, useful for interactive prompts
run_step_stream() {
  local desc=$1
  local cmd=$2
  local old_split=$SPLIT
  local old_stream=$STREAM
  SPLIT=1
  STREAM=1
  run_step "$desc" "$cmd"
  STREAM=$old_stream
  SPLIT=$old_split
}

step_if_stream() {
  local desc=$1
  local cond=$2
  local cmd=$3
  local reason=${4:-"precondition not met"}
  if bash -c "$cond" >/dev/null 2>&1; then
    run_step_stream "$desc" "$cmd"
  else
    skip_step "$desc" "$reason"
  fi
}

# ——————————————————————————————————————————————————————————————
# Sections / Steps
# ——————————————————————————————————————————————————————————————
if [ "$SPLIT" = "1" ] && [ "$POLKIT" = "0" ]; then
  print_header "Prerequisites"
  step_if_stream \
    "Authenticate sudo (cache credentials)" \
    "command -v sudo" \
    "sudo -v" \
    "sudo not available."
fi

if [ "$POLKIT" = "1" ]; then
  print_header "System packages (pacman via polkit)"
  step_if \
    "Update system packages (pkexec pacman)" \
    "command -v pkexec && command -v pacman" \
    "pkexec pacman -Syu --noconfirm" \
    "pkexec or pacman is not available, skipping system update."
else
  print_header "System packages (paru -Syu)"
  step_if \
    "Update system packages" \
    "command -v paru" \
    "paru -Syu --noconfirm" \
    "paru is not installed, skipping system update."
fi

if [ "$POLKIT" = "1" ]; then
  print_header "AUR packages (paru -Sua)"
  step_if \
    "Update AUR packages" \
    "command -v paru" \
    "paru -Sua --noconfirm" \
    "paru is not installed, skipping AUR updates."
fi

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

if { [ "$SPLIT" = "1" ] || [ "$QUIET" = "1" ]; } && [ -n "$LOG_ROOT" ] && [ -d "$LOG_ROOT" ]; then
  info "Per-step logs: $LOG_ROOT"
fi

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
