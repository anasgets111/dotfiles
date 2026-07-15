pragma Singleton
import Qt.labs.platform
import QtQuick
import Quickshell
import qs.Services.Utils
import qs.Services.WM

Singleton {
  id: root

  property bool _cleanupInFlight: false
  // Detached recording survives hot reload. PID + kernel start time prevents
  // signalling a recycled PID. ponytail: gpu-screen-recorder must stay foreground;
  // consume a recorder-provided pidfile if it ever starts daemonizing.
  readonly property string _launchScript: 'lock_path="$1"; output_path="$2"; shift 2; "$@" </dev/null >/dev/null 2>&1 & pid=$!; for _ in 1 2 3 4 5 6 7 8 9 10; do exe=$(readlink -f "/proc/$pid/exe" 2>/dev/null || true); [ "${exe##*/}" = gpu-screen-recorder ] && break; kill -0 "$pid" 2>/dev/null || exit 1; sleep 0.02; done; [ "${exe##*/}" = gpu-screen-recorder ] || { kill -TERM "$pid" 2>/dev/null || true; exit 1; }; start_time=$(awk "{print \\$22}" "/proc/$pid/stat" 2>/dev/null); [ -n "$start_time" ] || { kill -INT "$pid" 2>/dev/null || true; exit 1; }; lock_tmp="$lock_path.$$"; { printf "%s\\n%s\\n%s\\n" "$pid" "$start_time" "$output_path" > "$lock_tmp" && mv -f "$lock_tmp" "$lock_path"; } || { rm -f "$lock_tmp"; kill -INT "$pid" 2>/dev/null || true; exit 1; }; printf "%s\\n%s\\n" "$pid" "$start_time" || { rm -f "$lock_path"; kill -INT "$pid" 2>/dev/null || true; exit 1; }'
  readonly property string _probeScript: 'pid="$1"; expected_start="$2"; case "$pid" in ""|*[!0-9]*) exit 2;; esac; current_start=$(awk "{print \\$22}" "/proc/$pid/stat" 2>/dev/null) || exit 3; [ "$current_start" = "$expected_start" ] || exit 4; exe=$(readlink -f "/proc/$pid/exe" 2>/dev/null) || exit 5; [ "${exe##*/}" = gpu-screen-recorder ] || exit 6'
  property int _recorderPid: 0
  property string _recorderStartTime: ""
  property bool _signalInFlight: false
  readonly property string _signalScript: _probeScript + '; kill "-$3" "$1"'
  property bool _starting: false
  readonly property string directory: String(StandardPaths.writableLocation(StandardPaths.MoviesLocation)).replace(/^file:\/\//, "")
  property bool isPaused: false
  property bool isRecording: false
  readonly property string lockPath: Quickshell.statePath("screen-recording.lock")
  property string monitor: WorkspaceService.focusedOutput
  property string outputPath: ""
  readonly property bool starting: _starting

  signal recordingPaused(string path)
  signal recordingResumed(string path)
  signal recordingStarted(string path)
  signal recordingStopped(string path)

  function _clearRecording(emitStopped: bool): void {
    const stoppedPath = outputPath;
    const wasRecording = isRecording;
    _recorderPid = 0;
    _recorderStartTime = "";
    _signalInFlight = false;
    _starting = false;
    _cleanupInFlight = true;
    isRecording = false;
    isPaused = false;
    Command.run(["rm", "-f", lockPath], () => root._cleanupInFlight = false);
    syncPersist();
    if (emitStopped && wasRecording)
      recordingStopped(stoppedPath);
  }
  function _launchRecorder(captureArgs: var): void {
    const filename = TimeService.format("datetime", "yyyyMMdd_HHmmss") + ".mp4";
    const dir = directory.endsWith("/") ? directory : directory + "/";
    outputPath = dir + filename;
    _starting = true;
    const recorderCommand = ["gpu-screen-recorder", ...captureArgs, "-o", outputPath, "-a", "default_output", "-cursor", "yes"];
    Command.run(["sh", "-c", _launchScript, "sh", lockPath, outputPath, ...recorderCommand], result => {
      root._starting = false;
      const launchInfo = (result.stdout ?? "").trim().split(/\r?\n/);
      const pid = parseInt(launchInfo[0] ?? "0", 10);
      const startTime = launchInfo[1] ?? "";
      if (result.exitCode !== 0 || !Number.isInteger(pid) || pid <= 0 || !startTime) {
        Logger.error("ScreenRecordingService", `Failed to start gpu-screen-recorder (code: ${result.exitCode})`);
        root._clearRecording(false);
        return;
      }
      root._recorderPid = pid;
      root._recorderStartTime = startTime;
      root.isRecording = true;
      root.isPaused = false;
      root.syncPersist();
      root.recordingStarted(root.outputPath);
    }, "screen-recording.launch");
  }
  function _probeRecorder(pid: int, startTime: string, callback: var): void {
    Command.run(["sh", "-c", _probeScript, "sh", String(pid), startTime], callback, "screen-recording.probe");
  }
  function _restoreRecorder(pid: int, startTime: string, path: string): void {
    _starting = true;
    if (pid <= 0 || !startTime) {
      _clearRecording(false);
      return;
    }
    _probeRecorder(pid, startTime, result => {
      root._starting = false;
      if (result.exitCode !== 0) {
        root._clearRecording(false);
        return;
      }
      root._recorderPid = pid;
      root._recorderStartTime = startTime;
      root.outputPath = path || persist.lastOutputPath;
      root.isRecording = true;
      root.isPaused = !!persist.wasPaused;
      root.syncPersist();
    });
  }
  function _signalRecorder(signalName: string, callback: var): void {
    if (_signalInFlight || _recorderPid <= 0 || !_recorderStartTime)
      return;
    _signalInFlight = true;
    Command.run(["sh", "-c", _signalScript, "sh", String(_recorderPid), _recorderStartTime, signalName], result => {
      root._signalInFlight = false;
      callback(result);
    }, "screen-recording.signal");
  }
  function startRecording(mode = "default"): void {
    if (isRecording || _starting || _cleanupInFlight)
      return;
    if (mode === "selection") {
      _starting = true;
      Command.run(["slurp", "-f", "%wx%h+%x+%y"], result => {
        const region = (result.stdout ?? "").trim();
        if (root.isRecording || result.exitCode !== 0 || !region) {
          root._starting = false;
          return;
        }
        root._launchRecorder(["-w", "region", "-region", region]);
      }, "screen-recording.selection");
      return;
    }
    _launchRecorder(["-w", monitor]);
  }
  function stopRecording(): void {
    if (!isRecording || _signalInFlight)
      return;
    _signalRecorder("INT", result => {
      if (result.exitCode !== 0)
        Logger.warn("ScreenRecordingService", `Owned recorder was no longer available (code: ${result.exitCode})`);
      root._clearRecording(true);
    });
  }
  function syncPersist(): void {
    persist.wasPaused = isPaused;
    persist.lastOutputPath = outputPath;
  }
  function togglePause(): void {
    if (!isRecording || _signalInFlight)
      return;
    _signalRecorder("USR2", result => {
      if (result.exitCode !== 0) {
        Logger.warn("ScreenRecordingService", `Owned recorder was no longer available (code: ${result.exitCode})`);
        root._clearRecording(true);
        return;
      }
      root.isPaused = !root.isPaused;
      root.syncPersist();
      if (root.isPaused)
        root.recordingPaused(root.outputPath);
      else
        root.recordingResumed(root.outputPath);
    });
  }
  function toggleRecording(): void {
    isRecording ? stopRecording() : startRecording();
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.isRecording && !root._signalInFlight

    onTriggered: root._probeRecorder(root._recorderPid, root._recorderStartTime, result => {
      if (result.exitCode !== 0)
        root._clearRecording(true);
    })
  }
  PersistentProperties {
    id: persist

    property string lastOutputPath: ""
    property bool wasPaused: false

    reloadableId: "ScreenRecordingServiceState"

    onLoaded: Command.run(["sh", "-c", '[ -r "$1" ] && sed -n "1,3p" "$1"', "sh", root.lockPath], result => {
      const lockData = (result.stdout ?? "").split(/\r?\n/);
      root._restoreRecorder(parseInt(lockData[0] ?? "0", 10), lockData[1] ?? "", lockData[2] ?? persist.lastOutputPath);
    }, "screen-recording.restore")
  }
}
