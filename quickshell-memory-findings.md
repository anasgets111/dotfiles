# Quickshell Memory Findings

Baseline: 425 MB RSS (~226 MB anon heap = pixel data; JS heap only 4 MB — no leaks, services well-bounded).
On NVIDIA every window buffer/texture is mirrored in RSS. Fullscreen buffer @ 3440×1440 ≈ 20 MB.

## Tier 1 — structural

- **MainScreen fullscreen always** — `Modules/Shell/MainScreen.qml:47` `implicitHeight: screen.height` for a bar-height strip. Fix: bind height to `shouldCaptureBackground ? screen.height : Theme.panelHeight`, or split bar window + LazyLoader fullscreen overlay window. (~40–90 MB)
- **Wallpaper images cache pixmaps** — `AnimatedWallpaper.qml:95,125`, `OverviewWallpaper.qml:28` missing `cache: false`; each decode (~19 MB) stays in QML pixmap cache alongside the GPU texture, old wallpapers accumulate. (~20–40 MB)
- **OverviewWallpaper (niri only)** — fullscreen window + full-res hidden Image + live MultiEffect blur FBO, alive permanently for overview-only content. Fix: quarter-res `sourceSize` and/or pre-blur to cached file, plain Image. (~40–80 MB on niri)

## Tier 2 — transient spikes

- **LockScreen wallpaper native-res decode** — `LockScreen.qml:110` no `sourceSize` (6000×4000 photo → ~92 MB) + fullscreen blur FBO. Cap to screen size; optional half-res `layer.textureSize`.
- **Launcher icons full-res decode** — `AppLauncher.qml:359` no `sourceSize` for 34 px slot (icon themes ship up to 1024²).
- **Notification history non-virtualized** — `NotificationHistoryPanel.qml` Column+Repeater instantiates up to 100 NotificationCards. Fix: `ListView { reuseItems: true }`.
- **UpdateService.outputLines unbounded** — `UpdateService.qml:280` concats every pacman line, O(n²), reset only next run. Keep last ~300.

## Tier 3 — minor

- `PolkitDialog.qml:13` dialog tree resident from startup → `Loader { active: agent.isActive }`.
- `DateTimeDisplay.qml:90` tooltip weather column eager → move behind hover Loader (like `IconButton.qml:145`).
- `Command.qml:73` pooled processes retain last stdout string → clear on release.

## Tier 4 — env pragmas (shell.qml, measure each)

- `//@ pragma Env MALLOC_ARENA_MAX=2` — glibc arena bloat from render threads. (30–80 MB, zero cost)
- `//@ pragma Env QSG_RENDER_LOOP=basic` — one GL context for all windows instead of per-window. (20–60 MB; test transition smoothness)

Expected: ~425 MB → ~200–250 MB idle.
