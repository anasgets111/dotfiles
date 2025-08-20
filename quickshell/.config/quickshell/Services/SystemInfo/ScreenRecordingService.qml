pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
    id: root

    property QtObject settings: QtObject {
        property string directory: "~/Videos"
        property int frameRate: 60
        property string audioCodec: "opus"
        property string videoCodec: "h264"
        property string quality: "very_high"
        property string colorRange: "limited"
        property bool showCursor: true
        property string audioSource: "default_output"
    }
    property bool isRecording: false
    property string outputPath: ""

    // Start or Stop recording
    function toggleRecording() {
        isRecording ? stopRecording() : startRecording();
    }

    // Start screen recording using Quickshell.execDetached
    function startRecording() {
        if (isRecording) {
            return;
        }
        isRecording = true;

        var filename = TimeService.getFormattedTimestamp() + ".mp4";
        var videoDir = settings.directory;
        if (videoDir && !videoDir.endsWith("/")) {
            videoDir += "/";
        }
        outputPath = videoDir + filename;
        var command = "gpu-screen-recorder -w portal" + " -f " + settings.frameRate + " -ac " + settings.audioCodec + " -k " + settings.videoCodec + " -a " + settings.audioSource + " -q " + settings.quality + " -cursor " + (settings.showCursor ? "yes" : "no") + " -cr " + settings.colorRange + " -o " + outputPath;
        //Logger.log("ScreenRecorder", command)
        Quickshell.execDetached(["sh", "-c", command]);
        Logger.log("ScreenRecorder", "Started recording");
    }

    // Stop recording using Quickshell.execDetached
    function stopRecording() {
        if (!isRecording) {
            return;
        }

        Quickshell.execDetached(["sh", "-c", "pkill -SIGINT -f 'gpu-screen-recor'"]);
        Logger.log("ScreenRecorder", "Finished recording:", outputPath);

        // Just in case, force kill after 3 seconds
        killTimer.running = true;
        isRecording = false;
    }

    Timer {
        id: killTimer
        interval: 3000
        running: false
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["sh", "-c", "pkill -9 -f 'gpu-screen-recor' 2>/dev/null || true"]);
        }
    }
}
