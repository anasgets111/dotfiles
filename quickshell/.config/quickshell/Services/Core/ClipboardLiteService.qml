pragma Singleton
import QtQml
import QtQuick
import Quickshell
import qs.Services.Utils

// Minimal clipboard service that talks only to cliphist.
// No wl-copy/wl-paste usage, no watchers, no persistence in here.
// Async API via callbacks to keep it lightweight.
Singleton {
  id: cliphistSvc

  property bool _availabilityChecked: false
  property bool _available: false
  readonly property bool available: _available
  // Lifecycle
  readonly property bool ready: _availabilityChecked

  signal changed

  // Utilities
  function _ensureAvail() {
    if (!cliphistSvc._availabilityChecked)
      Logger.warn("ClipboardLiteService", "Availability not checked yet");

    if (!cliphistSvc._available)
      Logger.warn("ClipboardLiteService", "cliphist not available");

    return cliphistSvc._available;
  }

  // Internal: paste using wtype (Ctrl+V). cb(successBool)
  function _pasteFocused(cb) {
    // Press Ctrl+V and release Ctrl: -M ctrl (press), -k v (key), -m ctrl (release)
    Utils.runCmd(["sh", "-c", "(wtype -M ctrl -k v -m ctrl && echo OK) || echo FAIL"], function (out) {
      Logger.log("ClipboardLiteService", "paste result:", String(out || "").trim());
      if (cb) {
        try {
          cb(String(out || "").indexOf("OK") !== -1);
        } catch (e) {}
      }
    }, cliphistSvc);
  }

  // Public: refresh availability (runs once on startup automatically)
  function checkAvailable(cb) {
    Utils.runCmd(["sh", "-c", "command -v cliphist >/dev/null && echo yes || echo no"], function (out) {
      const ok = String(out || "").trim() === "yes";
      cliphistSvc._available = ok;
      cliphistSvc._availabilityChecked = true;
      Logger.log("ClipboardLiteService", `available=${ok}`);
      if (cb) {
        try {
          cb(ok);
        } catch (e) {}
      }
    }, cliphistSvc);
  }

  // Convenience: copy from list line, then paste after delayMs (default 200). cb(successBool)
  function copyAndPasteFromLine(line, opts, cb) {
    const delayMs = Number(opts && opts.delayMs) > 0 ? Number(opts.delayMs) : 200;
    const primary = !!(opts && opts.primary);
    Logger.log("ClipboardLiteService", `copyAndPasteFromLine delayMs=${delayMs} primary=${primary}`);
    cliphistSvc.copyFromLine(line, {
      "primary": primary
    }, function (ok) {
      if (!ok) {
        if (cb) {
          try {
            cb(false);
          } catch (e) {}
        }
        return;
      }
      _pasteTimer.interval = delayMs;
      _pasteTimer._cb = cb || null;
      _pasteTimer.restart();
    });
  }

  // --- Backend helpers to keep UI minimal ---
  // Copy selected list line content into clipboard (and optionally primary). cb(successBool)
  function copyFromLine(line, opts, cb) {
    if (!cliphistSvc._ensureAvail()) {
      if (cb)
        cb(false);

      return;
    }
    const primary = !!(opts && opts.primary);
    const l = String(line || "");
    Logger.log("ClipboardLiteService", "copyFromLine start; preview=", Utils.stripAnsi(l).slice(0, 120));
    const base = Utils.shCommand('line="$1"; printf "%s\n" "$line" | cliphist decode | wl-copy', [l]);
    Utils.runCmd(base, function () {
      Utils.runCmd(["sh", "-c", "wl-paste -n | head -c 80 | wc -c"], function (n) {
        Logger.log("ClipboardLiteService", "copy clipboard bytes=", String(n || "").trim());
      });
      if (primary) {
        const prim = Utils.shCommand('line="$1"; printf "%s\n" "$line" | cliphist decode | wl-copy --primary', [l]);
        Utils.runCmd(prim, function () {
          Utils.runCmd(["sh", "-c", "wl-paste --primary -n | head -c 80 | wc -c"], function (n2) {
            Logger.log("ClipboardLiteService", "copy primary bytes=", String(n2 || "").trim());
          });
          cliphistSvc.changed();
          if (cb) {
            try {
              cb(true);
            } catch (e) {}
          }
        }, cliphistSvc);
      } else {
        cliphistSvc.changed();
        if (cb) {
          try {
            cb(true);
          } catch (e2) {}
        }
      }
    }, cliphistSvc);
  }

  // Decode as base64 (safe for binary). Returns a base64 string (no newlines).
  function decodeBase64FromLine(line, cb) {
    if (!cliphistSvc._ensureAvail()) {
      if (cb)
        cb("");

      return;
    }
    const cmd = Utils.shCommand('line="$1"; printf "%s\n" "$line" | cliphist decode | base64 -w 0', [String(line || "")]);
    Utils.runCmd(cmd, function (text) {
      if (cb) {
        try {
          cb(String(text || "").trim());
        } catch (e) {}
      }
    }, cliphistSvc);
  }

  // Decode by id (best-effort; depends on cliphist accepting id argument). Returns UTF-8 text.
  function decodeById(id, cb) {
    if (!cliphistSvc._ensureAvail()) {
      if (cb)
        cb("");

      return;
    }
    const cmd = ["cliphist", "decode", String(id || "")];
    Utils.runCmd(cmd, function (text) {
      if (cb) {
        try {
          cb(String(text || ""));
        } catch (e) {}
      }
    }, cliphistSvc);
  }

  // Decode from a full list line (preferred; mirrors typical `list | dmenu | decode`).
  // cb receives decoded UTF-8 text. For binary, prefer decodeBase64FromLine.
  function decodeFromLine(line, cb) {
    if (!cliphistSvc._ensureAvail()) {
      if (cb)
        cb("");

      return;
    }
    const cmd = Utils.shCommand('line="$1"; printf "%s\n" "$line" | cliphist decode', [String(line || "")]);
    Utils.runCmd(cmd, function (text) {
      if (cb) {
        try {
          cb(String(text || ""));
        } catch (e) {}
      }
    }, cliphistSvc);
  }

  // Delete by id. cb(successBool)
  function deleteById(id, cb) {
    if (!cliphistSvc._ensureAvail()) {
      if (cb)
        cb(false);

      return;
    }
    Logger.log("ClipboardLiteService", "deleteById start; id=", String(id || ""));
    const cmd = Utils.shCommand('id="$1"; if [ -n "$id" ] && cliphist delete-query "^${id}\\t"; then echo OK; else echo FAIL; fi', [String(id || "")]);
    Utils.runCmd(cmd, function (text) {
      const ok = String(text || "").indexOf("OK") !== -1;
      Logger.log("ClipboardLiteService", "deleteById ->", ok);
      if (ok)
        cliphistSvc.changed();

      if (cb) {
        try {
          cb(ok);
        } catch (e) {}
      }
    }, cliphistSvc);
  }

  // Delete an item using a full list line (mirrors CLI behavior). cb(successBool)
  function deleteFromLine(line, cb) {
    if (!cliphistSvc._ensureAvail()) {
      if (cb)
        cb(false);

      return;
    }
    const raw = String(line || "");
    Logger.log("ClipboardLiteService", "deleteFromLine start; preview=", Utils.stripAnsi(raw).slice(0, 120));
    // Prefer deleting by piping the exact list line. If that fails, fall back to anchored delete-query by id and tab.
    const cmd = Utils.shCommand('line="$1"; id=$(printf "%s\n" "$line" | sed -E "s/^([0-9]+).*/\\1/"); echo "DEL_ID=$id"; if printf "%s\n" "$line" | cliphist delete; then echo OK; elif [ -n "$id" ] && cliphist delete-query "^${id}\\t"; then echo OK; else echo FAIL; fi', [raw]);
    Utils.runCmd(cmd, function (text) {
      const out = String(text || "").trim();
      const ok = out.indexOf("OK") !== -1;
      Logger.log("ClipboardLiteService", "deleteFromLine ->", ok, out);
      if (ok)
        cliphistSvc.changed();

      if (cb) {
        try {
          cb(ok);
        } catch (e) {}
      }
    }, cliphistSvc);
  }

  // Delete by query (exact CLI passthrough). cb(successBool)
  function deleteQuery(query, cb) {
    if (!cliphistSvc._ensureAvail()) {
      if (cb)
        cb(false);

      return;
    }
    const cmd = Utils.shCommand('cliphist delete-query "$1" && echo OK || echo FAIL', [String(query || "")]);
    Utils.runCmd(cmd, function (text) {
      const ok = String(text || "").indexOf("OK") !== -1;
      if (cb) {
        try {
          cb(ok);
        } catch (e) {}
      }
    }, cliphistSvc);
  }

  // List items. Returns array of lines (exactly what `cliphist list` prints) via cb(linesArray)
  function list(cb, limit) {
    if (!cliphistSvc._ensureAvail()) {
      if (cb)
        cb([]);

      return;
    }
    const n = Number(limit || 0);
    const cmd = n > 0 ? Utils.shCommand("cliphist list | head -n \"$1\"", [n]) : ["cliphist", "list"];
    Utils.runCmd(cmd, function (text) {
      const lines = String(text || "").split(/\n+/).filter(l => {
        return l.length > 0;
      });
      if (cb) {
        try {
          cb(lines);
        } catch (e) {}
      }
    }, cliphistSvc);
  }

  // Wipe database. cb(successBool)
  function wipe(cb) {
    if (!cliphistSvc._ensureAvail()) {
      if (cb)
        cb(false);

      return;
    }
    Utils.runCmd(["cliphist", "wipe"], function (text) {
      // cliphist prints nothing on success typically
      Logger.log("ClipboardLiteService", "wipe -> done");
      cliphistSvc.changed();
      if (cb) {
        try {
          cb(true);
        } catch (e) {}
      }
    }, cliphistSvc);
  }

  // Init
  Component.onCompleted: {
    checkAvailable();
  }

  // Timer to delay paste slightly so focus can return to target app
  Timer {
    id: _pasteTimer

    property var _cb: null

    interval: 200
    repeat: false
    onTriggered: {
      cliphistSvc._pasteFocused(function (ok) {
        var fn = _pasteTimer._cb;
        _pasteTimer._cb = null;
        if (fn) {
          try {
            fn(ok);
          } catch (e) {}
        }
      });
    }
  }
}
