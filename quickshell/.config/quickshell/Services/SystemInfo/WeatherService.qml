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
  property int _retryAttempt: 0

  // Constants
  readonly property var _weatherCodes: ({
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

  // Public state
  property string currentTemp: "Loading..."
  property int currentWeatherCode: -1
  readonly property string displayText: {
    const timeAgo = getTimeAgo();
    const stale = isDataStale() ? " [stale]" : "";
    const location = includeLocationInDisplay && locationName ? ` — ${locationName}` : "";
    const time = timeAgo ? ` (${timeAgo})` : "";
    return `${currentTemp}${location}${time}${stale}`;
  }
  property bool hasError: false
  property bool includeLocationInDisplay: true
  property var lastUpdated: null
  readonly property real latitude: weatherLocation?.latitude ?? NaN
  readonly property string locationName: weatherLocation?.placeName ?? ""
  readonly property real longitude: weatherLocation?.longitude ?? NaN
  property int maxRetries: 2
  readonly property int refreshInterval: 3.6e+06 // 1 hour
  readonly property var weatherLocation: Settings.data.weatherLocation

  function _fetchGeoLocation() {
    _httpGet("https://ipapi.co/json/", data => {
      const name = `${data.city || ""}${data.country_name ? ", " + data.country_name : ""}`;
      _saveCache({
        latitude: data.latitude,
        longitude: data.longitude,
        placeName: name
      });
      _fetchWeather(data.latitude, data.longitude);
    }, () => {
      Logger.warn("WeatherService", "IP geo failed");
      const {
        latitude: lat,
        longitude: lon
      } = weatherLocation;
      if (lat != null && lon != null && !isNaN(lat) && !isNaN(lon)) {
        _fetchWeather(lat, lon);
      } else {
        hasError = true;
        currentTemp = "Location unavailable";
      }
    });
  }

  function _fetchWeather(lat, lon) {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current_weather=true&timezone=auto`;
    _httpGet(url, data => {
      if (!data.current_weather)
        throw new Error("Missing current_weather");

      const {
        weathercode: code,
        temperature: temp
      } = data.current_weather;
      const roundedTemp = Math.round(temp);
      currentWeatherCode = code;
      currentTemp = `${roundedTemp}°C ${weatherInfo(code).icon}`;
      lastUpdated = new Date();
      hasError = false;
      _retryAttempt = 0;

      _saveCache({
        weatherCode: code,
        temperature: roundedTemp,
        lastPollTimestamp: lastUpdated.toISOString()
      });
      retryTimer.stop();
      updateTimer.interval = refreshInterval;
      updateTimer.restart();
    }, () => {
      Logger.warn("WeatherService", "Weather fetch failed");
      _handleError();
    });
  }

  function _handleError() {
    hasError = true;
    if (_retryAttempt < maxRetries) {
      _retryAttempt++;
      const delay = 2000 * Math.pow(2, _retryAttempt - 1);
      Logger.warn("WeatherService", `Retry ${_retryAttempt} in ${delay}ms`);
      retryTimer.interval = delay;
      retryTimer.start();
    } else {
      Logger.warn("WeatherService", "Max retries reached");
      _retryAttempt = 0;
    }
  }

  function _httpGet(url, onSuccess, onError) {
    if (_isRequesting) {
      Logger.warn("WeatherService", "Request in progress, ignoring");
      return;
    }
    _isRequesting = true;
    const xhr = new XMLHttpRequest();
    xhr.timeout = 5000;

    const cleanup = () => {
      xhr.onreadystatechange = null;
      xhr.ontimeout = null;
      _isRequesting = false;
    };

    xhr.onreadystatechange = () => {
      if (xhr.readyState !== XMLHttpRequest.DONE)
        return;
      cleanup();
      if (xhr.status === 200) {
        try {
          onSuccess(JSON.parse(xhr.responseText));
        } catch (e) {
          Logger.warn("WeatherService", "Parse error:", e.message);
          onError();
        }
      } else {
        Logger.warn("WeatherService", "HTTP status:", xhr.status);
        onError();
      }
    };

    xhr.ontimeout = () => {
      cleanup();
      Logger.warn("WeatherService", "Timeout");
      onError();
    };

    xhr.open("GET", url);
    xhr.send();
  }

  function _init() {
    const cache = _loadCache();
    if (cache?.valid) {
      const age = TimeService.now.getTime() - lastUpdated.getTime();
      const remaining = refreshInterval - age;
      if (remaining < 60000) {
        Logger.log("WeatherService", "Cache almost stale, fetching now");
        updateTimer.interval = refreshInterval;
        updateTimer.start();
        _fetchWeather(cache.lat, cache.lon);
      } else {
        Logger.log("WeatherService", `Next update in ${Math.round(remaining / 60000)} min`);
        updateTimer.interval = remaining;
        updateTimer.start();
      }
    } else {
      updateTimer.interval = refreshInterval;
      updateTimer.start();
      cache ? _fetchWeather(cache.lat, cache.lon) : _fetchGeoLocation();
    }
  }

  function _loadCache() {
    if (!Settings.isLoaded || !weatherLocation)
      return null;
    try {
      const {
        latitude: lat,
        longitude: lon,
        weatherCode: code,
        lastPollTimestamp: timestamp,
        temperature: temp = 0
      } = weatherLocation;
      if (lat == null || lon == null || code == null || !timestamp || isNaN(lat) || isNaN(lon) || isNaN(code))
        return null;

      currentWeatherCode = code;
      lastUpdated = new Date(timestamp);
      currentTemp = `${temp}°C ${weatherInfo(code).icon}`;

      const isFresh = (TimeService.now.getTime() - lastUpdated.getTime()) < refreshInterval;
      return {
        valid: isFresh,
        lat,
        lon
      };
    } catch (e) {
      Logger.warn("WeatherService", "Cache load failed:", e.message);
      return null;
    }
  }

  function _saveCache(updates) {
    if (!Settings.isLoaded) return;
    // Ensure weatherLocation exists in Settings before modifying
    if (!Settings.data.weatherLocation) {
      Settings.data.weatherLocation = {};
    }
    Object.assign(Settings.data.weatherLocation, updates);
  }

  function getTimeAgo() {
    if (!lastUpdated)
      return "";
    const diff = TimeService.now.getTime() - lastUpdated.getTime();
    const days = Math.floor(diff / 86400000);
    const hours = Math.floor(diff / 3600000);
    const mins = Math.floor(diff / 60000);
    return days > 0 ? `${days} day${days > 1 ? 's' : ''} ago` : hours > 0 ? `${hours} hour${hours > 1 ? 's' : ''} ago` : mins > 0 ? `${mins} minute${mins > 1 ? 's' : ''} ago` : "just now";
  }

  function isDataStale() {
    return lastUpdated ? (Date.now() - lastUpdated.getTime()) > refreshInterval * 2 : false;
  }

  function refresh() {
    if (lastUpdated && (Date.now() - lastUpdated.getTime()) < 30000) {
      Logger.log("WeatherService", "Manual refresh suppressed (30s cooldown)");
      return;
    }
    Logger.log("WeatherService", "Manual refresh");
    _retryAttempt = 0;
    updateTimer.stop();
    const {
      latitude: lat,
      longitude: lon
    } = weatherLocation;
    (!isNaN(lat) && !isNaN(lon)) ? _fetchWeather(lat, lon) : _fetchGeoLocation();
  }

  function weatherInfo(code = currentWeatherCode) {
    return _weatherCodes[String(code)] || {
      icon: "❓",
      desc: "Unknown"
    };
  }

  Component.onCompleted: {
    Logger.log("WeatherService", "Started");
    if (Settings.isLoaded)
      _init();
  }
  Component.onDestruction: {
    updateTimer.stop();
    retryTimer.stop();
    // Clear references for cleanup
    lastUpdated = null;
    _isRequesting = false;
  }

  Connections {
    function onIsLoadedChanged() {
      if (Settings.isLoaded)
        root._init();
    }

    target: Settings
  }

  Timer {
    id: updateTimer

    interval: root.refreshInterval
    repeat: true

    onTriggered: {
      if (root._isRequesting) {
        Logger.warn("WeatherService", "Request in progress, skipping");
        return;
      }
      interval = root.refreshInterval;
      const cache = root._loadCache();
      cache ? root._fetchWeather(cache.lat, cache.lon) : root._fetchGeoLocation();
    }
  }

  Timer {
    id: retryTimer

    interval: 2000
    repeat: false

    onTriggered: {
      if (root._isRequesting) {
        Logger.warn("WeatherService", "Retry skipped, request in progress");
        return;
      }
      const cache = root._loadCache();
      cache ? root._fetchWeather(cache.lat, cache.lon) : root._fetchGeoLocation();
    }
  }
}
