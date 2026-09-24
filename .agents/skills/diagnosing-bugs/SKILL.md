---
name: diagnosing-bugs
description: Diagnosis loop for hard bugs and performance regressions in the Mantle Lua shell and the Hyprland Lua config.
---

# Diagnosing Bugs

A strict discipline for hard bugs. Stop guessing. Build a loop, form a hypothesis, measure, fix.

## 0. Redact & Read
*   **Context:** Identify the layer: Mantle shell Lua (`mantle/.config/mantle/`), Hyprland Lua (`hypr/.config/hypr/`), or the engine under them. For engine behavior, read `docs/introduction.md` (the docs site source) and `CONTEXT.md` in the engine checkout (`/mnt/Work/0Coding/1Rust/mantle`).
*   **Security:** Redact all secrets (`<REDACTED>`) before outputting artifacts. Quote only the specific log lines carrying the signal.

## 1. Build a Feedback Loop (The Hard Part)
If you do not have a tight pass/fail signal that goes red on *this specific bug*, you will fail. Do not read code to guess. Build the loop.

### Domain A: Mantle Shell (Lua)
1.  **Headless Evaluation:** `mantle check -c mantle/.config/mantle` evaluates the config with every capability reading `nil` and exits non-zero on a load error. Diff its output.
2.  **LSP/Linting:** Run lua-language-server `--check` against the root `.luarc.json` (command in `AGENTS.md`) to catch type and stub mismatches.
3.  **Live State:** `mantle log -f` for the running shell; `mantle set|toggle|call` to drive its named state and actions.
4.  **Capability Source:** `busctl --user`, `dbus-monitor`, `pw-dump` or `journalctl --user` to prove whether the data feeding a signal is wrong before blaming the Lua.

### Domain B: Hyprland (Lua)
1.  **Config Errors:** `hyprctl reload` then `hyprctl configerrors`.
2.  **Live Queries:** `hyprctl repl '<lua>'` evaluates Lua in the running compositor and prints the result; use it to test `hl.*` calls in isolation.
3.  **State Diffs:** `hyprctl monitors -j` or `hyprctl clients -j` before and after the trigger.

### Tighten It
*   Make it fast (seconds, not minutes).
*   Make it deterministic (seed `math.random`, pin inputs in a fixture config under `/tmp`, isolate one module).
*   *Completion Criterion:* You must name **one runnable command** that reliably reproduces the exact symptom.

## 2. Reproduce & Minimize
Watch the loop go red. Confirm it is the *user's exact symptom*.

**Minimize (The Deletion Test for Bugs):**
Cut inputs, callers, Lua modules, or nodes one by one. Re-run. Keep only what is load-bearing for the failure. Shrink the hypothesis space.

## 3. Hypothesize (3-5 Ranked)
Before touching the code, state 3-5 falsifiable hypotheses.
*   *Format:* "If [X] is the cause, then [changing Y] will make it pass / [changing Z] will alter the error message."
*   Show the list to the user.

## 4. Instrument & Measure
Map probes to the hypotheses. Change one variable at a time.
*   **Mantle Lua:** `print()` inside the module, read with `mantle log -f`.
*   **Hyprland Lua:** `hyprctl repl` for state, and `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log` for errors.
*   **Performance:** `exceeded the 5ms CPU budget` lines in `mantle log`, and the row count of every open `list` (each item is built, none are reused).
*   **Logging:** Tag all debug logs with `[DEBUG]`. Never "log everything."

## 5. Fix & Regression Test
1.  Turn the minimized repro into a permanent check (an assert-based Lua self-check that `mantle check` evaluates, or a `hyprctl repl` assertion).
2.  Watch it fail.
3.  Apply the fix.
4.  Watch it pass.

## 6. Cleanup
*   [ ] Original loop runs green.
*   [ ] Regression test runs green.
*   [ ] `grep -r "DEBUG"` is empty.
*   [ ] Temporary `print()` calls and fixture modules are deleted.
*   [ ] The correct hypothesis is documented in the commit message.
