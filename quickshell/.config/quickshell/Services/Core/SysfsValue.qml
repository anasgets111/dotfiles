import Quickshell.Io

FileView {
  id: view

  property int fallback: 0
  property bool valid: false
  property int value: fallback

  onLoadFailed: valid = false
  onLoaded: {
    const parsed = parseInt(text().trim(), 10);
    const parsedValid = Number.isFinite(parsed);
    value = parsedValid ? parsed : fallback;
    valid = parsedValid;
  }
  onPathChanged: valid = false
}
