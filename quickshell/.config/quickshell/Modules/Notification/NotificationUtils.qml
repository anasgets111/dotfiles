pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Config

QtObject {
  id: utils

  // Urgency to color mapping - eliminates duplication
  function urgencyToColor(urgency) {
    switch (urgency) {
    case NotificationUrgency.Critical:
      return "#ff4d4f";
    case NotificationUrgency.Low:
      return Qt.rgba(Theme.disabledColor.r, Theme.disabledColor.g, Theme.disabledColor.b, 0.9);
    default:
      return Theme.activeColor;
    }
  }

  // Urgency to string mapping
  function urgencyToString(urgency) {
    switch (urgency) {
    case NotificationUrgency.Low:
      return "low";
    case NotificationUrgency.Critical:
      return "critical";
    default:
      return "normal";
    }
  }

  // Icon resolution helper
  function resolveIconSource(appName, appIcon, fallback) {
    if (appIcon && appIcon !== "")
      return appIcon;
    if (appName && appName !== "")
      return Quickshell.iconPath(appName, true);
    return fallback || "dialog-information";
  }
}
