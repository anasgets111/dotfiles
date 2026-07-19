# Quickshell Memory Audit

Observed on Hyprland at 3440x1440:

- RSS: ~427 MiB
- PSS: ~326 MiB
- Anonymous memory: ~249 MiB
- One full-screen 32-bit buffer: ~18.9 MiB before additional Wayland/driver buffers

## Priorities

1. **Destroy the disabled input-display overlay**
   - Settings disable it, but Hyprland still reports its 3440x1440 surface as mapped.
   - In `shell.qml`, replace `LazyLoader.activeAsync: InputDisplayService.enabled` with `active: InputDisplayService.enabled`.
   - Likely saving: 20-60+ MiB.

2. **Split `MainScreen` into two windows**
   - Keep an always-resident bar-height `PanelWindow`.
   - Load a full-screen overlay only while a panel or modal is open, retaining it briefly for closing animations.
   - Likely saving: 35-80+ MiB while idle.

3. **Cap update output history**
   - `UpdateService.outputLines` is unbounded and copies the whole array for every line.
   - Retain only the last 200-400 lines; keep full logs in the update service journal if needed.
   - Prevents potentially large temporary heap growth during updates.

4. **Load the Niri overview wallpaper only while overview is open**
   - Track Niri's `OverviewOpenedOrClosed` IPC event through the WM facade.
   - Avoid keeping a second full-resolution wallpaper and live blur effect resident.
   - Consider a pre-blurred image instead of full-screen `MultiEffect`.

5. **Virtualize notification history**
   - Replace the history `Flickable` + `Column` + `Repeater` with `ListView`.
   - Optionally reduce stored notifications from 100 to 30-50.

6. **Reduce lock-screen peak memory**
   - Use a half-resolution blur source or pre-blurred wallpaper.
   - This affects locked-state memory, not the normal idle baseline.

## Leave Alone

- Wallpaper transition images and shaders are already loader-owned and destroyed after transitions.
- The 56-file wallpaper directory is too small to matter.
- The reusable command process pool is unlikely to be a major contributor.

## Verification

Compare fresh-start values before opening panels and after an update:

```bash
sed -n '1,35p' /proc/$(pgrep -n quickshell)/smaps_rollup
hyprctl layers
```

Prefer PSS and anonymous memory over RSS when judging improvements.
