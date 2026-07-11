import Quickshell.Io

// Integer sysfs attribute read through a FileView; `valid` drops on path
// change or read failure so owners can gate readiness on it.
FileView {
  id: view

  property int fallback: 0
  property bool valid: false
  property int value: fallback

  onLoadFailed: valid = false
  onLoaded: {
    value = parseInt(text().trim(), 10) || fallback;
    valid = true;
  }
  onPathChanged: valid = false
}
