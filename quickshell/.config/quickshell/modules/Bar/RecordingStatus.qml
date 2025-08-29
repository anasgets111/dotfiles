import QtQuick
import Qt.labs.platform
import Quickshell
import Quickshell.Hyprland

Item {
  id: recorderWidget

  ///// not working for now
  // Recording config/state
  property string audioCodec: "opus"
  property string audioSource: "default_output"

  // Derived UI props
  readonly property color bgColor: isRecording ? Theme.activeColor : (hovered ? Theme.onHoverColor : Theme.inactiveColor)
  property string colorRange: "limited"
  property string directory: StandardPaths.writableLocation(StandardPaths.MoviesLocation)
  readonly property color fgColor: Theme.textContrast(bgColor)
  property int frameRate: 60

  // UI state
  property bool hovered: false
  property bool isPaused: false
  property bool isRecording: false
  // Self-contained monitor target (explicit name or "screen")
  property string monitor: "screen"
  property string outputPath: ""
  property string quality: "very_high"
  property bool showCursor: true
  // Nerd Font glyphs: recording (solid circle), paused (pause circle), idle (record-circle outline)
  readonly property string statusIcon: isRecording ? (isPaused ? "󰏥" : "") : ""
  property string videoCodec: "h264"

  function ensureMonitor() {
    const m = resolveMonitor();
    recorderWidget.monitor = (m && m.length > 0) ? m : "screen";
  }

  // Detect WM and try to fetch an explicit monitor name. Fallback to "screen".
  function resolveMonitor() {
    // Try Hyprland focused monitor if available
    var mon = "";
    try {
      mon = String((Hyprland && Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) ? Hyprland.focusedMonitor.name : "");
    } catch (e) {
      mon = "";
    }
    if (mon !== "")
      return mon;

    // Fallbacks: try environment-provided monitor name (custom setups may export one)
    const envMon = String(Quickshell.env("GSR_MONITOR") || "");
    if (envMon !== "")
      return envMon;

    // Last resort: "screen" (first monitor); avoids needing -s
    return "screen";
  }
  function startRecording() {
    if (isRecording)
      return;

    ensureMonitor();

    // Build filename yyyyMMdd_HHmmss.mp4
    const ts = new Date();
    const pad = n => (n < 10 ? "0" + n : "" + n);
    const filename = ts.getFullYear() + pad(ts.getMonth() + 1) + pad(ts.getDate()) + "_" + pad(ts.getHours()) + pad(ts.getMinutes()) + pad(ts.getSeconds()) + ".mp4";

    const dir = directory.endsWith("/") ? directory : directory + "/";
    outputPath = dir + filename;

    const args = ["gpu-screen-recorder"];
    // Use explicit monitor name or "screen" to avoid needing -s
    args.push("-w", recorderWidget.monitor);

    args.push("-f", String(frameRate), "-a", audioSource, "-o", outputPath, "-k", videoCodec, "-ac", audioCodec, "-q", quality, "-cursor", (showCursor ? "yes" : "no"), "-cr", colorRange);

    Quickshell.execDetached(args);
    isRecording = true;
    isPaused = false;
  }
  function stopRecording() {
    if (!isRecording)
      return;
    Quickshell.execDetached(["pkill", "-SIGINT", "-f", "gpu-screen-recorder"]);
    isRecording = false;
    isPaused = false;
  }
  function togglePause() {
    if (!isRecording)
      return;
    Quickshell.execDetached(["pkill", "-SIGUSR2", "-f", "gpu-screen-recorder"]);
    isPaused = !isPaused;
  }
  function toggleRecording() {
    isRecording ? stopRecording() : startRecording();
  }

  height: Theme.itemHeight
  visible: true
  width: Theme.itemWidth

  MouseArea {
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    // Left: toggle record, Middle: pause/resume, Right: stop
    onClicked: function (e) {
      if (e.button === Qt.LeftButton) {
        recorderWidget.toggleRecording();
      } else if (e.button === Qt.MiddleButton) {
        recorderWidget.togglePause();
      } else if (e.button === Qt.RightButton) {
        recorderWidget.stopRecording();
      }
    }
    onEntered: recorderWidget.hovered = true
    onExited: recorderWidget.hovered = false
  }
  Rectangle {
    anchors.fill: parent
    border.color: Theme.borderColor
    border.width: 1
    color: recorderWidget.bgColor
    radius: Theme.itemRadius

    Behavior on color {
      ColorAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.OutCubic
      }
    }

    Text {
      anchors.centerIn: parent
      color: recorderWidget.fgColor
      font.bold: true
      font.family: "Nerd Font"
      font.pixelSize: Theme.fontSize
      text: recorderWidget.statusIcon
    }
  }
}
