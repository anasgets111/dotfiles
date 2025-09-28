pragma Singleton
import QtQuick
import Qt.labs.platform
import Quickshell
import qs.Services.SystemInfo
import qs.Services.Utils
import qs.Services.WM

Singleton {
  id: screenRecorder

  property string audioCodec: "opus"
  property string audioSource: "default_output"
  property string colorRange: "limited"
  property string directory: StandardPaths.writableLocation(StandardPaths.MoviesLocation)
  property int frameRate: 30
  property bool isPaused: false
  property bool isRecording: false
  readonly property string lockPath: Quickshell.statePath("screen-recording.lock")
  property string monitor: WorkspaceService.focusedOutput
  property string outputPath: ""
  property string quality: "high"
  property bool showCursor: true
  property string videoCodec: "hevc"

  signal recordingPaused(string path)
  signal recordingResumed(string path)
  signal recordingStarted(string path)
  signal recordingStopped(string path)

  function _syncPersist() {
    persist.wasRecording = isRecording;
    persist.wasPaused = isPaused;
    persist.lastOutputPath = outputPath;
  }
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
    args.push("-cursor", "no");
    args.push("-cr", colorRange);
    Logger.log("ScreenRecorder", "Exec:", args.join(" "));
    Quickshell.execDetached(args);
    isRecording = true;
    isPaused = false;
    Quickshell.execDetached(["sh", "-c", `: > "${screenRecorder.lockPath}"`]);
    _syncPersist();
    recordingStarted(outputPath);
  }
  function stopRecording() {
    if (!isRecording)
      return;

    Quickshell.execDetached(["pkill", "-SIGINT", "-f", "gpu-screen-recorder"]);
    isRecording = false;
    isPaused = false;
    Quickshell.execDetached(["rm", "-f", screenRecorder.lockPath]);
    _syncPersist();
    recordingStopped(outputPath);
  }
  function togglePause() {
    if (!isRecording)
      return;

    Quickshell.execDetached(["pkill", "-SIGUSR2", "-f", "gpu-screen-recorder"]);
    if (isPaused) {
      isPaused = false;
      _syncPersist();
      recordingResumed(outputPath);
    } else {
      isPaused = true;
      _syncPersist();
      recordingPaused(outputPath);
    }
  }
  function toggleRecording() {
    isRecording ? stopRecording() : startRecording();
  }

  PersistentProperties {
    id: persist

    property string lastOutputPath: ""
    property bool wasPaused: false

    // Properties saved/restored across reloads
    property bool wasRecording: false

    reloadableId: "ScreenRecordingServiceState"

    onLoaded: {
      const script = `([ -e "${screenRecorder.lockPath}" ] && echo lock=yes || echo lock=no); (pgrep -f '^gpu-screen-recorder( |$)' >/dev/null && echo proc=yes || echo proc=no)`;
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
        _syncPersist();
      }, screenRecorder);
    }
  }
}
