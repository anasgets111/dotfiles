# AGENTS.md

## Project

- Arch Linux dotfiles for Hyprland (Lua config) and Niri, deployed with GNU Stow. Arch is authoritative for packages, runtime and installation.
- The shell is `mantle/.config/mantle/`, a Lua 5.4 config for the upstream [Mantle engine](https://github.com/anasgets111/mantle). The engine ships the `mantle` binary, Lua API and capabilities; this repo holds only the Lua.
- `NixConfig/` is inactive. Ignore it unless asked; never use it as context or sync it with Arch.

## Commands

- **Never run `stow` or start the shell** (`mantle`, `mantle -d`) unless told to.
- Saving a `.lua` reloads the running shell in place. A failed reload keeps the last scene and shows the error in the bar.

| Command | Use |
| --- | --- |
| `just` | Gate before done: `lua` (parse + format), `types` (LuaLS on the root `.luarc.json`), `mantle`. `just fmt` formats |
| `mantle check -c mantle/.config/mantle` | Run after every edit (`just mantle`). Evaluates and lays out the config with no Wayland, no subprocesses and every capability `nil`; writes no state |
| `mantle log [-f]` | Running shell output, `print()` included |
| `mantle set`, `toggle`, `call <name>` | Drive live `state` and `action` names like a keybind; changes the live UI |
| `luac5.4 -p file.lua` | Syntax check. Plain `luac` is Lua 5.5 |
| `hyprctl repl '<lua>'` | Evaluate `hl.*` in the running Hyprland without a reload |
| `shellcheck script.sh` | Lint Bash |

## Engine reference

Upstream checkout at `/mnt/Work/0Coding/1Rust/mantle`. Read it; never edit it from here unless asked to.

| Question | Read |
| --- | --- |
| What a config can declare and call | `docs/introduction.md`, then `docs/guide/`, `docs/nodes/`, `docs/surfaces/` |
| Capability fields and actions | `lua-meta/mantle.lua` (generated), `docs/capabilities/<name>.md` |
| Node and surface properties | `lua-meta/nodes.lua`, `lua-meta/surfaces.lua` |
| Lua change or engine gap | `docs/roadmap.md`. Flag a real engine gap instead of working around it |
| Terms (generation, named state, capability) | `docs/glossary.md`; engine-internal ones in `CONTEXT.md` |

## Shell structure

```
mantle/.config/mantle/
  shell.lua     Entry: font chain, requires modules, returns the surface list
  config/       Tokens: theme.lua (Catppuccin Mocha), icons.lua, dev_tools.lua
  components/   Reusable widgets with no state of their own
  lib/          Node-free logic and state: store, ui_state, idle, wallpaper, weather, updates, compositor
  modules/      bar/{indicators,panels}, global/, notification/, osd/, shell/panel_host.lua
  shaders/      Wallpaper transition .frag sources, compiled by the engine at runtime
```

## Patterns

| Topic | Rule |
| --- | --- |
| Signals | Pass the signal itself to keep a property live; `:get()` is a snapshot. Derive with `:map`, `computed`, `delay`, `pulse` |
| Hydration | Capabilities read `nil` until the first push. Every map handles `nil` |
| Actions | `mantle.audio:invoke("set_volume", 0.5)` returns nothing. Observe state for the outcome |
| Keybinds | Named state lives in `lib/ui_state.lua`; `action(name, fn)` backs `mantle call`. A rename also updates `hypr/.config/hypr/config/keybinds.lua` and `niri/.config/niri/config.kdl` |
| Persistence | One `persistent_table` in `lib/store.lua` (`~/.local/state/mantle/state.json`). Add keys to its `defaults` |
| Processes | `process.run` dies with the generation, `process.detach` outlives the shell, `session_process` survives reloads |
| Compositor | Per-compositor commands go in `lib/compositor.lua`; behavior reads `mantle.workspaces:get().compositor` |
| Theme | `config/theme.lua` tokens and `config/icons.lua` glyphs. Never hardcode colours, sizes or spacing |
| Panels | Four bands, top down. `panel_header` first, its subtitle one live state line, trailing only a badge (count), `panel_action_icon` (verb) or `toggle` (the subject's power). Then one row of controls: `panel_toggle_card` switches or `accent` `action_button`s; a radio anywhere is one `segmented` bar, never a row of tiles; every primary in a panel is that tinted glass, `solid` belongs to a modal's confirm, `danger` to the one action that ends something running. Then a flat body: `section_header` + `panel_row`s; "more" is always `panel_row { expanded }` in place, never a view swap; a `panel_card` only wraps a composite control (row + slider, status + meter, a table). Last, text buttons that conclude what the body showed. A modal is the same panel with a `theme.font.xl` masthead (`on_close` included), `lg` padding, `md` spacing and its one scroll area on an `outlined` card; a search modal's search bar is its masthead |
| Shaders | A new `.frag` in `shaders/` works as is. Add a `lib/wallpaper.lua` row only for non-zero uniforms |

## Ponytail: lazy senior dev mode

Lazy means efficient, not careless. The best code is the code never written.

- **Output.** Everything an agent writes (code, chat, comments, docs, commit messages) is to the point. No walls of text: tables first, bullets second, short prose last.
- **Diffs.** Add the fewest lines possible and remove as many as possible. Delete dead, redundant and duplicated code around the change. The smallest diff in the wrong place is a second bug.
- **Root cause.** Fix the cause, not the symptom. Grep every caller and fix the shared function once.
- **Boring.** No new abstractions, dependencies, boilerplate or files unless required. Between similar-sized approaches, take the edge-case-correct one.
- **Ceilings.** Mark a deliberate simplification (global lock, O(n²) scan, naive heuristic) with a `ponytail:` comment naming its ceiling and upgrade path.
- **Checks.** Non-trivial logic gets one runnable check; trivial one-liners get none.
- **Full effort.** Understanding the problem, trust-boundary validation, data loss, security, accessibility, real-hardware calibration and explicit requests are never lazy.

Before writing code, trace the real flow end to end, then stop at the first rung that holds:

1. Does it need to exist? (YAGNI)
2. Does the codebase already have it? Reuse it.
3. Does the Lua API, a capability, the platform or an installed tool cover it? Use it.
4. Can it be one line?
5. Only then, the minimum code that works.

## Notable files

| Path | Holds |
| --- | --- |
| `bin/.local/bin/arch-install.sh` | Full Arch install for the Wolverine and Mentalist hosts |
| `home/.profile` | XDG dirs, NVIDIA env, Wayland toolkit config, PATH |
| `home/.stowrc` | Points stow at this repo and `~` |
| `.luarc.json` | One LuaLS config for the mantle, Hyprland, Neovim and mpv Lua |
| `fish/.config/fish/conf.d/various.fish` | Custom fish functions |
| `.local_secrets/` | Gitignored secrets; `.gitconfig` symlinks here |

The default terminal resolves through `xdg-terminal-exec`.

## Lessons learned

- Record only non-obvious failures likely to recur: what fails, why, what to do instead. Name a version only when the behavior is version-bound.
- After edits, delete the stale comments, docs and entries here that the work exposed. Delete obsolete guidance rather than adding exceptions.

### Mantle Lua

| Trap | Fix |
| --- | --- |
| The VM has no `io`, `debug` or FFI; `os` has only `time`, `date`, `clock`, `getenv` | Shell out with `process.run` |
| `require` returns a second value, so inside the returned surface table it adds an entry (`error converting Lua string to table`) | Bind modules to locals first |
| `:map` and `computed` have a 5 ms CPU budget (`exceeded the 5ms CPU budget`) | Keep maps cheap |
| Signals nested in a property table do not resolve | Derive the whole table |
| `visible = false` keeps a frozen subtree | Switch views through `children` |
| Named state resets when its scalar seed changes | Keep the seed stable |
| `timer`, `action` and `on_change` last one evaluation | Expect them to re-register on every reload |
| `fonts` is read once at startup | Restart the shell after editing it |
| UPower's `PendingCharge` also follows `Discharging` | Only `Charging` to `PendingCharge` means charging stopped (`modules/global/power_events.lua`) |

### Tooling

| Trap | Fix |
| --- | --- |
| Zed reads only the root `.luarc.json`; nested ones are ignored | Keep all Lua settings in the root file |
| LuaLS builtin `os` types reject valid mantle `os.time` calls | Keep builtin `os` and `debug` disabled in `.luarc.json` |
| A running LuaLS ignores `runtime.*` changes | Restart the language server |
| Hyprland 0.56 parses its socket as Lua, so `hyprctl dispatch exit` fails | `hyprctl dispatch 'hl.dsp.exit()'` |
| Hyprland 0.56.1 fades mapped `Top` surfaces when fullscreen starts, but not ones mapped after | Handle both on Hyprland; Niri does neither |
| Hyprland sends the pointer only to a layer with `Exclusive` keyboard interactivity, so other surfaces stop taking clicks | `OnDemand`; it still takes focus when it maps |
| `niri msg action spawn` passes an activation token that overrides `open-focused false` | Spawn through `env -u XDG_ACTIVATION_TOKEN`, then focus explicitly |
| `niri --config x validate` is rejected | `niri validate --config x` |
| `systemd-run --scope` rejects `--pipe`, and fixed-name scopes linger after exit | Transient service with `--pipe --collect` |
