pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io

Singleton {
    id: fsService

    property bool ready: true // Always ready unless doing init checks

    // === Private callback storage (JS variables, not QML properties) ===
    QtObject {
        id: _cbStore
        property var jsonRead: null
        property var jsonWrite: null
        property var textRead: null
    }

    // === JSON Reader ===
    Process {
        id: jsonReader
        stdout: StdioCollector {
            onStreamFinished: {
                fsService._handleJsonRead(text);
            }
        }
    }

    // === JSON Writer ===
    Process {
        id: jsonWriter
        onExited: {
            fsService._handleJsonWrite(true);
        }
    }

    // === Text Reader ===
    Process {
        id: textReader
        stdout: StdioCollector {
            onStreamFinished: {
                fsService._handleTextRead(text);
            }
        }
    }

    // === Public API ===
    function readJson(path, callback) {
        _cbStore.jsonRead = callback;
        jsonReader.command = ["sh", "-c", `cat "${path}" 2>/dev/null`];
        jsonReader.running = true;
    }

    function writeJson(path, data, callback) {
        _cbStore.jsonWrite = callback;
        var jsonString = JSON.stringify(data, null, 2);
        jsonWriter.command = ["sh", "-c", `echo '${jsonString}' > "${path}"`];
        jsonWriter.running = true;
    }

    function readText(path, callback) {
        _cbStore.textRead = callback;
        textReader.command = ["sh", "-c", `cat "${path}" 2>/dev/null`];
        textReader.running = true;
    }

    // === Internal Handlers ===
    function _handleJsonRead(rawText) {
        if (_cbStore.jsonRead) {
            try {
                _cbStore.jsonRead(rawText ? JSON.parse(rawText) : null);
            } catch (e) {
                console.error("[FileSystemService] JSON parse error:", e);
                _cbStore.jsonRead(null);
            }
            _cbStore.jsonRead = null;
        }
    }

    function _handleJsonWrite(success) {
        if (_cbStore.jsonWrite) {
            _cbStore.jsonWrite(success);
            _cbStore.jsonWrite = null;
        }
    }

    function _handleTextRead(text) {
        if (_cbStore.textRead) {
            _cbStore.textRead(text);
            _cbStore.textRead = null;
        }
    }
}
