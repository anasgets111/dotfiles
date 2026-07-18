pragma Singleton
import QtQuick
import Quickshell
import qs.Services.WM.Impl.Niri

Singleton {
  id: root

  signal featuresChanged

  function fetchFeatures(outputName: string, callback: var): void {
    NiriService.request('"Outputs"', response => {
      const outputs = response?.Ok?.Outputs;
      const output = outputs?.[outputName] ?? (outputs ? Object.values(outputs).find(candidate => candidate?.name === outputName) : null);
      if (!output) {
        callback(null);
        return;
      }

      const modes = (output.modes ?? []).map(mode => ({
            width: mode.width,
            height: mode.height,
            refreshRate: typeof mode.refresh_rate === "number" ? mode.refresh_rate / 1000 : null
          }));
      const currentMode = Number.isInteger(output.current_mode) ? modes[output.current_mode] : null;
      callback({
        bitDepth: typeof output.max_bpc === "number" ? output.max_bpc : null,
        fps: currentMode?.refreshRate ?? null,
        modes,
        vrr: {
          supported: !!output.vrr_supported,
          active: !!output.vrr_enabled
        },
        hdr: {
          supported: false,
          active: false
        },
        mirror: false
      });
    });
  }

  Connections {
    function onConfigLoaded(): void {
      root.featuresChanged();
    }
    function onRequestConnectedChanged(): void {
      if (NiriService.requestConnected)
        root.featuresChanged();
    }

    target: NiriService
  }
}
