pragma Singleton
import Quickshell
import qs.Services.Utils
import qs.Services.WM.Impl.Niri

Singleton {
  readonly property string currentLayout: NiriService.currentLayout
  readonly property int currentLayoutIndex: NiriService.currentLayoutIndex
  readonly property var layouts: NiriService.layouts

  function nextLayout(): void {
    Command.detached(["niri", "msg", "action", "switch-layout", "next"]);
  }
  function setLayoutByIndex(layoutIndex: int): void {
    if (layoutIndex >= 0 && layoutIndex < layouts.length)
      Command.detached(["niri", "msg", "action", "switch-layout", `${layoutIndex}`]);
  }
}
