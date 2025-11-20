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
  // _weatherCodes moved to WeatherCodes.qml

  // Public state
  property string currentTemp: "Loading..."
  property int currentWeatherCode: -1
  property var dailyForecast: null
  readonly property string displayText: {
    const timeAgo = getTimeAgo();
    const stale = isDataStale() ? " [stale]" : "";
    const loc = (includeLocationInDisplay && locationName) ? ` — ${locationName}` : "";
    return `${currentTemp}${loc}${timeAgo ? ` (${timeAgo})` : ""}${stale}`;
  }
  property bool hasError: false
  property bool includeLocationInDisplay: true
  property var lastUpdated: null
  readonly property real latitude: weatherLocation?.latitude ?? NaN
  readonly property string locationName: weatherLocation?.placeName ?? ""
  readonly property real longitude: weatherLocation?.longitude ?? NaN
  readonly property int refreshInterval: 3600000 // 1 hour

  readonly property var weatherLocation: Settings.data.weatherLocation

  function _fetch() {
    if (_isRequesting)
      return;

    const {
      latitude: lat,
      longitude: lon
    } = weatherLocation || {};
    if (lat != null && lon != null && !isNaN(lat) && !isNaN(lon)) {
      _fetchWeather(lat, lon);
    } else {
      _fetchGeoLocation();
    }
  }

  function _fetchGeoLocation() {
    _httpGet("https://ipapi.co/json/", data => {
      const name = [data.city, data.country_name].filter(Boolean).join(", ");
      _saveCache({
        latitude: data.latitude,
        longitude: data.longitude,
        placeName: name
      });
      _fetchWeather(data.latitude, data.longitude);
    }, _handleError);
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
      _retryAttempt = 0;

      _saveCache({
        weatherCode: code,
        temperature: roundedTemp,
        dailyForecast: data.daily,
        lastPollTimestamp: lastUpdated.toISOString()
      });
    }, _handleError);
  }

  function _handleError() {
    hasError = true;
    if (_retryAttempt++ < 2) {
      const delay = 2000 * Math.pow(2, _retryAttempt - 1);
      Logger.warn("WeatherService", `Retry ${_retryAttempt} in ${delay}ms`);
      retryTimer.interval = delay;
      retryTimer.start();
    }
  }

  function _httpGet(url, onSuccess, onError) {
    _isRequesting = true;
    const xhr = new XMLHttpRequest();
    xhr.timeout = 5000;
    xhr.onreadystatechange = () => {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        _isRequesting = false;
        if (xhr.status === 200) {
          try {
            onSuccess(JSON.parse(xhr.responseText));
          } catch (e) {
            onError();
          }
        } else {
          onError();
        }
      }
    };
    xhr.ontimeout = () => {
      _isRequesting = false;
      onError();
    };
    xhr.open("GET", url);
    xhr.send();
  }

  function _init() {
    if (!Settings.isLoaded || !weatherLocation)
      return;

    try {
      const {
        weatherCode,
        lastPollTimestamp,
        temperature,
        dailyForecast: dfStr
      } = weatherLocation;
      if (lastPollTimestamp) {
        lastUpdated = new Date(lastPollTimestamp);
        currentWeatherCode = weatherCode ?? -1;
        currentTemp = `${temperature ?? 0}°C ${WeatherCodes.get(currentWeatherCode).icon}`;
        if (dfStr)
          dailyForecast = JSON.parse(dfStr);

        if ((Date.now() - lastUpdated.getTime()) < refreshInterval) {
          updateTimer.interval = refreshInterval - (Date.now() - lastUpdated.getTime());
          updateTimer.start();
          return;
        }
      }
    } catch (e) {
      Logger.warn("WeatherService", "Cache load failed");
    }

    _fetch();
    updateTimer.interval = refreshInterval;
    updateTimer.start();
  }

  function _saveCache(updates) {
    if (!Settings.isLoaded || !Settings.data.weatherLocation)
      return;
    const target = Settings.data.weatherLocation;
    for (const key in updates) {
      if (key === 'dailyForecast')
        target[key] = JSON.stringify(updates[key]);
      else if (key === 'temperature')
        target[key] = String(updates[key]);
      else
        target[key] = updates[key];
    }
  }

  function getTimeAgo() {
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

  function isDataStale() {
    return lastUpdated && (Date.now() - lastUpdated.getTime()) > refreshInterval * 2;
  }

  function refresh() {
    if (lastUpdated && (Date.now() - lastUpdated.getTime()) < 30000)
      return;
    Logger.log("WeatherService", "Manual refresh");
    _retryAttempt = 0;
    _fetch();
  }

  function weatherInfo(code = currentWeatherCode) {
    return WeatherCodes.get(code);
  }

  Component.onCompleted: if (Settings.isLoaded)
    root._init()

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
