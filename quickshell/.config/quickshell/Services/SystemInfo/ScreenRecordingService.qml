pragma Singleton
import QtQuick
import Quickshell
import qs.Services.Utils
import qs.Services.SystemInfo
import qs.Services.WM

Singleton {
    id: screenRecorder

    signal recordingStarted(string path)
    signal recordingStopped(string path)

    readonly property var settings: QtObject {
        // Expand ~ properly
        property string directory: "~/Videos"
        property int frameRate: 60
        property string audioCodec: "opus"
        property string videoCodec: "h264"
        property string quality: "very_high"
        property string colorRange: "limited"
        property bool showCursor: true
        property string audioSource: "default_output"
        property string monitor: WorkspaceService.focusedOutput
    }
    property bool isRecording: false
    property string outputPath: ""
    function toggleRecording() {
        isRecording ? stopRecording() : startRecording();
    }

    function startRecording() {
        if (isRecording)
            return;
        Logger.log("ScreenRecorder", "Current Monitor:", settings.monitor);
        const filename = TimeService.format("datetime", "yyyyMMdd_HHmmss") + ".mp4";
        const dir = settings.directory.endsWith("/") ? settings.directory : settings.directory + "/";
        outputPath = dir + filename;

        const args = ["gpu-screen-recorder", "-w", settings.monitor, "-f", settings.frameRate, "-ac", settings.audioCodec, "-k", settings.videoCodec, "-a", settings.audioSource, "-q", settings.quality, "-cursor", settings.showCursor ? "yes" : "no", "-cr", settings.colorRange, "-o", outputPath];

        Quickshell.execDetached(args);

        isRecording = true;
        Logger.log("ScreenRecorder", "Started recording:", outputPath);
        recordingStarted(outputPath);
    }

    function stopRecording() {
        if (!isRecording)
            return;

        Quickshell.execDetached(["pkill", "-SIGINT", "-f", "gpu-screen-recorder"]);
        Logger.log("ScreenRecorder", "Stopping recording");
        isRecording = false;
        recordingStopped(outputPath);

        // Just in case, force kill after 3s
        killTimer.running = true;
    }

    Timer {
        id: killTimer
        interval: 3000
        running: false
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["pkill", "-9", "-f", "gpu-screen-recorder"]);
            Logger.log("ScreenRecorder", "Force killed (fallback pkill)");
            if (!screenRecorder.isRecording)
                screenRecorder.recordingStopped(screenRecorder.outputPath);
        }
    }
}
