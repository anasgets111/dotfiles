pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: dateTime

  readonly property var minuteNow: minuteClock.date
  readonly property var now: clock.date
  property int precision: SystemClock.Seconds
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

  Component.onCompleted: {
    if (weekStart < 1 || weekStart > 7)
      weekStart = 7;
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
