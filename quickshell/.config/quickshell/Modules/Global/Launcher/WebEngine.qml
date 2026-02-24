pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Config

Singleton {
  id: root

  property string _query: ""
  property string _url: ""
  property bool _isUrl: false
  
  readonly property bool hasResult: _query.length > 0 && (_isUrl || _isFallback)
  readonly property bool isUrl: _isUrl
  readonly property string url: _url
  readonly property string query: _query
  
  // Only show as fallback if other engines didn't match and no apps found
  // This property will be controlled by AppLauncher
  property bool _isFallback: false
  readonly property bool isFallback: _isFallback

  function parse(text: string, isFallback: bool): void {
    const input = String(text || "").trim();
    _query = input;
    _isFallback = isFallback;
    
    if (!input) {
      _url = "";
      _isUrl = false;
      return;
    }

    // URL detection: starts with http/https OR has a TLD-like ending
    const urlPattern = /^(https?:\/\/)?([\w\-]+\.)+[\w\-]{2,}(\/.*)?$/i;
    if (urlPattern.test(input)) {
      _isUrl = true;
      _url = input.startsWith("http") ? input : "https://" + input;
    } else {
      _isUrl = false;
      _url = "https://duckduckgo.com/?q=" + encodeURIComponent(input);
    }
  }

  function reset(): void {
    _query = "";
    _url = "";
    _isUrl = false;
    _isFallback = false;
  }
}
