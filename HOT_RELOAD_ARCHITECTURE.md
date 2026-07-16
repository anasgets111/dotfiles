# Bounded-Memory Hot Reload

## Goal

Build a general Wayland shell framework with Quickshell-like authoring freedom, predictable Rust performance, and memory independent of reload count. Obelisk is the first regression workload, not the framework's product schema. The old UI generation must exit as a process so the kernel reclaims its allocator and process-owned mappings.

## Current Quickshell

- `shell.qml` loads UI and singleton services into one process and one `QQmlEngine` generation.
- Reload creates the next engine before deleting the previous engine in the same process.
- `PersistentProperties`, reloadable singletons, and `Retainable` objects carry selected state between generations.
- Destruction is explicit, but QML/allocator fragmentation can remain resident. Cleanup inside individual services cannot provide a process-wide memory bound.
- Notifications already reject reload retention (`keepOnReload: false`); recording survives through a detached process plus validated persisted identity.
- A scan or component-load error leaves the old generation active; [component-load failures](https://git.outfoxxed.me/quickshell/quickshell/src/commit/201c559dcdc1244515332a88b5145ead531787ed/src/core/rootwrapper.cpp) add newly discovered files to the active watch set.
- Reload errors use a [built-in popup](https://git.outfoxxed.me/quickshell/quickshell/src/commit/7b417bb80811d3d036df97d7149352b01ca6fb72/src/ui/reload_popup.cpp) independent of user QML; runtime QML warnings are logged with source locations.
- [Crash recovery](https://git.outfoxxed.me/quickshell/quickshell/src/commit/6eb12551baf924f8fdecdd04113863a754259c34/src/launch/main.cpp) relaunches after a 10 s loop guard, but reload success has no post-creation health window or last-known-good source fallback.

## Target

```text
file watcher -> supervisor -> disposable desktop renderer
                         \-> state/authority broker
lock request ----------------> durable lock/auth process
```

### Supervisor

- Own file watching, 250 ms debounce, validation, generation IDs, and child lifecycle.
- Allow one active reload and one pending reload; newer changes replace the pending request.
- Start a renderer staged; `ready` means every output in that transaction is configured and renderable.
- Retain every child handle, reap on exit, and contain each renderer in its own process group.
- Commit only after `ready`; discard and reap a failed candidate after a 5 s timeout.

### Renderer

- Own only the UI scene, animations, surfaces, and generation-local caches.
- Stage surfaces unmapped with exclusive zone `0`, keyboard disabled, and an empty input region.
- Never own durable state, public endpoints, authentication, or detached jobs.
- Exit completely after handoff; do not reuse its UI engine or allocator.

### Lua configuration

`shell.lua` is the user-facing configuration entry point. It returns a declarative scene built with the framework API; users edit Lua and hot reload without rebuilding Rust.

#### Runtime boundary

- Embed mature PUC Lua 5.4 with [`mlua`](https://docs.rs/mlua/latest/mlua/) using `lua54,vendored`; [Lua 5.5 is still at 5.5.0](https://www.lua.org/versions.html), so reconsider it after its first bug-fix release or a measured GC need.
- Create one Lua VM per disposable renderer generation. Supervisor, broker, and lock/auth processes never execute user Lua.
- Accept text chunks only and name each chunk with its canonical path for tracebacks. Do not cache Lua bytecode across framework versions.
- Load only base, table, string, math, and UTF-8 facilities. Remove `io`, `os`, `package`, `debug`, `load`, `loadfile`, `dofile`, and `collectgarbage`; replace `print` with a rate-limited logger and expose OS access only through explicit asynchronous capabilities.
- Use a custom `require` rooted at the canonical config directory and explicit trusted include roots. Reject traversal/symlink escape, record every dependency path, and hash loaded content.
- Default limits: 4 MiB total source, 64 MiB Lua heap, 20,000 scene nodes, 4,096 bindings, and 1,024 timers. Rust-side scene/cache limits remain separate.
- Check a monotonic deadline from an instruction hook: 10 million instructions/250 ms for build and 1 million/16 ms per callback. Native capabilities must never block the renderer thread.
- Execute Lua only on the renderer event-loop thread; background work returns immutable messages. Rust callbacks validate inputs and return Lua errors rather than panicking across the boundary.

These limits protect availability, not hostile-code isolation; the renderer still runs as the user. Raising them requires a trusted CLI/configuration option outside Lua.

A fresh VM also clears registered handlers naturally, a pattern already proven by [WezTerm's Lua reload model](https://wezterm.org/config/lua/wezterm/on.html).

#### UI model

- Lua constructors produce a typed retained scene; Rust validates properties, ownership, output targets, and limits before creating surfaces.
- The root scene declares an API version; reject unsupported versions before creating surfaces.
- Scene construction is side-effect-free: stage timers, subscriptions, and watches disabled, and reject action capabilities until the generation lease is active.
- Use explicit signals and property mappings instead of implicit global dependency tracking. Persist only byte-bounded JSON-compatible values through the broker.
- Timers are native Calloop sources holding protected Lua callbacks. Stop a timer/binding after its callback errors; reload restores it.
- Animations and easing execute in Rust/WGPU after Lua describes keyframes. Never call Lua once per animation frame.
- A custom canvas records a bounded command list only when invalidated. Trusted local shader packages may supply runtime-compiled WGSL with bounded sources, resources, and pipelines; never expose raw Wayland/WGPU handles.
- Generate LuaLS `*.d.lua` definitions from the same API metadata used for runtime validation.
- Authentication theming is compiled by a disposable, unprivileged Lua process into a validated data-only scene. It may describe native animations and clock-driven bindings, but authentication owners never receive Lua callbacks.

#### Authoring freedom contract

Lua defines the shell rather than filling slots in a Rust-defined shell. Users must be able to create different surface topologies, components, controllers, and local services without rebuilding Rust. The framework must provide:

- reusable modules and component functions with user-defined typed properties, slots, events, local and computed signals/state, lifecycle hooks, conditional/lazy children, and keyed repeaters;
- anchors plus row, column, grid, flow, stack, scroll, and virtualized list layouts with implicit/minimum/preferred/maximum sizing;
- text, icon fonts, images/SVG, gradients, clipping, transforms, masks, shadows, blur, canvas commands, and per-output scaling;
- pointer buttons, wheel, hover, tap, drag, keyboard focus/shortcuts, text editing, selection, clipboard, IME, and accessibility roles;
- property behaviors, parallel/sequential/delayed/repeating animations, retargeting, easing, enter/exit transitions, and completion callbacks, all scheduled natively;
- background/panel/overlay/popup surfaces with anchors, margins, exclusive zones, input regions, focus policy, per-output instances, and hotplug;
- keyed reactive models with map/filter/sort derivation, plus capability APIs for notifications/replies, tray menus, audio/media, network, Bluetooth, power, brightness, workspaces/windows, wallpaper, weather, updates, recording, files, processes, sockets, HTTP, and D-Bus;
- Lua-defined generation-local controllers and services that can own state, timers, subscriptions, and asynchronous workflows without becoming durable authorities.

All required Lua modules, assets, and shader packages participate in dependency watching and transactional reload. Native Lua modules, FFI, and in-process plugins remain forbidden because they defeat the memory and crash boundary.

Capabilities missing from the built-in API may be supplied by supervised external processes over versioned, bounded IPC. Extensions publish typed state streams and actions; they never load into the supervisor, broker, renderer, or authentication address spaces. They are generation-scoped and reaped by default; durable extensions require an explicit manifest plus memory, CPU, queue, and restart limits. Direct Wayland protocol and rendering integration remains core Rust work, as equivalent functionality also requires native Quickshell support.

Obelisk parity is the baseline test: bar/panels, launcher keyboard navigation, virtualized network list and text input, notification inline reply, tray menus, animated wallpaper shaders, multi-output hotplug, lock screen, greeter, and Polkit must pass behavior tests. Generality additionally requires a second shell with different surfaces and interaction structure, built only from Lua and external capability processes.

#### Demand-driven capabilities

- Loading any Lua module only returns definitions and inert handles. It may not allocate an optional backend resource, connect to a service, bind a protocol object, start a thread/process/timer, register a public endpoint, or begin polling.
- Lua evaluation may declare capability dependencies but cannot start them. On activation, the runtime starts only dependencies reached by live scene nodes; lazy or conditional UI therefore keeps unused services stopped.
- Capability lifetimes are reference-counted across handoff. Keep an old generation's dependencies through the health window for rollback, then stop anything the committed generation does not use.
- Every optional resource is acquired by a live subscription, scene node/timer, in-flight action, explicit job, or durable authority lease and released when its final owner disappears. A short bounded grace period may prevent rapid stop/start flapping.
- This applies transitively to every current and future capability, not only named services: unused dependencies must remain stopped even when their Rust code is compiled into the binary.
- `process.run` starts an asynchronous generation-scoped child group from an argument vector, environment, and working directory. Its handle exposes bounded stdout/stderr streams, optional stdin, exit, timeout, and cancellation; reload always terminates and reaps the group.
- `process.spawn_detached` is a separate supervisor request with no inherited pipes. It survives the calling Lua generation, is still reaped by the supervisor, and returns a runtime job ID; persistence or restart is opt-in for declared durable jobs. Never implicitly convert `process.run` into a detached job.
- Capability startup failure produces an error state on its signal/action; it does not crash unrelated UI or trigger polling retries without a subscriber.

### State and authority broker

Add broker ownership only where overlapping renderers would conflict or state loss matters:

- Start the broker process only while the committed capability graph contains durable authority or retained state; an entirely stateless shell has no broker.
- notification D-Bus server and bounded history;
- public IPC endpoint;
- detached-job identities such as screen recording;
- minimal versioned UI state needed across reloads.

Each renderer receives an authenticated, generation-scoped private channel. The broker rejects state-changing requests as soon as that generation's lease is revoked.

Audio, network, weather, and compositor views may reconnect in each renderer unless measurement proves a broker is needed. Transfer IDs and small values, never UI objects, images, timers, or callbacks.

### Lock and authentication

- A dedicated, non-hot-reloaded process owns `ext-session-lock-v1` and the PAM conversation.
- Separate durable frontends own greetd and Polkit conversations. Invalid themes fall back to built-in Rust login/authentication scenes.
- Native password fields send secrets directly to the relevant authentication owner; Lua may position and style the field but never reads its contents.
- Passwords never enter snapshots, broker messages, logs, or history; use zeroizing buffers and drop them after each attempt.
- Never terminate the lock owner after the compositor confirms `locked`. On unlock, call `unlock_and_destroy`, round-trip `wl_display.sync`, then exit.
- A lock-owner crash must remain securely locked; test compositor recovery separately.

## Reload transaction

1. Detect and coalesce changes.
2. Snapshot the output set. Active renderer and lock process still handle hotplug; any change aborts/restarts the candidate.
3. Start and validate generation `N+1` without replacing `N`.
4. Connect `N+1` to the broker and restore a byte-bounded, versioned snapshot.
5. On `ready`, freeze `N`'s surface commits. Keep its last buffers, but commit no input/keyboard and a nonreserving zone chosen per surface (`-1` usually preserves an anchored panel's position); wait for `wl_display.sync`.
6. Suspend `N`'s broker lease, then attach `N+1`'s buffers with their real input/exclusive state. Queue state-changing requests during this authority gap.
7. Confirm `N+1` with `wp_presentation` feedback when available; otherwise use a processed commit plus first frame callback and record that the fallback is not physical-presentation proof.
8. Activate `N+1`'s lease and keep frozen `N` for a 2 s health window.
9. If healthy, unmap, terminate, and reap `N`. Before then, failure unmaps `N+1`, waits for sync, and restores `N`'s surface state and lease.

Wayland provides no atomic cross-process surface handoff and same-layer stacking is compositor-defined, so brief overlap or a gap is acceptable. Defer desktop commits while locked, then apply only the newest pending generation after unlock.

## Configuration errors

Apply the useful Quickshell rule: never replace a working generation with a broken candidate. Improve it with process isolation, a health window, and last-known-good recovery.

| Failure                                                       | Action                                                                                                                                             |
| ------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Save is empty, unchanged, or changes while loading            | Debounce/hash and retry silently from a consistent snapshot.                                                                                       |
| Syntax, `require`, API, validation, limit, or readiness error | Reject/reap the candidate; keep the active renderer and all public authority.                                                                      |
| No valid generation yet                                       | Keep watching and launch a built-in Rust diagnostic renderer, not user Lua.                                                                        |
| Timer, binding, canvas, or event callback error               | Keep the renderer; disable that callback source until reload and retain its last valid value/scene.                                                |
| Lua VM OOM after activation                                   | Treat the renderer as failed; use the active-renderer recovery policy rather than continuing with an exhausted VM.                                 |
| Candidate crash or fatal error during handoff/health window   | Roll back to the frozen generation and restore its broker lease.                                                                                   |
| Active renderer crashes later                                 | Retry its successful bundle once, then try the previous successful bundle; after 3 crashes in 30 s, use the built-in safe shell and stop the loop. |
| Lock-theme error                                              | Keep the last validated data-only lock scene; authentication remains available.                                                                    |

- The custom loader reads and hashes each module before executing that chunk, records the complete dependency graph, then verifies every hash after root evaluation. Watch parent directories for missing modules. Keep the last two successful source bundles; never store functions, userdata, secrets, or bytecode.
- Every Lua entry point is a [protected call](https://www.lua.org/manual/5.4/manual.html#2.3) from Rust. Report structured phase, generation hash, canonical file, line/column when available, traceback, cause chain, and repeat count.
- Diagnostics are rendered by a built-in mode of the binary, independent of Lua. Replace the previous reload diagnostic and rate-limit repeats instead of stacking popups.
- Warnings and deprecations may commit but remain visible; errors never commit. A strict `--deny-warnings` mode belongs to tooling, not user Lua.
- Test syntax errors, missing modules, edits during load, infinite loops, Lua OOM, callback failure, candidate/active crashes, and invalid lock themes. Each fix must trigger a new candidate automatically.

## Invariants

- At most one renderer accepts input or reserves exclusive space; brief visual overlap or a gap is allowed.
- Exactly one process owns each D-Bus name, IPC socket, and detached job.
- IPC frames and snapshots are at most 1 MiB; each client queue is at most 256 messages and 4 MiB.
- Notification history is at most 100 entries and 1 MiB of text; each renderer's decoded-image cache is at most 256 MiB.
- No old-generation PID survives a successful handoff.
- Apart from the supervisor/file watcher and the active renderer's event loop and Wayland connection, every running facility has a traceable live subscription, scene node/timer, in-flight action, explicit job, or durable authority lease.
- After 5 warmups, run three 100-reload batches. After each 30 s settle, verify old PIDs exited and sample `Pss_Anon`/`Private_Dirty` five times at 1 s intervals. Broker medians stay within 16 MiB of warm baseline with no batch rise over 2 MiB; renderer medians stay within 32 MiB of clean baseline.

## Rust implementation candidates

Reviewed 2026-07-16. Pin versions only after the first vertical slice.

| Need                                                      | Crate                                                                                                                                                                         | Use                                                                                                                                                                                      |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Wayland client, outputs, input, layer shell, session lock | [`smithay-client-toolkit`](https://docs.rs/smithay-client-toolkit/latest/smithay_client_toolkit/) + [`wayland-client`](https://docs.rs/wayland-client/latest/wayland_client/) | Renderer and lock-process foundation; SCTK exposes both protocol modules.                                                                                                                |
| Renderer event loop                                       | [`calloop`](https://docs.rs/calloop/latest/calloop/)                                                                                                                          | Enable SCTK's optional `calloop` integration; do not add Tokio to the renderer initially.                                                                                                |
| GPU rendering                                             | [`wgpu`](https://docs.rs/wgpu/latest/wgpu/)                                                                                                                                   | One device per renderer generation; process exit is the cache boundary.                                                                                                                  |
| Text and icons                                            | [`cosmic-text`](https://docs.rs/cosmic-text/latest/cosmic_text/), [`resvg`](https://docs.rs/resvg/latest/resvg/), [`image`](https://docs.rs/image/latest/image/)              | Shape text and render assets after checking encoded bytes, dimensions, and decoded size.                                                                                                 |
| Watching and child lifecycle                              | [`notify-debouncer-full`](https://docs.rs/notify-debouncer-full/latest/notify_debouncer_full/), [`tokio`](https://docs.rs/tokio/latest/tokio/process/struct.Child.html)       | Supervisor only; debounce saves and continuously wait/reap children. Add [`rustix`](https://docs.rs/rustix/latest/rustix/process/) pidfds only if PID-safe external signaling is needed. |
| D-Bus authority and service adapters                      | [`zbus`](https://docs.rs/zbus/latest/zbus/)                                                                                                                                   | Broker notification server; define typed service proxies with zbus's `proxy` macro.                                                                                                      |
| Broker protocol and bounded caches                        | [`serde`](https://docs.rs/serde/latest/serde/), [`serde_json`](https://docs.rs/serde_json/latest/serde_json/), [`lru`](https://docs.rs/lru/latest/lru/)                       | Use size-prefixed, capped JSON; bounded channels/queues; LRU only for real caches.                                                                                                       |
| Authentication                                            | [`pam-client`](https://docs.rs/pam-client/latest/pam_client/), [`zeroize`](https://docs.rs/zeroize/latest/zeroize/)                                                           | Use a custom PAM conversation with zeroizing secret buffers inside the durable lock process.                                                                                             |
| Audio graph                                               | [`pipewire`](https://docs.rs/pipewire/latest/pipewire/)                                                                                                                       | Start renderer-local. If later brokered, one dedicated thread owns all PipeWire objects and uses bounded channels.                                                                       |
| Fast UI prototype                                         | [`iced_layershell`](https://docs.rs/iced_layershell/latest/iced_layershell/)                                                                                                  | Evaluate only for staged desktop surfaces and multi-output; keep lock/auth on direct SCTK.                                                                                               |
| Lua configuration                                         | [`mlua`](https://docs.rs/mlua/latest/mlua/)                                                                                                                                   | Embed vendored Lua 5.4; one limited VM per renderer generation.                                                                                                                          |
| Lua editor support                                        | [LuaLS](https://luals.github.io/wiki/definition-files/)                                                                                                                       | Ship generated LuaCATS definition files; it is tooling, not a runtime dependency.                                                                                                        |

Prefer direct SCTK for the first implementation: it exposes the ownership controls this architecture depends on without committing the shell to another UI framework.

## Progressive delivery

1. Supervisor plus a disposable hard-coded layer surface; pass the reload test.
2. Add Lua loader, one panel primitive, built-in diagnostics, and the configuration-failure tests.
3. Add composition, layout, input, text, models, signals, timers, and native animations.
4. Add multi-output/surfaces and the durable lock, greetd, and Polkit frontends.
5. Add broker IPC, notifications, and recording identity.
6. Port services and widgets one at a time; add the external capability protocol.
7. Add canvas and trusted shader packages; pass both the Obelisk and independent-shell tests before calling the framework general-purpose.

## Cleanup

- Retain each renderer's child handle, process group, and exit waiter. On handoff send `SIGTERM`, wait 2 s, kill the group, then wait/reap. Never force-kill a confirmed lock owner.
- Set renderer `PR_SET_PDEATHSIG`, then verify its parent is still the expected supervisor; otherwise exit. Keep the supervisor single-instance.
- Enforce byte/count bounds on insertion. Sweep TTL state every 60 s only as a backstop; never rely on allocator purges.
- Before decoding, cap encoded bytes and checked pixel bytes; also cap SVG input/output dimensions. Keep decoded assets generation-local.
- Removing a timer/binding/node calls `remove_registry_value` immediately. Every 60 s while idle, call `expire_registry_values` as a backstop. Keep Lua's default GC; reserve full collection for bulk scene removal or heap usage above 75%.
- Run the 100-reload memory test after dependency updates; quarterly remove unused crates and stale alternatives from this list.
