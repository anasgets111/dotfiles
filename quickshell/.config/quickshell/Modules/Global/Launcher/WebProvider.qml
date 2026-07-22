pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Services.Utils

Singleton {
  id: root

  property bool _isUrl: false
  property string _query: ""
  property string _url: ""
  readonly property string rowBadge: _isUrl ? "URL" : "WEB"
  readonly property string rowHint: qsTr("Enter to open")
  readonly property string rowIcon: _isUrl ? "󰖟" : "󰍉"
  readonly property bool rowIconIsText: false
  readonly property string rowSubtitle: _isUrl ? qsTr("Open link") : qsTr("Web search")
  readonly property string rowTitle: _isUrl ? _url : _query

  function activate(): void {
    Command.detached(["xdg-open", _url]);
  }
  function claims(query: string, appsWeak: bool): bool {
    const input = String(query || "").trim();
    _query = input;

    const urlPattern = /^(https?:\/\/)?([\w\-]+\.)+[\w\-]{2,}(\/.*)?$/i;
    if (urlPattern.test(input)) {
      _isUrl = true;
      _url = /^https?:\/\//i.test(input) ? input : "https://" + input;
    } else {
      _isUrl = false;
      _url = "https://duckduckgo.com/?q=" + encodeURIComponent(input);
    }
    return _isUrl || appsWeak;
  }
  function reset(): void {
    _query = "";
    _url = "";
    _isUrl = false;
  }
}
