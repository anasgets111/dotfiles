pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: root

  property bool enabled: true
  property list<var> history: []
  property int ignoreNextChanges: 0
  property bool isColdStart: true
  property bool isFetching: false
  property var lastPersisted: null
  property int maxItems: 20
  readonly property list<string> preferredTextMimes: ["text/html", "text/markdown", "text/md", "text/plain;charset=utf-8", "text/plain", "text"]
  readonly property bool ready: !root.isColdStart
  property string selectedPersistMime: ""
  property string selectedTextMime: ""

  signal changed
  signal textItemAdded(var entry)

  function appendTextHistory(mime, content) {
    const head = root.history[0];
    if (head?.mime === mime && head?.content === content)
      return;
    const entry = {
      mime,
      content: String(content ?? ""),
      ts: Date.now()
    };
    root.history = [entry, ...root.history].slice(0, root.maxItems);
    root.saveTextHistory();
    root.textItemAdded(entry);
    root.changed();
  }

  function clear() {
    root.history = [];
    root.saveTextHistory();
    root.changed();
  }

  function finishFetchCycle() {
    root.isFetching = false;
    if (root.isColdStart)
      root.isColdStart = false;
  }

  function loadTextHistory() {
    try {
      const arr = JSON.parse(store.textHistoryJson || "[]");
      root.history = Array.isArray(arr) ? arr : [];
    } catch (e) {
      root.history = [];
      store.textHistoryJson = "[]";
    }
  }

  function pickPersistMime(types) {
    for (const t of types) {
      if (String(t ?? "").startsWith("image/"))
        return t;
    }
    const text = root.pickPreferredTextMime(types);
    return text || (types.length ? String(types[0]) : "");
  }

  function pickPreferredTextMime(types) {
    for (const pref of root.preferredTextMimes) {
      if (types.includes(pref))
        return pref;
    }
    for (const t of types) {
      if (String(t ?? "").startsWith("text/"))
        return t;
    }
    return "";
  }

  function refresh() {
    root.startFetchCycle();
  }

  function saveTextHistory() {
    try {
      store.textHistoryJson = JSON.stringify(root.history);
    } catch (e) {}
  }

  function startFetchCycle() {
    if (!root.enabled || root.isFetching)
      return;
    root.isFetching = true;
    root.selectedTextMime = "";
    root.selectedPersistMime = "";
    typeDetectionProcess.command = ["wl-paste", "-l"];
    typeDetectionProcess.running = true;
  }

  function startPersist(mime) {
    if (!mime)
      return;
    persistProcess.command = ["sh", "-c", `mime='${mime}'; wl-paste -n -t "$mime" | wl-copy -t "$mime"`];
    root.ignoreNextChanges = Math.max(root.ignoreNextChanges, 1);
    persistProcess.running = true;
  }

  Component.onCompleted: {
    root.loadTextHistory();
    if (root.enabled) {
      watcher.running = true;
      root.startFetchCycle();
    }
  }
  onEnabledChanged: {
    watcher.running = root.enabled;
    if (root.enabled)
      root.startFetchCycle();
  }

  PersistentProperties {
    id: store

    property string textHistoryJson: "[]"

    reloadableId: "ClipboardLiteService"
  }

  Process {
    id: watcher

    command: ["wl-paste", "--watch", "printf", "CHANGE\n"]

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: function (_) {
        if (!root.enabled)
          return;
        if (root.ignoreNextChanges > 0 && persistProcess.running) {
          root.ignoreNextChanges = Math.max(0, root.ignoreNextChanges - 1);
          return;
        } else if (root.ignoreNextChanges > 0) {
          root.ignoreNextChanges = 0;
        }
        root.startFetchCycle();
      }
    }

    onRunningChanged: Logger.log("ClipboardLiteService", `Watcher running=${watcher.running}`)
  }

  Process {
    id: typeDetectionProcess

    stdout: StdioCollector {
      id: typeOut

      onStreamFinished: {
        const types = String(typeOut.text ?? "").trim().split(/\n+/).filter(t => !!t);
        Logger.log("ClipboardLiteService", `Types: ${types.join(", ")}`);

        root.selectedPersistMime = root.pickPersistMime(types);
        root.selectedTextMime = root.pickPreferredTextMime(types);

        if (root.selectedTextMime) {
          textFetchProcess.mime = root.selectedTextMime;
          textFetchProcess.command = ["wl-paste", "-n", "-t", root.selectedTextMime];
          textFetchProcess.running = true;
        }

        if (root.selectedPersistMime)
          root.startPersist(root.selectedPersistMime);
        if (!root.selectedTextMime)
          root.finishFetchCycle();
      }
    }
  }

  Process {
    id: textFetchProcess

    property string mime: ""

    stdout: StdioCollector {
      id: textOut

      onStreamFinished: {
        const content = String(textOut.text ?? "");
        if (content.length)
          root.appendTextHistory(textFetchProcess.mime, content);
        root.finishFetchCycle();
      }
    }
  }

  Process {
    id: persistProcess

    onRunningChanged: {
      if (!persistProcess.running) {
        root.lastPersisted = {
          mime: root.selectedPersistMime,
          ts: Date.now()
        };
        Logger.log("ClipboardLiteService", `Persist done: ${root.selectedPersistMime}`);
        root.ignoreNextChanges = 0;
      }
    }
  }
}
