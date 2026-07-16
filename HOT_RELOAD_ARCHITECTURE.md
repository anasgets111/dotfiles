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
- Allow one active reload and one pending reload; newer changes replace the pending request. Quickshell's own `RootWrapper::reloadGraph` has no reentrancy guard — a second reload during an in-flight one can race two live engines — so this single-active/single-pending rule is a deliberate fix, not an assumption.
- Start a renderer staged; `ready` means every output in that transaction is configured and renderable.
- Retain every child handle, reap on exit, and contain each renderer in its own process group.
- Commit only after `ready`; discard and reap a failed candidate after a 5 s timeout. This all-or-nothing gate mirrors the same discipline atomic KMS already provides at the modeset level (`DRM_MODE_ATOMIC_TEST_ONLY` validates a whole multi-output configuration before any hardware change), applied one layer up at generation handoff instead of at the modeset.

### Renderer

- Own only the UI scene, animations, surfaces, and generation-local caches.
- Stage surfaces unmapped with exclusive zone `0`, keyboard disabled, and an empty input region.
- Never own durable state, public endpoints, authentication, or detached jobs.
- Exit completely after handoff; do not reuse its UI engine or allocator.
- Register each output's `wl_surface.frame` callback as its own Calloop event source and render/present that surface only when its own callback fires — the protocol already decouples per-output redraw timing, so outputs never share a redraw clock (clients must not throttle on output count or a shared tick). WGPU's `Fifo`/`FifoRelaxed` present modes block `get_current_texture()` on that surface's own queue slot, so run each surface's acquire-render-present step off Calloop's dispatch thread (one worker per output) rather than inline in the shared loop; a stalled present on one output must not stop Calloop from servicing others. This is a real risk, not a hypothetical one — `cosmic-comp` (Smithay, the same protocol layer this architecture builds on) has shipped with a single output's stalled page-flip freezing its entire compositor.
- `wgpu::Device`, `Queue`, and `Surface` are all `Send + Sync` (no Linux-relevant thread-affinity restriction), so a `Surface` created on the Calloop thread — where SCTK's Wayland connection lives, needed for the window handle — can be handed off to and used exclusively by its own per-output worker thread, while Device/Queue are shared for submission across all workers. Workers report frame results back to the Calloop thread through calloop's bounded [`sync_channel`](https://docs.rs/calloop/latest/calloop/channel/index.html) — the standard cross-thread-to-single-reactor primitive, and bounded to match every other queue in this document (Invariants) — so Lua callbacks still only ever run on the Calloop thread, never on a render worker. The device-lost callback gets its own single-slot channel rather than sharing the frame-result one: [the WebGPU spec wgpu implements](https://webgpu-native.github.io/webgpu-headers/Asynchronous-Operations.html) allows a spontaneous callback to fire on an arbitrary thread at an arbitrary time, and [documents that the device is locked for reading while it runs](https://toji.dev/webgpu-best-practices/device-loss.html) — any wgpu call needing write access (e.g. destroying a resource) from inside the callback deadlocks. The callback must therefore only enqueue a notification and return; actual teardown happens on the Calloop thread afterward, never inside the callback itself.

### Lua configuration

`shell.lua` is the user-facing configuration entry point. It returns a declarative scene built with the framework API; users edit Lua and hot reload without rebuilding Rust.

#### Runtime boundary

- Embed mature PUC Lua 5.4 with [`mlua`](https://docs.rs/mlua/latest/mlua/) using `lua54,vendored`; [Lua 5.5 is still at 5.5.0](https://www.lua.org/versions.html), so reconsider it after its first bug-fix release or a measured GC need.
- Create one Lua VM per disposable renderer generation. Supervisor, broker, and lock/auth processes never execute user Lua.
- Accept text chunks only and name each chunk with its canonical path for tracebacks. Do not cache Lua bytecode across framework versions.
- Build the VM with [`Lua::new_with`](https://docs.rs/mlua/latest/mlua/struct.Lua.html#method.new_with) and only `StdLib::TABLE | STRING | MATH | UTF8` (mlua's `sandbox()` is Luau-only and does not apply to vendored PUC Lua 5.4). `StdLib::BASE` still brings in `load`, `loadfile`, `dofile`, and `collectgarbage`; `nil` these out of `globals()` after construction rather than relying on the flag set alone. Replace `print` with a rate-limited logger and expose OS access only through explicit asynchronous capabilities.
- Use a custom `require` rooted at the canonical config directory and explicit trusted include roots. Reject traversal/symlink escape, record every dependency path, and hash loaded content.
- Default limits: 4 MiB total source, 64 MiB Lua heap, 20,000 scene nodes, 4,096 bindings, and 1,024 timers. Rust-side scene/cache limits remain separate.
- Check a monotonic deadline from an instruction hook: 10 million instructions/250 ms for build and 1 million/16 ms per callback. Native capabilities must never block the renderer thread.
- Execute Lua only on the renderer event-loop thread; background work returns immutable messages. Rust callbacks validate inputs and return Lua errors rather than panicking across the boundary.

These limits protect availability, not hostile-code isolation; the renderer still runs as the user. Raising them requires a trusted CLI/configuration option outside Lua.

A fresh VM also clears registered handlers naturally, a pattern already proven by [WezTerm's Lua reload model](https://wezterm.org/config/lua/wezterm/on.html).

#### UI model

- Lua constructors produce a typed retained scene; Rust validates properties, ownership, output targets, and limits before creating surfaces.
- The root scene declares an API version; reject unsupported versions before creating surfaces.
- Scene construction is side-effect-free: stage timers, subscriptions, and watches disabled, and reject action capabilities until the generation lease is active. This applies to every construction transaction, not only the initial reload build (Reactivity and update).
- Use explicit signals and property mappings instead of implicit global dependency tracking. QML's own bindings cascade automatically on any read dependency, and QML's own documentation warns this causes real binding loops (e.g. sizing a container from `childrenRect` while a child sizes itself from the container) — a deliberate reason to require explicit dependency lists here rather than inherit that failure mode. Persist only byte-bounded JSON-compatible values through the broker.
- Authentication theming is compiled by a disposable, unprivileged Lua process into a validated data-only scene. It may describe native animations and clock-driven bindings, but authentication owners never receive Lua callbacks.

#### Component model

- A component is a plain Lua function `function(props, ctx) -> node` returning a descriptor built exclusively by framework constructors (`ui.row{...}`, `ui.text{...}`), never a hand-assembled table — constructors validate their own field names against the constructor's declared schema at call time, so a typo fails immediately instead of silently producing an inert table. That same schema generates the LuaLS definitions (Developer experience).
- A descriptor carries typed `props`, a children list or named `slots` table for composition, event fields (`on_click = function(ctx) ... end`) invoked as protected calls, and optional `on_mount` / `on_update` / `on_unmount` lifecycle fields.
- Lua build produces this lightweight descriptor tree, not the retained scene. Within one renderer process, Rust diffs each new descriptor tree against the previous retained tree for the same component instance and mutates only what changed (Reactivity and update) — the same reconciliation a component's own keyed children use, applied to the whole tree.
- Reload is not a diff: generation `N+1` mounts fresh in a new process with no access to `N`'s retained tree (an initial mount is simply a diff against nothing), so persistence across reload is opt-in and explicit rather than automatic. A signal or property may declare a stable `persist_key`, restored from the broker's byte-bounded snapshot (State and authority broker) — the same role Quickshell's `Reloadable.reloadableId` already plays for matching objects across engine reloads, just declared per-signal instead of per-object.
- `on_mount` fires once the diff introducing a node commits and its generation lease is active; `on_unmount` fires before that lease releases; `on_update` fires when a node survives a diff with changed props. All three are protected calls: an error disables further lifecycle callbacks for that node and logs a diagnostic without failing the diff.
- Keyed collections: `ui.repeater{ items = list, key = function(item) return item.id end, render = function(item) return ... end }`. Diffing matches children by key when a key function is supplied and by tree position otherwise — one mechanism, not two. Matched instances update in place; unmatched old keys unmount; unmatched new keys mount. This mirrors the `model.values.find(x => x.key === ...)` lookup the current QML services already use for keyed lists (e.g. Bluetooth devices).
- A reusable module is a plain `require`d Lua file returning tables/functions. Lua's own per-VM module cache already gives "load once per generation" for free, so a generation-local service needs no separate singleton mechanism — a module builds its state (signals, timers, subscriptions) on first `require` and returns it. Its resources are leased to whichever node or controller first required it and released when nothing still holds that lease; a module required from two places stays alive as long as either requirer does.

#### Reactivity and update

- `local s = signal(initial)` exposes `s:get()` / `s:set(v)`. `local c = computed({s1, s2}, function(v1, v2) return ... end)` takes an explicit dependency list — never implicit tracking through global reads — and exposes `c:get()`. Writing a signal marks every component instance whose props or computed bindings explicitly named it as dirty.
- Rust coalesces dirty instances per event-loop tick and re-invokes only their builder closures, producing new descriptors for just those subtrees, diffed against the existing retained subtree in the same process (Component model). This is an in-process update with no cross-process surface handoff, generation, or health window — reload is a different, coarser operation (a fresh mount in a new process, Reload transaction), not a bigger version of this diff. It carries the same side-effect-free-during-construction rule as any build and runs under the build instruction deadline as its own transaction, separate from whatever callback deadline the triggering signal write executed under. Whether per-instance subtree granularity (rebuilding a whole component's closure) is fine-grained enough at real Obelisk scale, or needs finer-grained property-level patching later, is a benchmark question — no documentation answers it, only measured rebuild cost per tick once components exist to measure.
- `timer.after(ms, fn)` and `timer.every(ms, fn)` return a cancellable handle backed by a native Calloop source holding a protected Lua callback; `handle:cancel()` stops it early, and it is cancelled automatically when its owning node or controller unmounts. Capability calls are callback-based (`capability.request(args, function(ok, result) ... end)`), never coroutine-based `await`: background work already returns immutable messages into the callback on the renderer thread, and callback-only avoids adding coroutine-resumption-across-ticks machinery before it is proven necessary. A timer or capability callback that errors disables and releases only that handle; it does not touch sibling handles or force a rebuild.
- Animations and behaviors are declared, not driven, from Lua: a descriptor's `behavior` field (or an explicit `ui.animate{...}` call) describes target value, duration, easing, and delay. Rust's native scheduler owns the running tween in WGPU and calls Lua at most once, on completion — never once per animation frame. A rebuild that leaves a behavior spec unchanged is a diff no-op; a changed spec retargets the running animation in Rust.
- A custom canvas records a bounded command list only when invalidated, using the same declare-then-let-Rust-drive discipline as animations.

#### Process APIs

- `process.run{cmd, args, env, cwd, stdin, timeout_ms}` starts an asynchronous, generation-scoped child in its own process group and returns a handle. Two shapes cover the two patterns the current Command/CommandStream QML services already use: a one-shot mode that collects bounded stdout/stderr and resolves a callback with `(ok, exit_code, stdout, stderr)`, and a streaming mode that delivers `on_line` / `on_error_line` callbacks as output arrives and auto-restarts on unexpected exit with capped exponential backoff (mirroring `CommandStream.qml`'s existing `restartDelay * backoff^n` policy).
- A per-call `timeout_ms` (or explicit `handle:cancel()`) escalates the same way generation handoff already does: `SIGTERM` to the process group, wait, then `SIGKILL` and reap (Cleanup) — one escalation policy, not a second one for Lua-spawned children.
- Children spawned by `process.run` get `PR_SET_PDEATHSIG` against the renderer, the same mechanism the renderer itself uses against the supervisor (Cleanup): a renderer crash kills its own children without the supervisor tracking each one individually.
- `process.spawn_detached{...}` is a distinct supervisor request with no inherited pipes; it outlives the calling Lua generation and renderer, and the supervisor — not the renderer — owns its process group and reap. Never implicitly promote a `process.run` handle into a detached job.
- Detached jobs are ephemeral (reaped on supervisor exit, like any plain child) unless declared durable via an explicit manifest entry (name, restart policy, resource limits) — the same manifest mechanism durable external extensions require (Extensibility), not a second one. The supervisor sets `PR_SET_CHILD_SUBREAPER` so detached jobs reparent to it rather than init, keeping `waitpid` reachable for as long as the supervisor lives. A supervisor crash is the one case a durable job's parent becomes init until the supervisor restarts and reconciles the manifest against the live process table; PIDs from before the crash cannot be re-attached for exit-status delivery, only rediscovered as still-running or gone.

#### Ownership, leases and cleanup

- Every acquirable resource — scene node, signal/computed binding, timer, subscription, capability instance, `process.run` handle, detached-job reference — is created against a **lease**: a (generation, owner) pair held by Rust and referenced from Lua only as an opaque handle. Shared capabilities (two nodes reading the same network state) hold independent leases on one running instance; the instance stops when its last lease releases.
- Cleanup triggers, all deterministic:
  - **Conditional/lazy removal**: a diff that drops a node walks that subtree post-order (children before parent), calling `on_unmount` as a protected call and releasing every lease the node held, before the parent's own removal proceeds.
  - **Reload**: the old generation's leases release after the health window on success, or immediately on rollback of the candidate (Reload transaction).
  - **Callback failure**: an erroring timer, subscription, or lifecycle callback disables and releases only that one lease; it does not cascade to siblings or force a rebuild.
  - **Crash**: process exit is the backstop, not the primary mechanism — the OS reclaims every lease a crashed renderer held, which is why disposable processes bound memory regardless of whether the other three triggers ever miss something.
- Demand-driven activation is transitive by construction, not a special case per capability: each build or rebuild transaction computes the capability set reachable from live scene nodes, timers, and explicit jobs. Anything freshly reachable starts immediately; anything no longer reachable schedules a stop after a short bounded grace period (anti-flap — starts are never delayed, only stops are debounced). This applies uniformly to every current and future capability, including ones compiled into the binary but unused by the live configuration.
- Leak detection reuses the live-lease inventory built for developer inspection (Developer experience): a debug dump lists every live lease with its resource kind, owner node id, and age. The 100-reload memory sample (Invariants) is the coarse signal; asserting the lease dump returns to its pre-test set after N reload cycles is the precise regression test for the "every running facility is held by a traceable lease" invariant.

#### Demand-driven capabilities

- Loading a Lua module only returns definitions and inert handles; it may not allocate a backend resource, connect to a service, bind a protocol object, start a thread/process/timer, register a public endpoint, or begin polling.
- Lua evaluation may declare capability dependencies but cannot start them — activation, refcounting, and shutdown are Rust's job (Ownership, leases and cleanup above).
- Capability startup failure produces an error state on its signal/action; it does not crash unrelated UI or trigger polling retries without a subscriber.

#### Authoring freedom contract

Lua defines the shell rather than filling slots in a Rust-defined shell. Users must be able to create different surface topologies, components, controllers, and local services without rebuilding Rust (Component model, Reactivity and update, Process APIs). The framework must also provide:

- anchors plus row, column, grid, flow, stack, scroll, and virtualized list layouts with implicit/minimum/preferred/maximum sizing;
- text, icon fonts, images/SVG, gradients, clipping, transforms, masks, shadows, blur, canvas commands, and per-output scaling;
- pointer buttons, wheel, hover, tap, drag, keyboard focus/shortcuts, text editing, selection, clipboard, IME, and accessibility roles;
- background/panel/overlay/popup surfaces with anchors, margins, exclusive zones, input regions, focus policy, per-output instances, and hotplug;
- keyed reactive models with map/filter/sort derivation, plus capability APIs for notifications/replies, tray menus, audio/media, network, Bluetooth, power, brightness, workspaces/windows, wallpaper, weather, updates, recording, files, processes, sockets, HTTP, and D-Bus.

All required Lua modules, assets, and shader packages participate in dependency watching and transactional reload (Extensibility). Native Lua modules, FFI, and in-process plugins remain forbidden because they defeat the memory and crash boundary. Direct Wayland protocol and rendering integration remains core Rust work, as equivalent functionality also requires native Quickshell support.

Obelisk parity is the baseline test: bar/panels, launcher keyboard navigation, virtualized network list and text input, notification inline reply, tray menus, animated wallpaper shaders, multi-output hotplug, lock screen, greeter, and Polkit must pass behavior tests. Generality additionally requires a second shell with different surfaces and interaction structure, built only from Lua and external capability processes.

#### Extensibility

- **Pure-Lua packages**: `require`d files under the trusted include roots, already covered by dependency watching, hashing, and reload (Configuration errors). No package manager or registry yet — Quickshell itself ships without one (`qmldir`-based directory imports only), and files copied or vendored by the user are enough until real multi-author package sharing proves otherwise.
- **Supervised external capability processes**: a capability the built-in API doesn't cover is a separate OS process speaking the broker's size-prefixed, capped JSON protocol (Rust implementation candidates) over a Unix socket, bound by the same IPC invariants (frame/queue size and count — Invariants) already declared globally; extension IPC is another client of those numbers, not a new ceiling. Extensions publish typed state streams and actions; they never load into the supervisor, broker, renderer, or authentication address spaces. They are generation-scoped and reaped by default; durable extensions need the same manifest (name, restart policy, resource limits) as durable detached jobs (Process APIs) — one manifest mechanism, not two.
- **Runtime-loaded shader packages**: a manifest (uniform schema, resource bindings, entry points) plus WGSL source, compiled at load time through WGPU/naga's existing runtime shader-module compilation — no extra crate. Resource/binding counts reuse WGPU's own cross-backend-guaranteed [`Limits`](https://docs.rs/wgpu/latest/wgpu/struct.Limits.html) defaults (`max_bind_groups: 4`, `max_bindings_per_bind_group: 1000`, `max_storage_buffers_per_shader_stage: 8`) rather than a new invented ceiling — a shader package is rejected the same way any other pipeline exceeding these limits already would be. WGSL source text size has no equivalent existing bound and remains unmeasured, not zero — there is no documentation to research here, only a number to pick by trying real shader packages and naga compile times once the loader exists.
- **What genuinely requires new Rust framework support**: new UI primitives, layouts, or input/text/accessibility behavior; new Wayland protocol integration; new capability categories needing direct system access no IPC protocol can express; and any change to the scene/diff/animation engine itself. Everything else — new widgets composed from existing primitives, new capability backends behind the existing IPC shape, new shaders behind the existing manifest shape — is a Lua-and-manifest-only addition, no Rust change required.

#### Developer experience

- Structured diagnostics (phase, generation hash, canonical file, line/column, traceback, cause chain, repeat count — Configuration errors) are emitted both as the built-in popup and as JSON lines on a debug channel, so tooling and tests can assert on them without scraping the popup.
- LuaLS `*.d.lua` definitions are generated from the same property/event schema Rust uses to validate scene descriptors at runtime (Component model) — one schema, not a hand-maintained IDL kept in sync by hand.
- The live lease inventory (Ownership, leases and cleanup) doubles as the inspector: a debug query over the same bounded IPC used for extensions returns the scene tree, explicit signal/computed dependency edges (already data, since dependencies are declared, not inferred), and every live lease with its owner node id — the direct answer to "which configuration object owns this running resource."
- Frame-time and build/rebuild-cost profiling uses standard `tracing` spans per subsystem (scene build, diff, layout, paint, animation tick) rather than a bespoke profiler.

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

A live in-process rebuild (Reactivity and update) running inside `N` needs no coordination with this transaction: `N+1` always mounts fresh from current Lua source in its own process and never resumes `N`'s in-flight diff state, so a rebuild in `N` simply finishes or is abandoned harmlessly whenever `N` is frozen (step 5) or torn down (step 9) — there is no shared state for the two to race on.

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
| GPU/adapter resource loss (VRAM exhaustion, device reset)     | Detect via WGPU's `Device::set_device_lost_callback` and treat as an active-renderer failure, using the same recovery row above — not a per-output degrade. |

A single WGPU `Device` is ordinarily shared across every surface on one adapter, so its loss is not isolable per-output; keeping unaffected outputs alive would need a separate `Device` per physical GPU, which only exists on genuine multi-GPU/hybrid setups and is a possible future refinement, not a baseline promise. This matches observed reality rather than an ideal: `cosmic-comp` (Smithay, the same protocol layer this architecture builds on) currently restarts the whole compositor session on an AMD GPU reset rather than degrading one output, and Mutter's atomic-KMS path has shipped equivalent whole-session fallbacks (`MUTTER_DEBUG_FORCE_KMS_MODE=simple`) when a commit fails. Recovering only the failed renderer generation, as the table above already does for any other active-renderer crash, is the honest baseline.

The callback's arbitrary-thread/read-lock contract above is confirmed at the WebGPU spec level; whether `wgpu`'s own Vulkan backend actually surfaces a device-lost event promptly and consistently on our real target drivers (Mesa AMD/Intel, proprietary NVIDIA) is not something documentation can answer — `cosmic-comp`'s own bug tracker shows this behavior is inconsistent across vendors in practice. This needs an actual fault-injection test once a renderer exists (e.g. force a reset via `nvidia-smi --gpu-reset`/Mesa's fault-injection layers, or simply unplug an external GPU) and is listed as such below, not assumed.

- The custom loader reads and hashes each module before executing that chunk, records the complete dependency graph, then verifies every hash after root evaluation. Watch parent directories for missing modules. Keep the last two successful source bundles; never store functions, userdata, secrets, or bytecode.
- Every Lua entry point is a [protected call](https://www.lua.org/manual/5.4/manual.html#2.3) from Rust. Report structured phase, generation hash, canonical file, line/column when available, traceback, cause chain, and repeat count.
- Diagnostics are rendered by a built-in mode of the binary, independent of Lua. Replace the previous reload diagnostic and rate-limit repeats instead of stacking popups.
- Warnings and deprecations may commit but remain visible; errors never commit. A strict `--deny-warnings` mode belongs to tooling, not user Lua.
- Test syntax errors, missing modules, edits during load, infinite loops, Lua OOM, callback failure, candidate/active crashes, invalid lock themes, and an induced GPU device loss/reset per real backend (Vulkan on Mesa AMD/Intel, proprietary NVIDIA) — the last one can only be characterized by fault injection on real hardware, not by reading documentation. Each fix must trigger a new candidate automatically.

## Invariants

- At most one renderer accepts input or reserves exclusive space; brief visual overlap or a gap is allowed.
- Exactly one process owns each D-Bus name, IPC socket, and detached job.
- IPC frames and snapshots are at most 1 MiB; each client queue is at most 256 messages and 4 MiB.
- Notification history is at most 100 entries and 1 MiB of text; each renderer's decoded-image cache is at most 256 MiB.
- No old-generation PID survives a successful handoff.
- Apart from the supervisor/file watcher and the active renderer's event loop and Wayland connection, every running facility is held by a traceable lease (Ownership, leases and cleanup).
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
| Structured diagnostics and profiling                      | [`tracing`](https://docs.rs/tracing/latest/tracing/), [`tracing-subscriber`](https://docs.rs/tracing-subscriber/latest/tracing_subscriber/)                                  | Per-subsystem spans (build, diff, layout, paint, animation); a JSON-line subscriber is the debug diagnostic channel (Developer experience).                                              |

Prefer direct SCTK for the first implementation: it exposes the ownership controls this architecture depends on without committing the shell to another UI framework.

## Progressive delivery

1. Supervisor plus a disposable hard-coded layer surface; pass the reload test.
2. Add Lua loader, one panel primitive, built-in diagnostics, and the configuration-failure tests.
3. Add composition, layout, input, text, keyed models, signals, timers, `process.run`, and native animations; add the lease inventory and its debug inspector alongside.
4. Add multi-output/surfaces and the durable lock, greetd, and Polkit frontends.
5. Add broker IPC, notifications, `process.spawn_detached`, and recording identity, sharing one durable-manifest mechanism.
6. Port services and widgets one at a time; add the external capability protocol.
7. Add canvas and trusted shader packages; pass both the Obelisk and independent-shell tests before calling the framework general-purpose.

## Cleanup

- Retain each renderer's child handle, process group, and exit waiter. On handoff send `SIGTERM`, wait 2 s, kill the group, then wait/reap. Never force-kill a confirmed lock owner.
- Set renderer `PR_SET_PDEATHSIG`, then verify its parent is still the expected supervisor; otherwise exit. Keep the supervisor single-instance.
- Enforce byte/count bounds on insertion. Sweep TTL state every 60 s only as a backstop; never rely on allocator purges.
- Before decoding, cap encoded bytes and checked pixel bytes; also cap SVG input/output dimensions. Keep decoded assets generation-local.
- Removing a timer/binding/node calls `remove_registry_value` immediately. Every 60 s while idle, call `expire_registry_values` as a backstop. Keep Lua's default GC; reserve full collection for bulk scene removal or heap usage above 75%.
- Run the 100-reload memory test after dependency updates; quarterly remove unused crates and stale alternatives from this list.
