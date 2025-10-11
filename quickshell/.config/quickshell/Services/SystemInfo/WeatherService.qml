pragma Singleton
import QtQml
import QtQuick
import Quickshell
import qs.Services.Utils

Singleton {
  id: root

  // Public API
  property string currentTemp: "Loading..."
  property int currentWeatherCode: -1
  property string locationName: ""
  property bool hasError: false
  property bool includeLocationInDisplay: true
  property int refreshInterval: 3.6e+06 // 1 hour
  property int maxRetries: 2
  readonly property string displayText: currentTemp + (includeLocationInDisplay && locationName ? " — " + locationName : "") + (isStale ? " (stale)" : "")
  readonly property bool isStale: lastUpdated ? (Date.now() - lastUpdated.getTime()) > refreshInterval * 2 : false
  readonly property real latitude: _lat
  readonly property real longitude: _lon
  // Private state
  property real _lat: NaN
  property real _lon: NaN
  property var lastUpdated: null
  property int _retryCount: 0
  property int _consecutiveErrors: 0
  property bool _isRequesting: false
  // Constants
  readonly property var _config: ({
      "fallback": {
        "lat": 30.0507,
        "lon": 31.2489,
        "name": ""
      },
      "timeout": {
        "geo": 4000,
        "weather": 5000
      },
      "retryDelay": 2000,
      "api": {
        "geo": "https://ipapi.co/json/",
        "weather": "https://api.open-meteo.com/v1/forecast"
      }
    })
  readonly property var _weatherCodes: ({
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

  // Public methods
  function getWeatherIconFromCode() {
    return _getWeatherData(currentWeatherCode).icon;
  }

  function getWeatherDescriptionFromCode() {
    return _getWeatherData(currentWeatherCode).desc;
  }

  function refresh() {
    retryTimer.stop();
    _retryCount = 0;
    if (!isNaN(_lat) && !isNaN(_lon)) {
      Logger.log("WeatherService", "Manual refresh:", `${_lat},${_lon}`);
      _fetchWeather(_lat, _lon);
    } else {
      Logger.warn("WeatherService", "No coordinates available");
    }
  }

  // Core logic
  function updateWeather() {
    const saved = _loadSavedLocation();
    if (!isNaN(_lat) && !isNaN(_lon)) {
      Logger.log("WeatherService", "Using existing coords:", `${_lat},${_lon}`);
      _fetchWeather(_lat, _lon);
    } else if (saved) {
      _lat = saved.lat;
      _lon = saved.lon;
      locationName = saved.name;
      Logger.log("WeatherService", "Using persisted coords:", `${_lat},${_lon}`);
      _fetchWeather(_lat, _lon);
    } else {
      _fetchGeoLocation();
    }
  }

  // Private methods
  function _getWeatherData(code) {
    const key = String(code);
    return _weatherCodes[key] || {
      "icon": "❓",
      "desc": "Unknown"
    };
  }

  function _loadSavedLocation() {
    try {
      const data = JSON.parse(persist.savedLocationJson || "{}");
      const lat = Number(data.lat);
      const lon = Number(data.lon);
      if (!isNaN(lat) && !isNaN(lon))
        return {
          "lat": lat,
          "lon": lon,
          "name": String(data.name || "")
        };
    } catch (e) {
      Logger.warn("WeatherService", "Failed to parse saved location");
    }
    return null;
  }

  function _saveLocation(lat, lon, name) {
    persist.savedLocationJson = JSON.stringify({
      "lat": lat,
      "lon": lon,
      "name": name
    });
  }

  function _setLocation(lat, lon, name) {
    _lat = lat;
    _lon = lon;
    locationName = name;
    _saveLocation(lat, lon, name);
  }

  function _useFallback() {
    const fb = _config.fallback;
    const name = fb.name || `${fb.lat}, ${fb.lon}`;
    Logger.warn("WeatherService", "Applying fallback:", `${fb.lat},${fb.lon}`);
    _setLocation(fb.lat, fb.lon, name);
    _fetchWeather(fb.lat, fb.lon);
  }

  function _fetchGeoLocation() {
    _httpGet(_config.api.geo, _config.timeout.geo, function (data) {
      const name = `${data.city || ""}${data.country_name ? ", " + data.country_name : ""}`;
      Logger.log("WeatherService", "IP geo success:", `${data.latitude},${data.longitude}`);
      _setLocation(data.latitude, data.longitude, name);
      _fetchWeather(data.latitude, data.longitude);
    }, function () {
      Logger.warn("WeatherService", "IP geo failed");
      _useFallback();
    });
  }

  function _fetchWeather(lat, lon) {
    const url = `${_config.api.weather}?latitude=${lat}&longitude=${lon}&current_weather=true&timezone=auto`;
    _httpGet(url, _config.timeout.weather, function (data) {
      if (!data.current_weather)
        throw new Error("Missing current_weather");

      currentWeatherCode = data.current_weather.weathercode;
      currentTemp = `${Math.round(data.current_weather.temperature)}°C ${getWeatherIconFromCode()}`;
      lastUpdated = new Date();
      hasError = false;
      _consecutiveErrors = 0;
      _retryCount = 0;
      Logger.log("WeatherService", "Weather success:", currentTemp, "code:", currentWeatherCode);
    }, function () {
      Logger.warn("WeatherService", "Weather fetch failed");
      _scheduleRetry();
    });
  }

  function _httpGet(url, timeout, onSuccess, onError) {
    if (_isRequesting) {
      Logger.warn("WeatherService", "Request in progress, ignoring");
      return;
    }
    _isRequesting = true;
    const xhr = new XMLHttpRequest();
    xhr.timeout = timeout;
    Logger.log("WeatherService", "Request:", url, "timeout:", timeout, "ms");
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== XMLHttpRequest.DONE)
        return;

      const status = xhr.status;
      const text = xhr.responseText;
      xhr.onreadystatechange = null;
      xhr.ontimeout = null;
      _isRequesting = false;
      if (status === 200) {
        try {
          onSuccess(JSON.parse(text));
        } catch (e) {
          Logger.warn("WeatherService", "Parse error:", e.message);
          onError();
        }
      } else {
        Logger.warn("WeatherService", "HTTP status:", status);
        onError();
      }
    };
    xhr.ontimeout = function () {
      xhr.onreadystatechange = null;
      xhr.ontimeout = null;
      _isRequesting = false;
      Logger.warn("WeatherService", "Timeout after", timeout, "ms");
      onError();
    };
    xhr.open("GET", url);
    xhr.send();
  }

  function _scheduleRetry() {
    hasError = true;
    _consecutiveErrors++;
    if (_retryCount < maxRetries) {
      _retryCount++;
      retryTimer.interval = _config.retryDelay * Math.pow(2, _retryCount - 1);
      Logger.warn("WeatherService", "Retry", _retryCount, "in", retryTimer.interval, "ms");
      retryTimer.start();
    } else {
      Logger.warn("WeatherService", "Max retries reached");
      _retryCount = 0;
    }
  }

  Component.onCompleted: {
    weatherTimer.start();
    Logger.log("WeatherService", "Started; interval:", refreshInterval, "ms");
    updateWeather();
  }
  Component.onDestruction: {
    weatherTimer.stop();
    retryTimer.stop();
  }

  PersistentProperties {
    id: persist

    property string savedLocationJson: "{}"

    function hydrate() {
      const saved = root._loadSavedLocation();
      if (saved) {
        root._lat = saved.lat;
        root._lon = saved.lon;
        root.locationName = saved.name;
      }
      root.updateWeather();
    }

    reloadableId: "WeatherService"
    onLoaded: hydrate()
    onReloaded: hydrate()
  }

  Timer {
    id: weatherTimer

    interval: root.refreshInterval
    repeat: true
    onTriggered: root.updateWeather()
  }

  Timer {
    id: retryTimer

    repeat: false
    onTriggered: {
      Logger.log("WeatherService", "Retrying...");
      if (root._isRequesting) {
        Logger.warn("WeatherService", "Request already in progress, skipping retry");
        return;
      }
      if (!isNaN(root._lat) && !isNaN(root._lon))
        root._fetchWeather(root._lat, root._lon);
      else
        root.updateWeather();
    }
  }
}
