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

  property bool _isFallback: false
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
        text: root.isUrl ? "Open Link" : "Web Search"
      }

      RowLayout {
        spacing: Theme.spacingMd

        OText {
          color: Theme.activeColor
          font.pixelSize: Theme.fontLg
          text: root.isUrl ? "󰖟" : "󰍉"
        }

        OText {
          Layout.fillWidth: true
          font.pixelSize: Theme.fontLg
          text: root.isUrl ? root.url : root.query
        }
      }

      LauncherHint {
        text: "Enter to open"
      }
    }
  }
  readonly property bool hasResult: _query.length > 0 && (_isUrl || _isFallback)
  readonly property bool isUrl: _isUrl
  readonly property string query: _query
  readonly property string statusLabel: _isUrl ? "URL" : "WEB"
  readonly property string url: _url

  function activate(): void {
    Command.detached(["xdg-open", url]);
  }

  function claims(query: string, appsWeak: bool): bool {
    const input = String(query || "").trim();
    _query = input;
    _isFallback = appsWeak;

    if (!input) {
      _url = "";
      _isUrl = false;
      return false;
    }

    const urlPattern = /^(https?:\/\/)?([\w\-]+\.)+[\w\-]{2,}(\/.*)?$/i;
    if (urlPattern.test(input)) {
      _isUrl = true;
      _url = input.startsWith("http") ? input : "https://" + input;
    } else {
      _isUrl = false;
      _url = "https://duckduckgo.com/?q=" + encodeURIComponent(input);
    }
    return hasResult;
  }

  function reset(): void {
    _query = "";
    _url = "";
    _isUrl = false;
    _isFallback = false;
  }
}
