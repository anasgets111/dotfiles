pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: fileSystemService

    property bool ready: false

    // File loader
    FileView {
        id: fileReader
    }

    // === Read text file ===
    function readFile(path) {
        fileReader.url = "file://" + path;
        return fileReader.text || "";
    }

    // === Read JSON file ===
    function readJson(path) {
        const raw = fileSystemService.readFile(path);
        if (!raw) {
            console.warn("[FileSystemService] JSON file not found or empty:", path);
            return {};
        }
        try {
            return JSON.parse(raw);
        } catch (e) {
            console.error("[FileSystemService] Failed to parse JSON:", e);
            return {};
        }
    }

    // === Write file (via Process) ===
    Process {
        id: writeProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    console.error("[FileSystemService] Write error:", text.trim());
                }
            }
        }
    }

    function writeFile(path, data) {
        const strData = String(data); // ensure it's a string
        const safeData = strData.replace(/'/g, "'\\''");
        writeProc.command = ["sh", "-c", "printf '%s' '" + safeData + "' > '" + path + "'"];
        writeProc.running = true;
    }

    Component.onCompleted: {
        fileSystemService.ready = true;
        console.log("[FileSystemService] Ready");
    }
}
