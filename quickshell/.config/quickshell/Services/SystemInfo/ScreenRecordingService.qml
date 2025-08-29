pragma Singleton
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
  property int frameRate: 60
  property bool isPaused: false
  property bool isRecording: false
  property string monitor: WorkspaceService.focusedOutput
  property string outputPath: ""
  property string quality: "very_high"
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
    args.push("-f", String(frameRate), "-a", audioSource, "-o", outputPath);
    args.push("-k", videoCodec);
    args.push("-ac", audioCodec);
    args.push("-q", quality);
    args.push("-cursor", "no");
    args.push("-cr", colorRange);
    Logger.log("ScreenRecorder", "Exec:", args.join(" "));
    Quickshell.execDetached(args);
    isRecording = true;
    isPaused = false;
    recordingStarted(outputPath);
  }
  function stopRecording() {
    if (!isRecording)
      return;

    Logger.log("ScreenRecorder", "Stopping recording");
    Quickshell.execDetached(["pkill", "-SIGINT", "-f", "gpu-screen-recorder"]);
    isRecording = false;
    isPaused = false;
    recordingStopped(outputPath);
  }
  function togglePause() {
    if (!isRecording)
      return;

    Quickshell.execDetached(["pkill", "-SIGUSR2", "-f", "gpu-screen-recorder"]);
    if (isPaused) {
      Logger.log("ScreenRecorder", "Resumed recording");
      isPaused = false;
      recordingResumed(outputPath);
    } else {
      Logger.log("ScreenRecorder", "Paused recording");
      isPaused = true;
      recordingPaused(outputPath);
    }
  }
  function toggleRecording() {
    isRecording ? stopRecording() : startRecording();
  }
}
