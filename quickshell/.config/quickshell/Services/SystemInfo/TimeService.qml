pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: dateTime

  readonly property string currentDate: useLocaleDate ? Qt.locale().toString(clock.date, localeDateLong ? Locale.LongFormat : Locale.ShortFormat) : Qt.formatDate(clock.date, dateFormat)
  readonly property string currentTime: Qt.formatTime(clock.date, timePattern)
  property string dateFormat: "yyyy-MM-dd"
  property bool localeDateLong: false
  // Expose the underlying Date object for widgets to bind to
  readonly property var now: clock.date
  property bool ntpEnabled: false
  property bool ntpSynced: false
  property int precision: SystemClock.Seconds
  property bool ready: false
  readonly property string timePattern: use24Hour ? (precision === SystemClock.Seconds ? "HH:mm:ss" : "HH:mm") : (precision === SystemClock.Seconds ? "hh:mm:ss AP" : "hh:mm AP")
  property string timeZone: ""
  property bool use24Hour: false
  property bool useLocaleDate: false
  property int weekStart: Qt.locale().firstDayOfWeek

  function dayName(day, standalone, longForm) {
    const n = day === 0 ? 7 : day, fmt = longForm ? Locale.LongFormat : Locale.ShortFormat;
    return standalone ? Qt.locale().standaloneDayName(n, fmt) : Qt.locale().dayName(n, fmt);
  }

  function format(kind, pattern) {
    if (kind === "time")
      return Qt.formatTime(clock.date, pattern || timePattern);

    if (kind === "date")
      return pattern ? Qt.formatDate(clock.date, pattern) : (useLocaleDate ? Qt.locale().toString(clock.date, localeDateLong ? Locale.LongFormat : Locale.ShortFormat) : Qt.formatDate(clock.date, dateFormat));

    return pattern ? Qt.formatDateTime(clock.date, pattern) : currentDate + " " + currentTime;
  }

  function formatDuration(sec) {
    sec = Math.floor(sec);
    if (sec <= 0)
      return "";

    const day = Math.floor(sec / 86400), hour = Math.floor(sec % 86400 / 3600), minute = Math.floor(sec % 3600 / 60), second = sec % 60, parts = [];
    if (day)
      parts.push(day + "d");

    if (hour)
      parts.push(hour + "h");

    if (minute)
      parts.push(minute + "m");

    if (!day && !hour && !minute)
      parts.push(second + "s");

    return parts.join(" ");
  }

  function formatHM(sec) {
    if (sec <= 0)
      return "Calculating…";

    let h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60);
    if (m === 60) {
      h++;
      m = 0;
    }
    return h > 0 ? h + "h " + m + "m" : m + "m";
  }

  function ntpSync() {
    ntpEnabled ? timeInfoProc.running = true : setNtpEnabled(true);
  }

  function setDateFormat(pattern) {
    useLocaleDate = false;
    dateFormat = pattern;
  }

  function setNtpEnabled(enable) {
    ntpToggleProc.command = ["sh", "-c", "timedatectl set-ntp " + (enable ? "true" : "false")];
    ntpToggleProc.running = true;
  }

  function setWeekStart(day) {
    weekStart = Math.max(1, Math.min(7, day === 0 ? 7 : day));
    Logger.log("TimeService", "WeekStart:", weekStart, Qt.locale().dayName(weekStart, Locale.LongFormat));
  }

  function timestamp() {
    return Qt.formatTime(clock.date, "h:mm:ss AP");
  }

  function toggle24Hour() {
    use24Hour = !use24Hour;
  }

  function toggleNtp() {
    setNtpEnabled(!ntpEnabled);
  }

  function toggleSeconds() {
    precision = (precision === SystemClock.Seconds) ? SystemClock.Minutes : SystemClock.Seconds;
  }

  function useLocaleFormat(shortForm) {
    useLocaleDate = true;
    localeDateLong = !shortForm;
  }

  Component.onCompleted: {
    if (weekStart < 1 || weekStart > 7)
      weekStart = 7;

    timeInfoProc.running = true;
    ready = true;
    Logger.log("TimeService", "Ready, WeekStart:", weekStart, Qt.locale().dayName(weekStart, Locale.LongFormat));
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
        const vals = text.trim().split(/\r?\n/);
        if (vals.length === 3) {
          dateTime.timeZone = vals[0];
          dateTime.ntpEnabled = vals[1].toLowerCase() === "yes";
          dateTime.ntpSynced = vals[2].toLowerCase() === "yes";
        } else {
          Logger.log("TimeService", "Failed to parse timedatectl output:", text);
        }
        Logger.log("TimeService", "TZ:", dateTime.timeZone, "| NTP:", dateTime.ntpEnabled, "| Synced:", dateTime.ntpSynced);
      }
    }
  }

  Process {
    id: ntpToggleProc

    stdout: StdioCollector {
      onStreamFinished: timeInfoProc.running = true
    }
  }
}
