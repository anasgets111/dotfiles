pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: dateTime

  readonly property var minuteNow: minuteClock.date
  readonly property var now: clock.date
  property bool use24Hour: !/\bAP\b/i.test(Qt.locale().timeFormat(Locale.ShortFormat))

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
    return fn(d, fmt12);
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

  SystemClock {
    id: clock

    precision: SystemClock.Seconds
  }
  SystemClock {
    id: minuteClock

    precision: SystemClock.Minutes
  }
}
