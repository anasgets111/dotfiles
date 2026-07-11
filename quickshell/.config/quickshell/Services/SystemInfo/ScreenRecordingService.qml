pragma Singleton
import Qt.labs.platform
import QtQuick
import Quickshell
import qs.Services.SystemInfo
import qs.Services.Utils
import qs.Services.WM

Singleton {
  id: root

  readonly property string directory: String(StandardPaths.writableLocation(StandardPaths.MoviesLocation)).replace(/^file:\/\//, "")
  property bool isPaused: false
  property bool isRecording: false
  readonly property string lockPath: Quickshell.statePath("screen-recording.lock")
  property string monitor: WorkspaceService.focusedOutput
  property string outputPath: ""

  signal recordingPaused(string path)
  signal recordingResumed(string path)
  signal recordingStarted(string path)
  signal recordingStopped(string path)

  function startRecording(mode = "default") {
    if (isRecording)
      return;
    if (mode === "selection") {
      Command.run(["slurp", "-f", "%wx%h+%x+%y"], result => {
        const region = (result.stdout ?? "").trim();
        if (root.isRecording || result.exitCode !== 0 || !region)
          return;
        root._launchRecorder(["-w", "region", "-region", region]);
      });
      return;
    }
    _launchRecorder(["-w", monitor]);
  }

  function _launchRecorder(captureArgs) {
    const filename = TimeService.format("datetime", "yyyyMMdd_HHmmss") + ".mp4";
    const dir = directory.endsWith("/") ? directory : directory + "/";
    outputPath = dir + filename;
    Command.detached(["gpu-screen-recorder", ...captureArgs, "-o", outputPath, "-a", "default_output", "-cursor", "yes"]);
    Command.detached(["touch", root.lockPath]);

    isRecording = true;
    isPaused = false;
    syncPersist();
    recordingStarted(outputPath);
  }

  function stopRecording() {
    if (!isRecording)
      return;
    Command.detached(["pkill", "-SIGINT", "-f", "gpu-screen-recorder"]);
    Command.detached(["rm", "-f", root.lockPath]);
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
    Command.detached(["pkill", "-SIGUSR2", "-f", "gpu-screen-recorder"]);
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

    onLoaded: Command.run(["sh", "-c", `([ -e "${root.lockPath}" ] && echo lock=yes || echo lock=no); (pgrep -f '^gpu-screen-recorder( |$)' >/dev/null && echo proc=yes || echo proc=no)`], result => {
      const active = /lock=yes/.test(result.stdout) || /proc=yes/.test(result.stdout);
      if (active) {
        root.isRecording = true;
        root.isPaused = !!persist.wasPaused;
        if (persist.lastOutputPath)
          root.outputPath = persist.lastOutputPath;
      } else {
        root.isRecording = false;
        root.isPaused = false;
      }
      root.syncPersist();
    })
  }
}
