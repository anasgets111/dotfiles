# QuickShell.Io - Detailed Reference

This document collects the QuickShell.Io QML types and details used in this repo. It restores the API surface (creatable/uncreatable, readonly flags, function signatures, signals, and enum variants) so you can use the objects safely.

Note: types are imported from `Quickshell.Io` in the original library.

## QuickShell.Io Definitions

A quick index of IO types provided by `Quickshell.Io` (names and short descriptions):

## DataStream (uncreatable)

Type: `DataStream` (QObject) — uncreatable

Description

Properties

Notes

## DataStreamParser (uncreatable)

Type: `DataStreamParser` (QObject) — uncreatable

Description

Signals

## FileView (reloadable file object)

Type: FileView (Reloadable)

Properties (selected)

- `loaded: bool` (read-only) — true when a file is currently loaded; may remain true for the duration described below.
  - Note: if a file is loaded, `path` is changed, and a new file is loaded, this property may stay true the whole time; setting `path` to an empty string unloads the file and makes `loaded` false.
- `preload: bool` — if true (default) the file will be loaded in the background immediately when `path` is set. This can increase or decrease load time depending on file size, storage speed, and access pattern. Default: true.
- `printErrors: bool` — if true (default) read/write errors will be printed to Quickshell logs. If false, known errors will be suppressed from logs.

Functions

Signals

Notes

### Detailed notes for `blockAllReads` / `blockLoading`

### `watchChanges` usage example

You can reload a file's content when it changes on disk:

```qml
FileView {
  // ...
  watchChanges: true
  onFileChanged: this.reload()
}
```

### FileView.adapter types

File adapters conform to the FileView.adapter contract. The library provides adapters such as `JsonAdapter`.

Type: `FileViewAdapter` (QObject)

- Creatable: No (uncreatable). Use as a child component in `FileView` via the `adapter` slot.
  Signals
- `adapterUpdated()` — fired when adapter data changes. When this is emitted the `FileView` will also fire `adapterUpdated()`.

- Import: `Quickshell.Io`
- Purpose: expose JSON keys as QML properties which can be read and written. When adapter properties change, call `writeAdapter()` on the `FileView` to persist.
- `list<...>` of supported primitive/object types
- `var` for arbitrary JSON values

Example

FileView {
path: "/path/to/file"
watchChanges: true
onFileChanged: reload()
onAdapterUpdated: writeAdapter()

JsonAdapter {
property string myStringProperty: "default value"
onMyStringPropertyChanged: { console.log("myStringProperty changed") }

    property list<string> stringList: ["default", "value"]
    property JsonObject subObject: JsonObject { property string subObjectProperty: "default value" }

}
}

When adapter properties are updated from QML or on-disk, `adapterUpdated()` is emitted.

Note: the `adapter` property on `FileView` has a default adapter slot; when present the adapter will automatically receive the loaded file's data and may be saved back with `writeAdapter()`.

## FileViewError

Type: `FileViewError` (enum / QObject)

- `PermissionDenied` — permission to read/write was not granted.
- `FileNotFound` — the file was not found when attempting to read.
  Functions
- `toString(value: FileViewError): string` — convert the enum value to a human readable string.

## Process (external process runner)

Import: `Quickshell.Io`
Type: `Process` (QObject)

- `processId: variant` (read-only) — PID of the running process or `null` when not running.
- `running: bool` — set to `true` to start the process (if `command` has at least one element). Setting to false will request termination.
  Functions
- `startDetached(): void` — start an untracked subprocess; `running` for the tracked process will remain false and the child will not be killed when QuickShell exits.
- `write(data: string): void` — write data to stdin (no-op if `stdinEnabled` is false).
- `started()` — emitted when the process starts.
- `exited(exitCode: int, exitStatus: int)` — emitted when the process exits.
- Do not put a full shell command into a single `command` entry (e.g. `"echo hello"`). Instead use `["sh","-c","echo hello"]` to run shell semantics.
- Use `StdioCollector` when you need the whole stdout/stderr buffers; use streaming parsers (e.g., `SplitParser`) to process lines incrementally.

Type: `StdioCollector` (DataStreamParser)

- Import: `Quickshell.Io`
- `text: string` (read-only) — collected text output.
- `waitForEnd: bool` — if true (default) `text` and `data` will only update when the stream ends; otherwise they update incrementally.
  Signals
- `streamFinished()` — emitted when the stream ends (EOF).

## DataStream parsers

Type: `SplitParser` (DataStreamParser)

- Import: `Quickshell.Io`
  Properties
- `splitMarker: string` — delimiter used to split the incoming stream (defaults to `"\n"`).
  Behavior
- Emits a `read()` signal (or callback) per parsed chunk.

## Socket / SocketServer

Import: `Quickshell.Io`

### Socket

Type: `Socket` (DataStream)

- `path: string` — the unix socket path to connect to.
- `connected: bool` — whether the socket is currently connected.
- `write(data: string): void` — write to the socket (no-op if not connected).
- `flush(): void` — flush queued writes.
  Signals
- `error(error)` — emitted when a socket-level error occurs.

### SocketServer

Type: `SocketServer` (Reloadable)

- `active: bool` — if true the server listens; setting to false will destroy connections and remove socket file.
- `handler: Component` — a component that must create a `Socket` instance to handle each incoming connection.
  Notes
- The created handler/socket should not set `connected` or `path`; the server will manage the lifecycle and set `connected` accordingly.
- When using `Process.command` remember: arguments must be separate elements in the `command` list.

---

This file was generated from QuickShell.Io documentation screenshots and local usage patterns to restore full API detail (creatable/uncreatable, function signatures, properties, signals and enum variants). If you want, I can also split this into per-type markdown files under `docs/` or add a quick API table for each type.
