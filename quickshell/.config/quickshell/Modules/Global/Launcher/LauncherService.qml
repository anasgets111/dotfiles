pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Modules.Global.Launcher

Singleton {
  id: root

  property var _active: null
  readonly property var activeProvider: _active
  readonly property bool hasSpecial: _active !== null
  readonly property var providers: [CurrencyProvider, CalcProvider]

  function activateSpecial(): void {
    if (_active)
      _active.activate();
  }
  function refresh(): void {
    CurrencyProvider.refreshIfStale();
  }
  function reset(): void {
    for (const p of providers)
      p.reset();
    WebProvider.reset();
    _active = null;
  }
  function route(query: string, appCount: int, maxAppScore: real): void {
    reset();

    const q = String(query || "").trim();
    if (!q)
      return;

    for (const p of providers) {
      if (p.claims(q)) {
        _active = p;
        return;
      }
    }
    const appsWeak = appCount === 0 || maxAppScore < Math.max(32, q.length * 25);
    _active = WebProvider.claims(q, appsWeak) ? WebProvider : null;
  }
}
