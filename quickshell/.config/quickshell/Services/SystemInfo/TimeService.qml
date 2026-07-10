pragma Singleton
import QtQuick
import Quickshell
import qs.Services.Utils

Singleton {
  id: dateTime

  property bool internalNtpEnabled: false
  property bool internalNtpSynced: false
  property string internalTimeZone: ""
  readonly property var minuteNow: minuteClock.date
  readonly property var now: clock.date
  readonly property bool ntpEnabled: internalNtpEnabled
  readonly property bool ntpSynced: internalNtpSynced
  property int precision: SystemClock.Seconds
  readonly property string timeZone: internalTimeZone
  property bool use24Hour: false
  property int weekStart: Qt.locale().firstDayOfWeek

  function _stripMeridiem(str) {
    return str.replace(/\s*(AM|PM)$/i, "");
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
    Command.run(["sh", "-c", "timedatectl show -P Timezone -P NTP -P NTPSynchronized"], result => {
      const vals = result.stdout.trim().split(/\r?\n/);
      if (vals.length === 3) {
        dateTime.internalTimeZone = vals[0];
        dateTime.internalNtpEnabled = vals[1].toLowerCase() === "yes";
        dateTime.internalNtpSynced = vals[2].toLowerCase() === "yes";
      }
    });
    Logger.log("TimeService", "Ready");
  }

  SystemClock {
    id: clock

    precision: dateTime.precision
  }

  SystemClock {
    id: minuteClock

    precision: SystemClock.Minutes
  }
}
