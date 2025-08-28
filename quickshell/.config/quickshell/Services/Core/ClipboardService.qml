pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: clipLite

  property int _ignoreNextChanges: 0 // ignore N subsequent watcher events caused by our own persist

  // Internal
  property bool _isColdStart: true
  property bool _isFetching: false
  property string _selectedPersistMime: ""
  property string _selectedTextMime: ""

  // Public state
  property bool enabled: true

  // Persisted text history (text/* only)
  property var history: [] // [{ mime, content, ts }]
  property var lastPersisted: null // { mime, ts }

  property int maxItems: 20 // number of text items to retain

  readonly property bool ready: !clipLite._isColdStart

  signal changed
  signal textItemAdded(var entry)

  function _appendTextHistory(mime, content) {
    const now = Date.now();
    const head = clipLite.history.length ? clipLite.history[0] : null;
    if (head && head.mime === mime && head.content === content)
      return;
    const entry = {
      mime: mime,
      content: String(content || ""),
      ts: now
    };
    clipLite.history = [entry, ...clipLite.history].slice(0, clipLite.maxItems);
    _saveTextHistory();
    clipLite.textItemAdded(entry);
    clipLite.changed();
  }

  function _finishFetchCycle() {
    clipLite._isFetching = false;
    if (clipLite._isColdStart)
      clipLite._isColdStart = false;
  }

  function _loadTextHistory() {
    try {
      const arr = JSON.parse(store.textHistoryJson || "[]");
      if (Array.isArray(arr)) {
        clipLite.history = arr;
      } else {
        clipLite.history = [];
      }
    } catch (e) {
      clipLite.history = [];
      store.textHistoryJson = "[]";
    }
  }

  function _pickPersistMime(types) {
    // Persist any image/* as-is; otherwise use preferred text; else first available
    for (let i = 0; i < types.length; i++) {
      const t = String(types[i] || "");
      if (t.indexOf("image/") === 0)
        return t;
    }
    const text = _pickPreferredTextMime(types);
    if (text)
      return text;
    return types.length ? String(types[0]) : "";
  }

  // Helpers
  function _pickPreferredTextMime(types) {
    // Prefer richer text formats if available
    const prefs = ["text/html", "text/markdown", "text/md", "text/plain;charset=utf-8", "text/plain", "text"];
    for (let i = 0; i < prefs.length; i++) {
      if (types.indexOf(prefs[i]) !== -1)
        return prefs[i];
    }
    for (let j = 0; j < types.length; j++) {
      const t = String(types[j] || "");
      if (t.indexOf("text/") === 0)
        return t;
    }
    return "";
  }

  function _saveTextHistory() {
    try {
      store.textHistoryJson = JSON.stringify(clipLite.history);
    } catch (e)
    // ignore
    {}
  }

  function _startFetchCycle() {
    if (!clipLite.enabled || clipLite._isFetching)
      return;
    clipLite._isFetching = true;
    clipLite._selectedTextMime = "";
    clipLite._selectedPersistMime = "";
    typeDetectionProcess.command = ["wl-paste", "-l"];
    typeDetectionProcess.running = true;
  }

  function _startPersist(mime) {
    if (!mime)
      return;
    // Pipe wl-paste -> wl-copy for the chosen mime to keep rich formatting
    persistProcess.command = ["sh", "-c", "mime='" + mime + "'; wl-paste -n -t \"$mime\" | wl-copy -t \"$mime\""];
    // Ignore the next change notification that results from wl-copy taking ownership
    clipLite._ignoreNextChanges = Math.max(clipLite._ignoreNextChanges, 1);
    persistProcess.running = true;
  }

  // Public API
  function clear() {
    clipLite.history = [];
    _saveTextHistory();
    clipLite.changed();
  }

  function refresh() {
    clipLite._startFetchCycle();
  }

  // Init
  Component.onCompleted: {
    _loadTextHistory();
    if (clipLite.enabled) {
      watcher.running = true;
      clipLite._startFetchCycle();
    }
  }
  onEnabledChanged: {
    if (clipLite.enabled) {
      watcher.running = true;
      clipLite._startFetchCycle();
    } else {
      watcher.running = false;
    }
  }

  PersistentProperties {
    id: store

    property string textHistoryJson: "[]"

    reloadableId: "ClipboardLiteService"
  }

  // Watcher for clipboard changes
  Process {
    id: watcher

    command: ["wl-paste", "--watch", "printf", "CHANGE\n"]

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: function (_) {
        if (!clipLite.enabled)
          return;
        if (clipLite._ignoreNextChanges > 0 && persistProcess.running) {
          clipLite._ignoreNextChanges = Math.max(0, clipLite._ignoreNextChanges - 1);
          return; // ignore our own persist-induced change(s)
        } else if (clipLite._ignoreNextChanges > 0 && !persistProcess.running) {
          // Persist already finished; clear leftover ignore budget
          clipLite._ignoreNextChanges = 0;
        }
        clipLite._startFetchCycle();
      }
    }

    onRunningChanged: Logger.log("ClipboardLiteService", `Watcher running=${watcher.running}`)
  }

  // Detect available MIME types
  Process {
    id: typeDetectionProcess

    stdout: StdioCollector {
      id: typeOut

      onStreamFinished: {
        const out = String(typeOut.text || "").trim();
        const types = out ? out.split(/\n+/).filter(t => !!t) : [];
        Logger.log("ClipboardLiteService", `Types: ${types.join(", ")}`);

        // Choose what to persist and which text mime (if any) to record
        clipLite._selectedPersistMime = clipLite._pickPersistMime(types);
        clipLite._selectedTextMime = clipLite._pickPreferredTextMime(types);

        if (clipLite._selectedTextMime) {
          textFetchProcess.mime = clipLite._selectedTextMime;
          textFetchProcess.command = ["wl-paste", "-n", "-t", clipLite._selectedTextMime];
          textFetchProcess.running = true;
        }

        if (clipLite._selectedPersistMime) {
          clipLite._startPersist(clipLite._selectedPersistMime);
        }

        if (!clipLite._selectedTextMime) {
          // No text to fetch; finish now
          clipLite._finishFetchCycle();
        }
      }
    }
  }

  // Fetch text content for history
  Process {
    id: textFetchProcess

    property string mime: ""

    stdout: StdioCollector {
      id: textOut

      onStreamFinished: {
        const content = String(textOut.text || "");
        if (content.length)
          clipLite._appendTextHistory(textFetchProcess.mime, content);
        clipLite._finishFetchCycle();
      }
    }
  }

  // Persistence pipeline
  Process {
    id: persistProcess

    onRunningChanged: {
      if (!persistProcess.running) {
        clipLite.lastPersisted = {
          mime: clipLite._selectedPersistMime,
          ts: Date.now()
        };
        Logger.log("ClipboardLiteService", `Persist done: ${clipLite._selectedPersistMime}`);
        // Ensure we don't accidentally swallow the next real change
        clipLite._ignoreNextChanges = 0;
      }
    }
  }
}
