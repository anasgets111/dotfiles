#!/usr/bin/env bash
# Ponytail HITL (Human-In-The-Loop) Loop.
# Use ONLY when a bug requires manual interaction (Mantle shell rendering, Hyprland behavior)
# and cannot be caught via headless loops.
#
# Usage: bash scripts/hitl.sh

set -euo pipefail

step() {
  printf '\n>>> %s\n' "$1"
  read -r -p "    [Enter when done] " _
}

capture() {
  local var="$1" question="$2" answer
  printf '\n>>> %s\n' "$question"
  read -r -p "    > " answer
  printf -v "$var" '%s' "$answer"
}

printf "Ponytail HITL Diagnostics\n=========================\n"

# ==============================================================================
# TEMPLATE A: MANTLE SHELL / LUA (Hyprland or Niri)
# ==============================================================================
# step "Follow the running shell's output in a terminal: mantle log -f"
# step "Save the module under test to reload the shell in place."
#
# capture RENDERED "Did the reload apply without a rescue error in the bar? (y/n)"
# capture STATE_SYNC "Change the workspace. Did the widget update? (y/n)"
# capture ERROR_MSG "Paste the exact error from mantle log (or 'none'):"


# ==============================================================================
# TEMPLATE B: HYPRLAND / LUA
# ==============================================================================
# step "Save the Hyprland config file under test."
#
# capture CONFIG_ERRORS "Paste the output of hyprctl configerrors (or 'none'):"
# capture BEHAVIOR "Trigger the bind or rule. Did it behave as expected? (y/n)"

# --- UNCOMMENT AND EDIT ONE OF THE TEMPLATES ABOVE ---

printf '\n--- [ PONYTAIL HITL RESULTS ] ---\n'
# printf 'RENDERED=%s\n' "$RENDERED"
# printf 'STATE_SYNC=%s\n' "$STATE_SYNC"
# printf 'ERROR_MSG=%s\n' "$ERROR_MSG"
# printf 'CONFIG_ERRORS=%s\n' "$CONFIG_ERRORS"
# printf 'BEHAVIOR=%s\n' "$BEHAVIOR"
