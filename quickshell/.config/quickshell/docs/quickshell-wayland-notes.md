# Quickshell Wayland Components – Field Notes

> Import namespace unless stated otherwise: `import Quickshell.Wayland`

---

## ScreencopyView (Item)

Displays a live video stream or single captured frames from a capture source.

- Key properties

  - `sourceSize: size` (readonly) – Size of the source image. Valid when `hasContent` is true.
  - `captureSource: QObject` – One of:
    - `null` – Clear the displayed image.
    - `ShellScreen` – Capture a monitor; requires compositor support for `wlr-screencopy-unstable` or both `ext-image-copy-capture-v1` and `ext-capture-source-v1`.
    - `Toplevel` – Capture a toplevel window; requires `hyprland-toplevel-export-v1`.
  - `live: bool` – If true, show live video instead of a still image. Default: false.
  - `constraintSize: size|unknown` – If set, constrains width/height of implicit size while preserving aspect ratio.
  - `hasContent: bool` (readonly) – True when there’s content ready to display; useful to delay visibility until ready.
  - `paintCursor: bool` – Paint the system cursor on the image. Default: false.

- Functions

  - `captureFrame(): void` – Capture one frame. No-op if `live` is true.

- Signals
  - `stopped()` – Compositor ended the stream. Restart attempts may or may not work.

---

## Toplevel (QObject)

Represents a window/toplevel from another application; obtainable from `ToplevelManager`.

- Notable properties

  - `minimized: bool` – Current minimized state; can request changes (compositor may ignore).
  - `appId: string` (readonly) – Application identifier.
  - `activated: bool` (readonly) – If currently focused/activated; request focus with `activate()`.
  - `maximized: bool` – Current maximized state; can request changes (compositor may ignore).
  - `parent: Toplevel` (readonly) – Parent toplevel if this is a modal/dialog, else null.
  - `screens: list<ShellScreen>` (readonly) – Screens the window is visible on; order is compositor-defined. Some compositors report only one screen even if visible on multiple.
  - `fullscreen: bool` – If window is fullscreen; can request changes (compositor may ignore). Fullscreen can be requested on a specific screen via `fullscreenOn()`.
  - `title: string` (readonly) – Window title.

- Functions

  - `activate(): void` – Request activation/focus.
  - `close(): void` – Request close; compositor or app may ignore.
  - `fullscreenOn(screen: ShellScreen): void` – Request fullscreen on a specific screen.
  - `setRectangle(window: QObject, rect: rect): void` – Hint: where this toplevel’s visual representation is relative to a Quickshell window; useful for effects like minimization.
  - `unsetRectangle(): void` – Clear rectangle hint.

- Signals
  - `closed()` – Window closed.

---

## WlSessionLock (Reloadable)

Implements the `ext_session_lock_v1` protocol to create a compositor lock screen that covers all screens.

- Usage pattern

  - When `locked` becomes true, Quickshell creates one `WlSessionLockSurface` per screen using the configured `surface` component.
  - Example:
    ```qml
    WlSessionLock {
      id: lock
      WlSessionLockSurface {
        Button { text: "unlock me"; onClicked: lock.locked = false }
      }
    }
    // later
    lock.locked = true
    ```

- Warnings

  - Only one `WlSessionLock` may be locked at a time. Enabling another lock while one is active does nothing.
  - If the lock object is destroyed or Quickshell exits without setting `locked` to false, conformant compositors will keep the screen locked/solid color. This is intentional for security.

- Properties
  - `locked: bool` – Controls lock state.
  - `surface: Component` – Component used to create the `WlSessionLockSurface` for each screen.
  - `secure: bool` (readonly) – True once compositor confirms all screens are covered with locks.

---

## WlSessionLockSurface (Reloadable)

The surface displayed by a `WlSessionLock` when the session is locked.

- Properties
  - `color: color` – Background color (default white). Transparent colors may behave oddly on some systems; recommended workaround is using a colored content item inside a transparent window rather than a transparent lock. Most compositors will ignore attempts to make a transparent lock.
  - `data: list<QObject>` (default/readonly) – Arbitrary data list (as shown in docs; details not provided).
  - `height: int` (readonly)
  - `width: int` (readonly)
  - `visible: bool` (readonly) – Surfaces don’t become invisible; they are destroyed when not needed.
  - `contentItem: Item` (readonly) – Root item of the surface.
  - `screen: ShellScreen` (readonly) – Screen this surface is displayed on.

---

## WlrKeyboardFocus (enum)

Degree of keyboard focus taken by a layershell-backed `PanelWindow`.

- Variants
  - `OnDemand` – Access as determined by OS. On some systems this may cause the shell to keep focus unexpectedly; try `None` if you see issues.
  - `None` – No keyboard input accepted.
  - `Exclusive` – Exclusive keyboard access; locks out all other windows. Not a secure lock screen. Use `WlSessionLock` to build a real lock screen.

---

## WlrLayer (enum)

Layer values for layershell-backed windows.

- Variants
  - `Top` – For panels, launchers, docks. Usually over normal windows and below fullscreen.
  - `Background` – Below `Bottom`.
  - `Overlay` – Usually renders over fullscreen windows.
  - `Bottom` – Above background, usually below regular windows.

---

## WlrLayershell (attached: PanelWindow)

Decorations-free window attachment using `zwlr_layer_shell_v1`. Exposed as an attached object on `PanelWindow`.

- Usage

  - Prefer `PanelWindow` (platform independent). When backed by layershell, the attached `WlrLayershell` is available.
  - Example:
    ```qml
    PanelWindow {
      WlrLayershell.layer: WlrLayer.Bottom
      // or dynamically
      Component.onCompleted: if (this.WlrLayershell) this.WlrLayershell.layer = WlrLayer.Bottom
    }
    ```

- Properties
  - `layer: WlrLayer` – Shell layer; defaults to `Top`.
  - `keyboardFocus: WlrKeyboardFocus` – Degree of keyboard focus; defaults to `KeyboardFocus.None`.
  - `namespace: string` – Identifier for external tools. Must be set before `windowConnected`.

---

## Quick tips

- For secure lock screens use `WlSessionLock` rather than layershell-exclusive focus.
- Screencopy of toplevels depends on compositor-specific protocols; Hyprland requires `hyprland-toplevel-export-v1`.
- When showing screencopy content, watch `hasContent` before making the view visible to avoid flicker.
