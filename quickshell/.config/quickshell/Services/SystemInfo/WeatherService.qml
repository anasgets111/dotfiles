pragma Singleton
import QtQml
import QtQuick
import Quickshell
import qs.Config
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: root

  // Private state
  property bool _isRequesting: false
  readonly property int _minRefreshInterval: 30000 // 30 seconds minimum between manual refreshes
  property int _retryAttempt: 0
  readonly property int _retryDelay: 2000
  readonly property int _timeout: 5000
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

  // Public API
  property string currentTemp: "Loading..."
  property int currentWeatherCode: -1
  readonly property string displayText: currentTemp + (includeLocationInDisplay && locationName ? " — " + locationName : "") + (timeAgoText ? " (" + timeAgoText + ")" : "") + (isStale ? " [stale]" : "")
  property bool hasError: false
  property bool includeLocationInDisplay: true
  readonly property bool isStale: lastUpdated ? (Date.now() - lastUpdated.getTime()) > refreshInterval * 2 : false
  property var lastUpdated: null
  readonly property real latitude: weatherLocation.latitude || NaN
  readonly property string locationName: weatherLocation.placeName || ""
  readonly property real longitude: weatherLocation.longitude || NaN
  property int maxRetries: 2
  readonly property int refreshInterval: 3.6e+06 // 1 hour
  readonly property string timeAgoText: _calculateTimeAgo()
  readonly property var weatherLocation: Settings.data.weatherLocation

  function _calculateTimeAgo() {
    if (!lastUpdated)
      return "";

    const now = TimeService.now.getTime();
    const diff = now - lastUpdated.getTime();
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);

    if (days > 0)
      return days === 1 ? "1 day ago" : `${days} days ago`;
    if (hours > 0)
      return hours === 1 ? "1 hour ago" : `${hours} hours ago`;
    if (minutes > 0)
      return minutes === 1 ? "1 minute ago" : `${minutes} minutes ago`;
    return "just now";
  }

  function _fetchGeoLocation() {
    _httpGet("https://ipapi.co/json/", _timeout, function (data) {
      const name = `${data.city || ""}${data.country_name ? ", " + data.country_name : ""}`;
      _updateSettings(data.latitude, data.longitude, name);
      _fetchWeather(data.latitude, data.longitude);
    }, function () {
      Logger.warn("WeatherService", "IP geo failed, using cached location");
      _useCachedLocation();
    });
  }

  function _fetchWeather(lat, lon) {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current_weather=true&timezone=auto`;
    _httpGet(url, _timeout, function (data) {
      if (!data.current_weather)
        throw new Error("Missing current_weather");

      const weatherCode = data.current_weather.weathercode;
      const temperature = Math.round(data.current_weather.temperature);

      currentWeatherCode = weatherCode;
      currentTemp = `${temperature}°C ${getWeatherIconFromCode()}`;
      lastUpdated = new Date();
      hasError = false;
      _retryAttempt = 0;

      _saveWeatherData(weatherCode, lastUpdated, temperature);

      // Restart timer with full interval after successful fetch
      updateTimer.interval = refreshInterval;
      updateTimer.restart();
    }, function () {
      Logger.warn("WeatherService", "Weather fetch failed");
      _handleError();
    });
  }

  function _getWeatherData(code) {
    const key = String(code);
    return _weatherCodes[key] || {
      "icon": "❓",
      "desc": "Unknown"
    };
  }

  function _handleError() {
    hasError = true;

    if (_retryAttempt < maxRetries) {
      _retryAttempt++;
      const delay = _retryDelay * Math.pow(2, _retryAttempt - 1);
      Logger.warn("WeatherService", "Retry", _retryAttempt, "in", delay, "ms");
      updateTimer.interval = delay;
      updateTimer.restart();
    } else {
      Logger.warn("WeatherService", "Max retries reached");
      _retryAttempt = 0;
      updateTimer.interval = refreshInterval;
    }
  }

  function _httpGet(url, timeout, onSuccess, onError) {
    if (_isRequesting) {
      Logger.warn("WeatherService", "Request in progress, ignoring");
      return;
    }

    _isRequesting = true;
    const xhr = new XMLHttpRequest();
    xhr.timeout = timeout;

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

  function _isCachedDataFresh() {
    if (!lastUpdated)
      return false;
    const age = TimeService.now.getTime() - lastUpdated.getTime();
    return age < refreshInterval;
  }

  function _loadCachedData() {
    if (!Settings.isLoaded || !weatherLocation)
      return null;

    try {
      const lat = weatherLocation.latitude;
      const lon = weatherLocation.longitude;
      const code = weatherLocation.weatherCode;
      const timestamp = weatherLocation.lastPollTimestamp;

      if (isNaN(lat) || isNaN(lon) || isNaN(code) || !timestamp)
        return null;

      // Restore state from settings
      currentWeatherCode = code;
      lastUpdated = new Date(timestamp);
      const temp = weatherLocation.temperature || 0;
      currentTemp = `${temp}°C ${getWeatherIconFromCode()}`;

      return {
        lat,
        lon
      };
    } catch (e) {
      Logger.warn("WeatherService", "Failed to load cached data:", e.message);
      return null;
    }
  }

  function _saveWeatherData(code, timestamp, temperature) {
    if (!Settings.isLoaded)
      return;
    weatherLocation.weatherCode = code;
    weatherLocation.temperature = temperature;
    weatherLocation.lastPollTimestamp = timestamp.toISOString();
  }

  function _updateSettings(lat, lon, name) {
    if (!Settings.isLoaded)
      return;
    weatherLocation.latitude = lat;
    weatherLocation.longitude = lon;
    weatherLocation.placeName = name;
  }

  function _useCachedLocation() {
    const lat = weatherLocation.latitude;
    const lon = weatherLocation.longitude;

    if (!isNaN(lat) && !isNaN(lon)) {
      _fetchWeather(lat, lon);
    } else {
      Logger.warn("WeatherService", "No cached location available");
      hasError = true;
      currentTemp = "Location unavailable";
    }
  }

  function getWeatherDescriptionFromCode() {
    return _getWeatherData(currentWeatherCode).desc;
  }

  // Public methods
  function getWeatherIconFromCode() {
    return _getWeatherData(currentWeatherCode).icon;
  }

  function refresh() {
    // Prevent API spam - require at least 30 seconds between manual refreshes
    if (lastUpdated && (Date.now() - lastUpdated.getTime()) < _minRefreshInterval) {
      Logger.log("WeatherService", "Manual refresh suppressed (min 30s interval)");
      return;
    }

    Logger.log("WeatherService", "Manual refresh: fetching weather data");
    updateTimer.stop();
    _retryAttempt = 0;

    const lat = weatherLocation.latitude;
    const lon = weatherLocation.longitude;

    if (!isNaN(lat) && !isNaN(lon)) {
      _fetchWeather(lat, lon);
    } else {
      Logger.warn("WeatherService", "No coordinates available");
      _fetchGeoLocation();
    }
  }

  function updateWeather() {
    const cached = _loadCachedData();

    if (cached && _isCachedDataFresh()) {
      return;
    }

    if (cached) {
      _fetchWeather(cached.lat, cached.lon);
    } else {
      _fetchGeoLocation();
    }
  }

  Component.onCompleted: {
    Logger.log("WeatherService", "Started");

    // Handle case where Settings is already loaded
    if (Settings.isLoaded) {
      const cached = _loadCachedData();

      if (cached && _isCachedDataFresh()) {
        const age = TimeService.now.getTime() - lastUpdated.getTime();
        const remaining = refreshInterval - age;
        Logger.log("WeatherService", "Next update in", Math.round(remaining / 60000), "min");
        updateTimer.interval = remaining;
        updateTimer.start();
      } else {
        updateTimer.interval = refreshInterval;
        updateTimer.start();
        updateWeather();
      }
    }
  }
  Component.onDestruction: {
    updateTimer.stop();
  }

  Connections {
    function onIsLoadedChanged() {
      if (!Settings.isLoaded)
        return;

      const cached = root._loadCachedData();

      if (cached && root._isCachedDataFresh()) {
        const age = TimeService.now.getTime() - root.lastUpdated.getTime();
        const remaining = root.refreshInterval - age;
        Logger.log("WeatherService", "Next update in", Math.round(remaining / 60000), "min");
        updateTimer.interval = remaining;
        updateTimer.start();
      } else {
        updateTimer.interval = root.refreshInterval;
        updateTimer.start();
        root.updateWeather();
      }
    }

    target: Settings
  }

  Timer {
    id: updateTimer

    interval: root.refreshInterval
    repeat: true

    onTriggered: {
      if (root._isRequesting) {
        Logger.warn("WeatherService", "Request in progress, skipping update");
        return;
      }
      interval = root.refreshInterval;
      root.updateWeather();
    }
  }
}
