pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services as Services // adjust path if needed

Singleton {
    id: configService

    property bool ready: false
    property string configPath: Quickshell.dataPath("config.json")
    property var config: ({}) // in-memory config object

    Component.onCompleted: {
        loadConfig();
        configService.ready = true;
        console.log("[ConfigService] Ready with", Object.keys(configService.config).length, "keys");
    }

    // === Load config from disk ===
    function loadConfig() {
        const obj = Services.FileSystemService.readJson(configService.configPath);
        if (obj && typeof obj === "object") {
            configService.config = obj;
            console.log("[ConfigService] Loaded config from", configService.configPath);
        } else {
            console.warn("[ConfigService] No valid config found, using defaults");
            configService.config = {};
        }
    }

    // === Save config to disk ===
    function saveConfig() {
        try {
            const json = JSON.stringify(configService.config, null, 2);
            Services.FileSystemService.writeFile(configService.configPath, json);
            console.log("[ConfigService] Saved config to", configService.configPath);
        } catch (e) {
            console.error("[ConfigService] Failed to save config:", e);
        }
    }

    // === Get a config value with default ===
    function get(key, defaultValue) {
        return configService.config.hasOwnProperty(key) ? configService.config[key] : defaultValue;
    }

    // === Set a config value and save ===
    function set(key, value) {
        configService.config[key] = value;
        saveConfig();
    }
}
