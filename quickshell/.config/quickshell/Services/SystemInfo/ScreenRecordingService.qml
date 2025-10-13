pragma Singleton
import Qt.labs.platform
import QtQuick
import Quickshell
import qs.Services.SystemInfo
import qs.Services.Utils
import qs.Services.WM

Singleton {
  id: root

  property string audioCodec: "opus"
  property string audioSource: "default_output"
  property string colorRange: "limited"
  readonly property string directory: String(StandardPaths.writableLocation(StandardPaths.MoviesLocation)).replace(/^file:\/\//, "")
  property int frameRate: 24
  property bool isPaused: false
  property bool isRecording: false
  readonly property string lockPath: Quickshell.statePath("screen-recording.lock")
  property string monitor: WorkspaceService.focusedOutput
  property string outputPath: ""
  property string quality: "medium"
  property bool showCursor: true
  property string videoCodec: "h264"

  signal recordingPaused(string path)
  signal recordingResumed(string path)
  signal recordingStarted(string path)
  signal recordingStopped(string path)

  function startRecording() {
    if (isRecording)
      return;
    const filename = TimeService.format("datetime", "yyyyMMdd_HHmmss") + ".mp4";
    const dir = directory.endsWith("/") ? directory : directory + "/";
    outputPath = dir + filename;
    const args = ["gpu-screen-recorder"];
    args.push("-w", monitor);
    args.push("-f", String(frameRate));
    args.push("-o", outputPath);
    args.push("-k", videoCodec);
    // args.push("-a", audioSource);
    // args.push("-ac", audioCodec);
    args.push("-q", quality);
    args.push("-cursor", "yes");
    args.push("-cr", colorRange);
    Logger.log("ScreenRecorder", "Starting:", args.join(" "));
    Quickshell.execDetached(args);
    Quickshell.execDetached(["sh", "-c", `: > "${root.lockPath}"`]);

    isRecording = true;
    isPaused = false;
    syncPersist();
    recordingStarted(outputPath);
  }

  function stopRecording() {
    if (!isRecording)
      return;
    Quickshell.execDetached(["pkill", "-SIGINT", "-f", "gpu-screen-recorder"]);
    Quickshell.execDetached(["rm", "-f", root.lockPath]);
    isRecording = false;
    isPaused = false;
    syncPersist();
    recordingStopped(outputPath);
  }

  function syncPersist() {
    persist.wasRecording = isRecording;
    persist.wasPaused = isPaused;
    persist.lastOutputPath = outputPath;
  }

  function togglePause() {
    if (!isRecording)
      return;
    Quickshell.execDetached(["pkill", "-SIGUSR2", "-f", "gpu-screen-recorder"]);
    isPaused = !isPaused;
    syncPersist();

    if (isPaused)
      recordingPaused(outputPath);
    else
      recordingResumed(outputPath);
  }

  function toggleRecording() {
    isRecording ? stopRecording() : startRecording();
  }

  PersistentProperties {
    id: persist

    property string lastOutputPath: ""
    property bool wasPaused: false
    property bool wasRecording: false

    reloadableId: "ScreenRecordingServiceState"

    onLoaded: {
      const script = `([ -e "${root.lockPath}" ] && echo lock=yes || echo lock=no); (pgrep -f '^gpu-screen-recorder( |$)' >/dev/null && echo proc=yes || echo proc=no)`;
      Utils.runCmd(["sh", "-c", script], function (out) {
        const txt = String(out || "");
        const active = /lock=yes/.test(txt) || /proc=yes/.test(txt);
        if (active) {
          isRecording = true;
          isPaused = !!persist.wasPaused;
          if (persist.lastOutputPath)
            outputPath = persist.lastOutputPath;
        } else {
          isRecording = false;
          isPaused = false;
        }
        syncPersist();
      }, root);
    }
  }
}
