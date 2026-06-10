pragma Singleton
import Qt.labs.platform
import QtQuick
import Quickshell
import qs.Services.SystemInfo
import qs.Services.Utils
import qs.Services.WM

Singleton {
  id: root

  property string audioCodec: ""
  property string audioSource: "default_output"
  property string colorRange: ""
  readonly property string directory: String(StandardPaths.writableLocation(StandardPaths.MoviesLocation)).replace(/^file:\/\//, "")
  property int frameRate: 0
  property bool isPaused: false
  property bool isRecording: false
  readonly property string lockPath: Quickshell.statePath("screen-recording.lock")
  property string monitor: WorkspaceService.focusedOutput
  property string outputPath: ""
  property string quality: ""
  property bool recordAudio: true
  property bool showCursor: true
  property string videoCodec: ""

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
    const args = ["gpu-screen-recorder", ...captureArgs];
    if (frameRate > 0)
      args.push("-f", String(frameRate));
    args.push("-o", outputPath);
    if (videoCodec)
      args.push("-k", videoCodec);
    if (recordAudio && audioSource) {
      args.push("-a", audioSource);
      if (audioCodec)
        args.push("-ac", audioCodec);
    }
    if (quality)
      args.push("-q", quality);
    args.push("-cursor", showCursor ? "yes" : "no");
    if (colorRange)
      args.push("-cr", colorRange);

    Command.detached(args);
    Command.detached(["sh", "-c", `: > "${root.lockPath}"`]);

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
