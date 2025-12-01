pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: dateTime

  property bool internalNtpEnabled: false
  property bool internalNtpSynced: false
  property string internalTimeZone: ""
  readonly property var now: clock.date
  readonly property bool ntpEnabled: internalNtpEnabled
  readonly property bool ntpSynced: internalNtpSynced
  property int precision: SystemClock.Seconds
  property bool ready: false
  readonly property string timeZone: internalTimeZone
  property bool use24Hour: false
  property int weekStart: Qt.locale().firstDayOfWeek

  function _stripMeridiem(str) {
    return str.replace(/\s*(AM|PM)$/i, "");
  }

  function dayName(day, standalone, longForm) {
    const n = day === 0 ? 7 : day;
    const fmt = longForm ? Locale.LongFormat : Locale.ShortFormat;
    return standalone ? Qt.locale().standaloneDayName(n, fmt) : Qt.locale().dayName(n, fmt);
  }

  function format(kind, pattern) {
    const d = clock.date;
    const formatters = {
      time: [Qt.formatTime, "HH:mm", "hh:mm AP"],
      date: [Qt.formatDate, "yyyy-MM-dd", "yyyy-MM-dd"],
      datetime: [Qt.formatDateTime, "yyyy-MM-dd HH:mm", "yyyy-MM-dd hh:mm AP"]
    };
    const [fn, fmt24, fmt12] = formatters[kind] || formatters.datetime;

    if (pattern)
      return fn(d, pattern);
    if (use24Hour)
      return fn(d, fmt24);
    return _stripMeridiem(fn(d, fmt12));
  }

  function formatDuration(sec) {
    sec = Math.floor(sec);
    if (sec <= 0)
      return "";
    const day = Math.floor(sec / 86400);
    const hour = Math.floor((sec % 86400) / 3600);
    const minute = Math.floor((sec % 3600) / 60);
    const second = sec % 60;
    const parts = [];
    if (day)
      parts.push(`${day}d`);
    if (hour)
      parts.push(`${hour}h`);
    if (minute)
      parts.push(`${minute}m`);
    if (!day && !hour && !minute)
      parts.push(`${second}s`);
    return parts.join(" ");
  }

  function formatHM(sec) {
    if (sec <= 0)
      return "Calculating…";
    let h = Math.floor(sec / 3600);
    let m = Math.round((sec % 3600) / 60);
    if (m === 60) {
      h++;
      m = 0;
    }
    return h > 0 ? `${h}h ${m}m` : `${m}m`;
  }

  function timestamp() {
    return Qt.formatTime(clock.date, "h:mm:ss AP");
  }

  function toggle24Hour() {
    use24Hour = !use24Hour;
  }

  function toggleSeconds() {
    precision = precision === SystemClock.Seconds ? SystemClock.Minutes : SystemClock.Seconds;
  }

  Component.onCompleted: {
    if (weekStart < 1 || weekStart > 7)
      weekStart = 7;
    timeInfoProc.running = true;
    ready = true;
    Logger.log("TimeService", "Ready");
  }

  SystemClock {
    id: clock

    precision: dateTime.precision
  }

  Process {
    id: timeInfoProc

    command: ["sh", "-c", "timedatectl show -P Timezone -P NTP -P NTPSynchronized"]

    stdout: StdioCollector {
      onStreamFinished: {
        const vals = this.text.trim().split(/\r?\n/);
        if (vals.length === 3) {
          dateTime.internalTimeZone = vals[0];
          dateTime.internalNtpEnabled = vals[1].toLowerCase() === "yes";
          dateTime.internalNtpSynced = vals[2].toLowerCase() === "yes";
        }
      }
    }
  }
}
