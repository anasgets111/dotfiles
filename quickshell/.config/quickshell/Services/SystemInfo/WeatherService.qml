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
  property bool _requesting: false
  property int _retryCount: 0

  // Public state
  property string currentTemp: "Loading..."
  property int currentWeatherCode: -1
  property var dailyForecast: null
  readonly property string displayText: {
    const parts = [currentTemp];
    if (includeLocationInDisplay && locationName)
      parts.push(`— ${locationName}`);
    const ago = _timeAgo();
    if (ago)
      parts.push(`(${ago})`);
    if (_isStale())
      parts.push("[stale]");
    return parts.join(" ");
  }
  property bool hasError: false
  property bool includeLocationInDisplay: true
  property var lastUpdated: null
  readonly property real latitude: weatherLocation?.latitude ?? NaN
  readonly property string locationName: weatherLocation?.placeName ?? ""
  readonly property real longitude: weatherLocation?.longitude ?? NaN
  readonly property int refreshInterval: 3600000 // 1 hour
  readonly property string timeAgo: _timeAgo()
  readonly property var weatherLocation: Settings.data.weatherLocation

  function _fetch() {
    if (_requesting)
      return;
    const loc = weatherLocation;
    if (loc?.latitude != null && loc?.longitude != null && !isNaN(loc.latitude) && !isNaN(loc.longitude))
      _fetchWeather(loc.latitude, loc.longitude);
    else
      _fetchGeoLocation();
  }

  function _fetchGeoLocation() {
    _httpGet("https://ipapi.co/json/", data => {
      const loc = weatherLocation;
      if (loc) {
        loc.latitude = data.latitude;
        loc.longitude = data.longitude;
        loc.placeName = [data.city, data.country_name].filter(Boolean).join(", ");
      }
      _fetchWeather(data.latitude, data.longitude);
    });
  }

  function _fetchWeather(lat, lon) {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current_weather=true&timezone=auto&forecast_days=10&past_days=1&daily=temperature_2m_max,temperature_2m_min,weathercode`;
    _httpGet(url, data => {
      if (!data.current_weather)
        throw new Error("No weather data");

      const {
        weathercode: code,
        temperature: temp
      } = data.current_weather;
      const roundedTemp = Math.round(temp);

      currentWeatherCode = code;
      currentTemp = `${roundedTemp}°C ${WeatherCodes.get(code).icon}`;
      dailyForecast = data.daily;
      lastUpdated = new Date();
      hasError = false;
      _retryCount = 0;

      // Persist to settings
      const loc = weatherLocation;
      if (loc) {
        loc.weatherCode = code;
        loc.temperature = String(roundedTemp);
        loc.dailyForecast = JSON.stringify(data.daily);
        loc.lastPollTimestamp = lastUpdated.toISOString();
      }
    });
  }

  function _handleError() {
    hasError = true;
    if (_retryCount++ < 2) {
      const delay = 2000 * Math.pow(2, _retryCount - 1);
      Logger.warn("WeatherService", `Retry ${_retryCount} in ${delay}ms`);
      retryTimer.interval = delay;
      retryTimer.start();
    }
  }

  function _httpGet(url, onSuccess) {
    _requesting = true;
    const xhr = new XMLHttpRequest();
    xhr.timeout = 5000;
    xhr.onreadystatechange = () => {
      if (xhr.readyState !== XMLHttpRequest.DONE)
        return;
      _requesting = false;
      if (xhr.status !== 200) {
        _handleError();
        return;
      }
      try {
        onSuccess(JSON.parse(xhr.responseText));
      } catch (e) {
        _handleError();
      }
    };
    xhr.ontimeout = () => {
      _requesting = false;
      _handleError();
    };
    xhr.open("GET", url);
    xhr.send();
  }

  function _init() {
    if (!Settings.isLoaded || !weatherLocation)
      return;

    const loc = weatherLocation;
    if (loc.lastPollTimestamp) {
      try {
        lastUpdated = new Date(loc.lastPollTimestamp);
        currentWeatherCode = loc.weatherCode ?? -1;
        currentTemp = `${loc.temperature ?? 0}°C ${WeatherCodes.get(currentWeatherCode).icon}`;
        if (loc.dailyForecast)
          dailyForecast = JSON.parse(loc.dailyForecast);

        const elapsed = Date.now() - lastUpdated.getTime();
        if (elapsed < refreshInterval) {
          updateTimer.interval = refreshInterval - elapsed;
          updateTimer.start();
          return;
        }
      } catch (e) {
        Logger.warn("WeatherService", "Cache load failed");
      }
    }

    _fetch();
    updateTimer.interval = refreshInterval;
    updateTimer.start();
  }

  function _isStale() {
    return lastUpdated && (Date.now() - lastUpdated.getTime()) > refreshInterval * 2;
  }

  function _timeAgo() {
    if (!lastUpdated)
      return "";
    const diff = (TimeService.now.getTime() - lastUpdated.getTime()) / 1000;
    if (diff < 60)
      return "just now";
    if (diff < 3600)
      return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400)
      return `${Math.floor(diff / 3600)}h ago`;
    return `${Math.floor(diff / 86400)}d ago`;
  }

  function refresh() {
    if (lastUpdated && (Date.now() - lastUpdated.getTime()) < 30000)
      return;
    Logger.log("WeatherService", "Manual refresh");
    _retryCount = 0;
    _fetch();
  }

  function weatherInfo(code = currentWeatherCode) {
    return WeatherCodes.get(code);
  }

  Component.onCompleted: if (Settings.isLoaded)
    _init()

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
      interval = root.refreshInterval;
      root._fetch();
    }
  }

  Timer {
    id: retryTimer

    repeat: false

    onTriggered: root._fetch()
  }
}
