pragma Singleton
import Quickshell

Singleton {
  readonly property var codes: ({
      "0": {
        icon: "☀️",
        desc: "Clear sky"
      },
      "1": {
        icon: "🌤️",
        desc: "Mainly clear"
      },
      "2": {
        icon: "⛅",
        desc: "Partly cloudy"
      },
      "3": {
        icon: "☁️",
        desc: "Overcast"
      },
      "45": {
        icon: "🌫️",
        desc: "Fog"
      },
      "48": {
        icon: "🌫️",
        desc: "Depositing rime fog"
      },
      "51": {
        icon: "🌦️",
        desc: "Drizzle: Light"
      },
      "53": {
        icon: "🌦️",
        desc: "Drizzle: Moderate"
      },
      "55": {
        icon: "🌧️",
        desc: "Drizzle: Dense"
      },
      "56": {
        icon: "🌧️❄️",
        desc: "Freezing Drizzle: Light"
      },
      "57": {
        icon: "🌧️❄️",
        desc: "Freezing Drizzle: Dense"
      },
      "61": {
        icon: "🌦️",
        desc: "Rain: Slight"
      },
      "63": {
        icon: "🌧️",
        desc: "Rain: Moderate"
      },
      "65": {
        icon: "🌧️",
        desc: "Rain: Heavy"
      },
      "66": {
        icon: "🌧️❄️",
        desc: "Freezing Rain: Light"
      },
      "67": {
        icon: "🌧️❄️",
        desc: "Freezing Rain: Heavy"
      },
      "71": {
        icon: "🌨️",
        desc: "Snow fall: Slight"
      },
      "73": {
        icon: "🌨️",
        desc: "Snow fall: Moderate"
      },
      "75": {
        icon: "❄️",
        desc: "Snow fall: Heavy"
      },
      "77": {
        icon: "❄️",
        desc: "Snow grains"
      },
      "80": {
        icon: "🌦️",
        desc: "Rain showers: Slight"
      },
      "81": {
        icon: "🌧️",
        desc: "Rain showers: Moderate"
      },
      "82": {
        icon: "⛈️",
        desc: "Rain showers: Violent"
      },
      "85": {
        icon: "🌨️",
        desc: "Snow showers: Slight"
      },
      "86": {
        icon: "❄️",
        desc: "Snow showers: Heavy"
      },
      "95": {
        icon: "⛈️",
        desc: "Thunderstorm: Slight or moderate"
      },
      "96": {
        icon: "⛈️🧊",
        desc: "Thunderstorm with slight hail"
      },
      "99": {
        icon: "⛈️🧊",
        desc: "Thunderstorm with heavy hail"
      }
    })

  function get(code) {
    return codes[String(code)] || {
      icon: "❓",
      desc: "Unknown"
    };
  }
}
