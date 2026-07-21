# Quickshell UI/UX Refactor

## Goal

Make the shell as polished as Network and Bluetooth. Prefer UX over reuse; reduce code only when the result preserves or improves UX.

- Unify visual language and interaction patterns as far as practical.
- Keep domain-specific layouts where they are better than a common denominator.
- Prefer a prominent status/top card when a panel has meaningful state; do not require one for menus or domains where it adds no value.
- Preserve current panel widths and height behavior for now.
- Small behavior improvements are allowed when they simplify the design.
- Delete replaced APIs and files; do not keep compatibility wrappers inside this repository.
- Greeter is out of scope. Do not modify anything under `Greeter/`.

## Shared architecture

### `OModal`

Create one modal shell for App Launcher, Wallpaper Picker, and Idle Settings. It owns:

- Scrim, blur geometry, focus, Escape/scrim dismissal, and the launcher-style open/close animation.
- A Theme-backed default scrim color/opacity, with a per-modal override only for exceptional content.
- Shared responsive limits with a different preferred size per modal. The UI only needs to support screens down to 1080p.
- A content slot; modal-specific layouts remain local.

Modal searches clear whenever opened. Extend `OInput` so its internal field forwards key events to the caller; the modal, not `OInput`, owns list/grid navigation.

`OPopup` remains separate: it owns transient per-screen layer-shell windows, masks, namespaces, blur, and focus claims. `OModal` is interactive content inside `MainScreen`'s overlay window.

### `PanelCard`

Add a content-slot surface that owns padding, radius, border, background, and standard/active/warning/error tones. Active/connected cards use `Theme.activeSubtle` with an active-color border. Domain components supply their content.

### `PanelRow`

Add a standard row with:

- Leading icon, title, subtitle, badges, trailing actions, and optional expanded content.
- Normal, hovered, selected, disabled, and busy states.
- A single normal action on the whole row. A single destructive action stays explicit.
- Always-visible trailing actions; do not resize content on hover. More than two actions are allowed when a domain needs them.
- Action clicks never trigger the row action.
- At most one expanded row per owning list. The list/panel coordinates this with an expanded item key; `PanelRow` does not keep global expansion state.
- Busy rows disable clicks and replace actions with the shared spinner.

Roll it out through Network/Bluetooth first, then Audio, Launcher, and System Info.

### Existing components

- Rename `PanelTogglePill` to `PanelToggleCard`. Keep one adaptive component: layout width determines whether it is the full primary card or a compact secondary card.
- Make `PanelActionIcon` a thin `IconButton` specialization.
- Add one shared spinner visual for rows, toggle cards, and other busy indicators.
- Reuse `OInput` for Network credentials and modal search fields.
- Keep `InfoBadge`, `OButton`, `OComboBox`, `OToggle`, `Slider`, and `FillBar`.
- Do not extract `PanelStateMessage` or `PanelSectionHeader`; keep those small layouts local.
- Remove `SearchGridPanel`. Wallpaper Picker will use `OModal` with its own grid.
- Rename and move `OPanel` to `Modules/Shell/PanelHost.qml`.
- Move `LockContent.qml` beside `LockScreen.qml` under `Modules/Global`.

## Interaction contract

- Basic keyboard support only: type in searches, arrows navigate launcher/wallpaper results, Enter activates the selection, and Escape closes panels/modals.
- If an inline input is active, first Escape cancels/clears it; second Escape closes the panel.
- Focus uses the standard active border. Disabled controls use `Theme.opacityDisabled` and no pointer cursor.
- Destructive actions use `Theme.critical`, remain explicit, and execute immediately without confirmation.
- Data indicators may use role-specific hover feedback; they do not have to imitate `IconButton`.
- Loading must keep layout geometry stable.

## Theme cleanup

Perform a repository-wide visual-value pass:

1. Reuse an existing `Theme` value when it represents the same intent, even if it slightly changes the old literal.
2. Use simple meaningful relationships such as `Theme.animationDuration * 2`.
3. Add a semantic value only when it has a distinct reusable purpose.
4. Never add numeric names such as `size255`, or arbitrary arithmetic merely to reproduce a literal.

Colors, spacing, radii, typography, sizes, timing, and any other meaningful UI constants belong in `Theme.qml`. Functional constants remain with their owning logic.

## Panel specifications

### Network

- Use the main Network toggle card as the prominent status surface.
- Show the preferred/default connection name, IP, Wi-Fi band/signal, or Ethernet speed. If Wi-Fi and Ethernet are both connected, show only the preferred connection here.
- Keep compact Wi-Fi and Ethernet toggle cards below it. Put Ethernet IP/speed in its existing toggle card and remove the separate Ethernet hero.
- Put the connected Wi-Fi network first inside Saved as a selected row; remove its separate hero.
- The connected row is not clickable because details are already in the status card. Keep Disconnect and Forget visible as trailing actions.
- Disconnected saved rows connect on row click; credentials expand inline.
- Keep local Saved/Available labels, but make Network's list density follow Bluetooth's better compact treatment.
- Continue scanning automatically when the panel opens.

### Bluetooth

- Use the main Bluetooth toggle card for connected count plus the primary device name/battery.
- Put connected devices inside Paired as selected rows; remove the separate connected hero.
- A connected audio-device row expands codec details on click. Disconnect and Forget remain visible trailing actions.
- Continue discovery automatically while the panel is open.

### Updates

Use distinct status, package/log, and footer cards. Keep the current panel width.

Available updates:

- Status card: update count, total download size, and last-check time.
- Fixed-height alphabetic package table with sticky `Package | Old Version | New Version` header.
- No individual sizes and no row interaction.
- Full-width Update button in the footer; start immediately.
- Show Check only when results are stale.
- “Stale” means the latest check failed or the last successful check is older than the existing 15-minute poll interval. Track successful-check time separately from failed attempts.

Checking:

- Never check automatically on panel open.
- Manual Check replaces the table with a spinner and “Checking…”.
- On failure, retain the last successful list and mark it stale.

Updating:

- Replace the table with the exact live line text/order in a normal `PanelCard`, using the current font and no timestamps/collapsing.
- Strip or ignore command ANSI styling, then apply Obelisk semantic colors to warnings, errors, downloading, installing, upgrading, and other important lines.
- Follow output until the user scrolls up; resume when they return to the bottom.
- Status card: current step, package, `current/total`, and package-count progress.
- Parse the existing update/pacman output. Use indeterminate progress during downloads/hooks and determinate progress only for reliable `(current/total) installing/upgrading` lines.
- Remove cancellation from the UI, `UpdateService`, and `bin/.local/bin/update`.

Completion:

- Stay open with a compact package/count/duration/warnings/reboot summary.
- Parse the existing reboot-required hook output as the authority, but show only a general reboot requirement, not its component list.
- Keep the completed log collapsed behind View log.
- On failure, show an error summary above the preserved log and retain the existing Retry action. Partial success remains visible only in the log.
- With no updates, show a compact Up to date card with last-check time and Check in the footer.

### Audio

Use GNOME-like hierarchy with KDE-like mixer depth:

- Master output is the prominent first card; its device picker expands inline.
- Microphone/input is a second full card with inline device selection.
- Application streams remain always visible below both master cards.
- Clicking an application icon toggles mute; its slider controls volume.

### Notifications

- Top card shows notification count and Do Not Disturb.
- Clear all is a destructive secondary footer action.
- Keep `NotificationCard` specialized. History must retain groups, expansion, inline replies, and actions.
- Keep current notification-group expand/collapse behavior.

### Tray menu

Keep its compact native-menu structure: rows, submenus, and separators. Do not force status cards onto it.

### Idle Settings

- Use the main Idle enabled state as the prominent top card.
- Use one `PanelCard` per settings section with standardized setting rows inside.
- Changes continue applying immediately; no Apply button.

## Modal specifications

### App Launcher

- Keep the search-first list layout.
- Normal apps and Calculator, Currency, and Web provider results all use `PanelRow`.
- Providers map their result, metadata/badge, leading icon/text, and Enter hint into the shared row rather than custom delegates.

### Wallpaper Picker

- Use `OModal` with a specialized thumbnail grid on the left and a compact settings card on the right.
- Settings include monitor, fill mode, transition, and theme. The two-column layout may assume 1080p or larger.
- Apply every selection or setting immediately.
- Remove Apply/Cancel/footer/close buttons. Escape or scrim click closes the modal.
- Search uses `OInput`; arrows navigate tiles and Enter selects the wallpaper.

## Flyouts and overlays

### Weather

- Keep the three-day summary visible and expand the remaining forecast below it.
- Keep the specialized day layout, using `PanelCard` for each surface.

### System Info

- Keep the expandable header and collapsed summary percentages. When expanded, show only the collapse chevron; remove “live”.
- CPU, Memory, and GPU use `PanelCard`.
- Each disk uses an expandable `PanelRow`; partitions are compact non-interactive rows in its expansion slot.
- Disk partitions always start collapsed.
- Keep uptime and boot time as footer metadata.

### Popup and secure surfaces

- Keep `OPopup` for Notification, OSD, and Input Display windows.
- OSD and Input Display may use `PanelCard` for their visual surfaces.
- `NotificationCard` stays specialized and aligns through `Theme`, not `PanelCard`.
- `PolkitDialog` remains its own authenticated window but reuses `PanelCard`, `OInput`, and shared styling.
- Lock Screen remains a session-lock surface and reuses appropriate controls/styling.
- Calendar is unchanged and out of scope.

## Bar

- Keep the current left/center/right layout.
- Audit every indicator and align height, radius, animation timing, and tooltip behavior where their semantics match.
- Do not force every custom indicator through `IconButton`; preserve specialized behavior.
- Interactive bar widgets, including icon buttons, Battery, and Volume, have no visible border at rest. Keep border width allocated with a transparent color so hover cannot shift layout or inner content.
- Hover adds the widget's role-appropriate fill/surface plus a clearly contrasting border. Volume keeps its expanded data track rather than adopting a generic hover fill.
- Select the hover-border color through cross-theme visual testing. Test it against normal hover fills, Volume's muted/normal/headroom fills, and Battery's normal/warning/critical fills. Reuse an existing Theme color when it remains distinct in every bundled scheme; otherwise add a semantic bar-hover-border value.
- Window title remains display-only.
- Workspace Strip remains `ExpandingPill` with `IconButton` delegates.
- Volume keeps its specialized hover expansion into a slider.
- Battery keeps its percentage-pill shape, pointer, and hover behavior. Change its normal fill so it is visually distinct from hover: try `Theme.powerSaveColor`, retain warning/critical thresholds, check every bundled color scheme, and add a semantic battery color only if needed. A battery configuration panel is future work.

## Service and architecture boundaries

- Do not extract `SysfsLevelDevice`; Brightness and Keyboard Backlight remain independent.
- Fix `SysfsValue` so a valid parsed zero is not replaced by its fallback.
- Keep WM backend selectors explicit in each facade.
- Keep the finite streamed update process local to `UpdateService`; do not add `CommandTask`.
- Do not add `Command.exists()` during this refactor.

## Implementation and review

Complete the refactor before the final user review, but work in bounded passes:

1. Theme cleanup and component foundations (`PanelCard`, `PanelRow`, `OModal`, spinner, `OInput`, icon consolidation).
2. Network and Bluetooth reference migration.
3. Updates and update-script simplification.
4. Audio, Notifications, Tray, and Idle Settings.
5. App Launcher and Wallpaper Picker.
6. Weather, System Info, popups, secure surfaces, and bar cleanup.
7. File moves, dead-code deletion, and final cross-tree consistency audit.

Every pass must:

- Follow Ponytail mode: understand flows first, reuse before adding, and keep the smallest correct diff.
- Receive a separate-agent review before the next pass. The primary agent resolves that review's findings.
- Preserve behavior unless an approved improvement or a clear simplification justifies a change.
- Run proportional static checks without running `quickshell` or `stow`.

Final verification covers keyboard basics, focus/Escape behavior, hover without layout shift, busy/disabled states, modal animation/dismissal, update states, Theme consistency, and removal of dead APIs.
