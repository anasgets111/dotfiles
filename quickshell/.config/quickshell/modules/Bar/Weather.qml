import QtQuick
import Quickshell

Item {
  id: weatherWidget

  property bool _fallbackApplied: false
  property int _geoAttempt: 0
  property string _pendingRetry: ""
  property int _wxAttempt: 0
  property int consecutiveErrors: 0

  // --- State -----------------------------------------------------------
  property string currentTemp: "Loading..."
  property int currentWeatherCode: -1
  readonly property int defaultRefreshMs: 3600000 // 1 hour
  readonly property int defaultRetryDelayMs: 2000
  readonly property string displayText: {
    const parts = [];
    parts.push(currentTemp);
    if (includeLocationInDisplay && locationName)
      parts.push("— " + locationName);
    if (isStale)
      parts.push("(stale)");
    return parts.join(' ');
  }

  // Fallback coordinates (used when IP geolocation fails)
  readonly property real fallbackLat: 30.0507
  // Optional: name to display for fallback coords; leave empty to show nothing
  readonly property string fallbackLocationName: ""
  readonly property real fallbackLon: 31.2489
  readonly property int geoTimeoutMs: 4000
  property bool hasError: false
  property bool includeLocationInDisplay: true
  readonly property string ipGeoUrl: "https://ipapi.co/json/"
  readonly property bool isStale: lastUpdated ? (Date.now() - lastUpdated.getTime()) > staleAfterMs : false
  property var lastUpdated: null
  property real latitude: NaN
  property string locationName: ""
  property real longitude: NaN
  property int maxRetries: 2
  // --- Constants -------------------------------------------------------
  readonly property string openMeteoUrlBase: "https://api.open-meteo.com/v1/forecast"
  property int refreshInterval: defaultRefreshMs
  property int retryDelayMs: defaultRetryDelayMs
  property int staleAfterMs: refreshInterval * 2

  // Factor icon map to a constant
  readonly property var weatherIconMap: ({
      "0": {
        "icon": "☀️",
        "desc": "Clear sky"
      },
      "1": {
        "icon": "🌤️",
        "desc": "Mainly clear"
      },
      "2": {
        "icon": "⛅",
        "desc": "Partly cloudy"
      },
      "3": {
        "icon": "☁️",
        "desc": "Overcast"
      },
      "45": {
        "icon": "🌫️",
        "desc": "Fog"
      },
      "48": {
        "icon": "🌫️",
        "desc": "Depositing rime fog"
      },
      "51": {
        "icon": "🌦️",
        "desc": "Drizzle: Light"
      },
      "53": {
        "icon": "🌦️",
        "desc": "Drizzle: Moderate"
      },
      "55": {
        "icon": "🌧️",
        "desc": "Drizzle: Dense"
      },
      "56": {
        "icon": "🌧️❄️",
        "desc": "Freezing Drizzle: Light"
      },
      "57": {
        "icon": "🌧️❄️",
        "desc": "Freezing Drizzle: Dense"
      },
      "61": {
        "icon": "🌦️",
        "desc": "Rain: Slight"
      },
      "63": {
        "icon": "🌧️",
        "desc": "Rain: Moderate"
      },
      "65": {
        "icon": "🌧️",
        "desc": "Rain: Heavy"
      },
      "66": {
        "icon": "🌧️❄️",
        "desc": "Freezing Rain: Light"
      },
      "67": {
        "icon": "🌧️❄️",
        "desc": "Freezing Rain: Heavy"
      },
      "71": {
        "icon": "🌨️",
        "desc": "Snow fall: Slight"
      },
      "73": {
        "icon": "🌨️",
        "desc": "Snow fall: Moderate"
      },
      "75": {
        "icon": "❄️",
        "desc": "Snow fall: Heavy"
      },
      "77": {
        "icon": "❄️",
        "desc": "Snow grains"
      },
      "80": {
        "icon": "🌦️",
        "desc": "Rain showers: Slight"
      },
      "81": {
        "icon": "🌧️",
        "desc": "Rain showers: Moderate"
      },
      "82": {
        "icon": "⛈️",
        "desc": "Rain showers: Violent"
      },
      "85": {
        "icon": "🌨️",
        "desc": "Snow showers: Slight"
      },
      "86": {
        "icon": "❄️",
        "desc": "Snow showers: Heavy"
      },
      "95": {
        "icon": "⛈️",
        "desc": "Thunderstorm: Slight or moderate"
      },
      "96": {
        "icon": "⛈️🧊",
        "desc": "Thunderstorm with slight hail"
      },
      "99": {
        "icon": "⛈️🧊",
        "desc": "Thunderstorm with heavy hail"
      }
    })
  readonly property int wxTimeoutMs: 5000

  function applyFallbackCoords() {
    if (_fallbackApplied)
      return;
    latitude = fallbackLat;
    longitude = fallbackLon;
    locationName = fallbackLocationName || (fallbackLat + ", " + fallbackLon);
    persist.savedLat = latitude;
    persist.savedLon = longitude;
    persist.savedLocationName = locationName;
    _fallbackApplied = true;
    hasError = false;
    _geoAttempt = 0;
    fetchCurrentTemp(latitude, longitude);
  }
  function fetchCurrentTemp(lat, lon) {
    var wxXhr = new XMLHttpRequest();
    var url = openMeteoUrlBase + "?latitude=" + lat + "&longitude=" + lon + "&current_weather=true&timezone=auto";
    wxXhr.open("GET", url);
    wxXhr.timeout = wxTimeoutMs;
    wxXhr.onreadystatechange = function () {
      if (wxXhr.readyState !== XMLHttpRequest.DONE)
        return;

      if (wxXhr.status === 200) {
        try {
          var data = JSON.parse(wxXhr.responseText);
          if (data && data.current_weather) {
            currentWeatherCode = data.current_weather.weathercode;
            var icon = getWeatherIconFromCode();
            currentTemp = Math.round(data.current_weather.temperature) + "°C" + ' ' + icon;
            lastUpdated = new Date();
            hasError = false;
            consecutiveErrors = 0;
            _wxAttempt = 0;
          } else {
            console.warn("Weather: response missing current_weather");
            scheduleWxRetry();
          }
        } catch (e) {
          console.warn("Weather: failed to parse weather response", e);
          scheduleWxRetry();
        }
      } else {
        console.warn("Weather: fetch failed with status", wxXhr.status);
        scheduleWxRetry();
      }
    };
    wxXhr.ontimeout = function () {
      console.warn("Weather: fetch timed out");
      scheduleWxRetry();
    };
    wxXhr.send();
  }
  function getWeatherDescriptionFromCode() {
    const key = String(currentWeatherCode);
    if (weatherIconMap.hasOwnProperty(key))
      return weatherIconMap[key].desc;

    return "Unknown";
  }
  function getWeatherIconAndDesc(code) {
    const key = String(code);
    if (weatherIconMap.hasOwnProperty(key))
      return weatherIconMap[key];

    return {
      "icon": "❓",
      "desc": "Unknown"
    };
  }
  function getWeatherIconFromCode() {
    const key = String(currentWeatherCode);
    if (weatherIconMap.hasOwnProperty(key))
      return weatherIconMap[key].icon;

    return "❓";
  }
  function scheduleGeoRetry() {
    hasError = true;
    consecutiveErrors++;
    if (_geoAttempt < maxRetries) {
      _geoAttempt++;
      _pendingRetry = "geo";
      retryTimer.interval = retryDelayMs * _geoAttempt;
      retryTimer.start();
    }
  }
  function scheduleWxRetry() {
    hasError = true;
    consecutiveErrors++;
    if (_wxAttempt < maxRetries) {
      _wxAttempt++;
      _pendingRetry = "wx";
      retryTimer.interval = retryDelayMs * _wxAttempt;
      retryTimer.start();
    }
  }
  function updateWeather() {
    if (isNaN(latitude) || isNaN(longitude)) {
      // Prefer persisted coordinates if available
      if (!isNaN(persist.savedLat) && !isNaN(persist.savedLon)) {
        latitude = persist.savedLat;
        longitude = persist.savedLon;
        if (persist.savedLocationName)
          locationName = persist.savedLocationName;
        fetchCurrentTemp(latitude, longitude);
        return;
      }

      var geoXhr = new XMLHttpRequest();
      geoXhr.open("GET", ipGeoUrl);
      geoXhr.timeout = geoTimeoutMs;
      geoXhr.onreadystatechange = function () {
        if (geoXhr.readyState !== XMLHttpRequest.DONE)
          return;

        if (geoXhr.status === 200) {
          try {
            var ipData = JSON.parse(geoXhr.responseText);
            latitude = ipData.latitude;
            longitude = ipData.longitude;
            // Compose a readable location string
            locationName = (ipData.city || "") + (ipData.country_name ? ", " + ipData.country_name : "");

            persist.savedLat = latitude;
            persist.savedLon = longitude;
            persist.savedLocationName = locationName;

            hasError = false;
            _geoAttempt = 0;
            fetchCurrentTemp(latitude, longitude);
          } catch (e) {
            console.warn("Weather: failed to parse IP geo response", e);
            applyFallbackCoords();
          }
        } else {
          console.warn("Weather: IP geo failed with status", geoXhr.status);
          applyFallbackCoords();
        }
      };
      geoXhr.ontimeout = function () {
        console.warn("Weather: IP geo request timed out");
        applyFallbackCoords();
      };
      geoXhr.send();
    } else {
      fetchCurrentTemp(latitude, longitude);
    }
  }

  PersistentProperties {
    id: persist

    property real savedLat: NaN
    property string savedLocationName: ""
    property real savedLon: NaN

    function hydrate() {
      if (!isNaN(persist.savedLat) && !isNaN(persist.savedLon)) {
        weatherWidget.latitude = persist.savedLat;
        weatherWidget.longitude = persist.savedLon;
        weatherWidget.locationName = persist.savedLocationName;
      }
      if (!weatherTimer.running)
        weatherTimer.start();
      weatherWidget.updateWeather();
    }

    reloadableId: "WeatherWidget"

    onLoaded: hydrate()
    onReloaded: hydrate()
  }
  Timer {
    id: weatherTimer

    interval: weatherWidget.refreshInterval
    repeat: true
    running: false
    triggeredOnStart: false

    onTriggered: weatherWidget.updateWeather()
  }
  Timer {
    id: retryTimer

    interval: 0
    repeat: false
    running: false
    triggeredOnStart: false

    onTriggered: {
      if (weatherWidget._pendingRetry === "geo") {
        weatherWidget.updateWeather();
      } else if (weatherWidget._pendingRetry === "wx") {
        if (!isNaN(weatherWidget.latitude) && !isNaN(weatherWidget.longitude))
          weatherWidget.fetchCurrentTemp(weatherWidget.latitude, weatherWidget.longitude);
        else
          weatherWidget.updateWeather();
      }
      weatherWidget._pendingRetry = "";
    }
  }
}
