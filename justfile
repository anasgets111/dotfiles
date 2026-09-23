# Lua gates for the dotfiles, after the engine's own justfile. `just` alone runs `check`.

default: check

# Every Lua this repo owns; `NixConfig/` is inactive.
lua_dirs := "mantle hypr nvim mpv wezterm"

# The engine checkout, for its LSP-driven formatter (`tools/luafmt.py` says why it isn't stylua).
engine := "/mnt/Work/0Coding/1Rust/mantle"

check: lua types mantle

# `luac5.4`, not `luac`: that one is Lua 5.5.
[doc('Every Lua file parses and is formatted.')]
lua:
    #!/usr/bin/env bash
    set -euo pipefail
    find {{lua_dirs}} -name '*.lua' -print0 | xargs -0 -n1 luac5.4 -p
    echo "all lua parses"
    python3 {{engine}}/tools/luafmt.py --check {{lua_dirs}}

fmt:
    python3 {{engine}}/tools/luafmt.py {{lua_dirs}}

# The root `.luarc.json`, the one Zed reads. A missing server fails rather than skips.
[doc('Everything type-checked against the mantle, Hyprland and Neovim stubs.')]
types:
    #!/usr/bin/env bash
    set -euo pipefail
    luals=$(command -v lua-language-server 2>/dev/null ||
        ls -d ~/.local/share/zed/extensions/work/lua/lua-language-server-*/bin/lua-language-server 2>/dev/null | sort -V | tail -1 || true)
    if [ -z "$luals" ]; then
        echo "no lua-language-server on PATH or in Zed's extensions. Install it: pacman -S lua-language-server" >&2
        exit 1
    fi
    log=$(mktemp -d)
    trap 'rm -rf "$log"' EXIT
    # The progress bar redraws with carriage returns; replay only the diagnostics on failure.
    if ! out=$("$luals" --check "$PWD" --checklevel=Warning --logpath="$log" 2>&1); then
        printf '%s' "$out" | tr '\r' '\n' |
            sed -E '/^[[:space:]]*$/d; /^[[:space:]]*Initializing/d; /^[[:space:]]*[>=]+[[:space:]]*[0-9]+\/[0-9]+/d; /^[[:space:]]*Diagnosis complet/d' >&2
        exit 1
    fi
    echo "lua type-checks"

# No Wayland, no subprocesses, every capability `nil`; writes no state.
[doc('The shell config evaluates.')]
mantle:
    mantle check -c mantle/.config/mantle
