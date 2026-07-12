pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.Config
import qs.Services.Utils

Singleton {
  id: root

  property bool _isUrl: false
  property string _query: ""
  property string _url: ""
  readonly property Component delegate: Component {
    Column {
      anchors.fill: parent
      spacing: Theme.spacingXs

      OText {
        color: Theme.activeColor
        font.pixelSize: Theme.fontXs
        text: root._isUrl ? qsTr("Open link") : qsTr("Web search")
      }

      RowLayout {
        spacing: Theme.spacingMd

        OText {
          color: Theme.activeColor
          font.pixelSize: Theme.fontLg
          text: root._isUrl ? "󰖟" : "󰍉"
        }

        OText {
          Layout.fillWidth: true
          font.pixelSize: Theme.fontLg
          text: root._isUrl ? root._url : root._query
        }
      }

      LauncherHint {
        text: qsTr("Enter to open")
      }
    }
  }
  readonly property string statusLabel: _isUrl ? "URL" : "WEB"

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
