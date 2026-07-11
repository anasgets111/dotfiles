pragma Singleton
import QtQuick
import Quickshell
import qs.Config
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: root

  property bool _initialized: false
  property bool _requestInFlight: false
  property int _retryCount: 0
  property string currentTemp: "Loading..."
  property int currentWeatherCode: -1
  property var dailyForecast: null
  property bool hasError: false
  property var lastUpdated: null
  readonly property real latitude: weatherLocation?.latitude ?? NaN
  readonly property string locationName: weatherLocation?.placeName ?? ""
  readonly property real longitude: weatherLocation?.longitude ?? NaN
  readonly property int refreshInterval: 60 * 60 * 1000
  readonly property string timeAgo: _formatTimeAgo()
  readonly property var weatherCache: Settings.state.weather
  readonly property var weatherLocation: Settings.data.weatherLocation

  function _applyWeatherData(responseData: var): void {
    const currentWeather = responseData?.current_weather;
    if (!currentWeather)
      throw new Error("No weather data");
    const weatherCode = currentWeather.weathercode ?? -1;
    const roundedTemperature = Math.round(currentWeather.temperature ?? 0);
    const cacheEntry = weatherCache;
    currentWeatherCode = weatherCode;
    currentTemp = `${roundedTemperature}°C ${WeatherCodes.get(weatherCode).icon}`;
    dailyForecast = responseData.daily ?? null;
    lastUpdated = new Date();
    hasError = false;
    _retryCount = 0;
    if (!cacheEntry)
      return;
    cacheEntry.weatherCode = weatherCode;
    cacheEntry.temperature = String(roundedTemperature);
    cacheEntry.dailyForecast = dailyForecast ? JSON.stringify(dailyForecast) : "";
    cacheEntry.lastPollTimestamp = lastUpdated.toISOString();
  }

  function _fetch(): void {
    if (_requestInFlight)
      return;
    if (_hasCoordinates(latitude, longitude)) {
      _fetchWeather(latitude, longitude);
      return;
    }
    _fetchGeoLocation();
  }

  function _fetchGeoLocation(): void {
    _httpGet("https://ipapi.co/json/", data => {
      const resolvedLatitude = data?.latitude;
      const resolvedLongitude = data?.longitude;
      if (!_hasCoordinates(resolvedLatitude, resolvedLongitude))
        throw new Error("No geolocation coordinates");
      if (weatherLocation) {
        weatherLocation.latitude = resolvedLatitude;
        weatherLocation.longitude = resolvedLongitude;
        weatherLocation.placeName = [data.city, data.country_name].filter(Boolean).join(", ");
      }
      _fetchWeather(resolvedLatitude, resolvedLongitude);
    });
  }

  function _fetchWeather(requestLatitude: real, requestLongitude: real): void {
    const requestUrl = "https://api.open-meteo.com/v1/forecast" + `?latitude=${requestLatitude}` + `&longitude=${requestLongitude}` + "&current_weather=true" + "&timezone=auto" + "&forecast_days=10" + "&past_days=1" + "&daily=temperature_2m_max,temperature_2m_min,weathercode";
    _httpGet(requestUrl, data => _applyWeatherData(data));
  }

  function _formatTimeAgo(): string {
    if (!lastUpdated)
      return "";
    const elapsedSeconds = Math.max(0, Math.floor((TimeService.minuteNow.getTime() - lastUpdated.getTime()) / 1000));
    if (elapsedSeconds < 60)
      return "just now";
    if (elapsedSeconds < 60 * 60)
      return `${Math.floor(elapsedSeconds / 60)}m ago`;
    if (elapsedSeconds < 24 * 60 * 60)
      return `${Math.floor(elapsedSeconds / (60 * 60))}h ago`;
    return `${Math.floor(elapsedSeconds / (24 * 60 * 60))}d ago`;
  }

  function _handleRequestError(): void {
    hasError = true;
    if (_retryCount >= 2)
      return;
    _retryCount += 1;
    const retryDelay = 2000 * Math.pow(2, _retryCount - 1);
    Logger.warn("WeatherService", `Retry ${_retryCount} in ${retryDelay}ms`);
    retryTimer.interval = retryDelay;
    retryTimer.start();
  }

  function _hasCoordinates(candidateLatitude: real, candidateLongitude: real): bool {
    return candidateLatitude != null && candidateLongitude != null && !isNaN(candidateLatitude) && !isNaN(candidateLongitude);
  }

  function _httpGet(url: string, onSuccess: var): void {
    _requestInFlight = true;
    const request = new XMLHttpRequest();
    let requestFinished = false;
    const finishRequest = () => {
      if (requestFinished)
        return false;
      requestFinished = true;
      _requestInFlight = false;
      return true;
    };
    request.timeout = 5000;
    request.onreadystatechange = () => {
      if (request.readyState !== XMLHttpRequest.DONE || !finishRequest())
        return;
      if (request.status !== 200) {
        _handleRequestError();
        return;
      }
      try {
        onSuccess(JSON.parse(request.responseText));
      } catch (error) {
        Logger.warn("WeatherService", `Request handling failed: ${error}`);
        _handleRequestError();
      }
    };
    request.onerror = () => {
      if (finishRequest())
        _handleRequestError();
    };
    request.ontimeout = () => {
      if (finishRequest())
        _handleRequestError();
    };
    request.open("GET", url);
    request.send();
  }

  function _init(): void {
    if (_initialized || !Settings.isLoaded || !Settings.isStateLoaded || !weatherLocation)
      return;
    _initialized = true;
    const cacheEntry = weatherCache;
    if (cacheEntry?.lastPollTimestamp) {
      try {
        const cachedTimestamp = new Date(cacheEntry.lastPollTimestamp);
        if (!isNaN(cachedTimestamp.getTime())) {
          lastUpdated = cachedTimestamp;
          currentWeatherCode = cacheEntry.weatherCode ?? -1;
          currentTemp = `${cacheEntry.temperature ?? 0}°C ${WeatherCodes.get(currentWeatherCode).icon}`;
          dailyForecast = cacheEntry.dailyForecast ? JSON.parse(cacheEntry.dailyForecast) : null;

          const elapsedMs = Date.now() - cachedTimestamp.getTime();
          if (elapsedMs < refreshInterval) {
            updateTimer.interval = refreshInterval - elapsedMs;
            updateTimer.start();
            return;
          }
        }
      } catch (error) {
        Logger.warn("WeatherService", `Cache load failed: ${error}`);
      }
    }
    _fetch();
    updateTimer.interval = refreshInterval;
    updateTimer.start();
  }

  function refresh(): void {
    if (lastUpdated && (Date.now() - lastUpdated.getTime()) < 30 * 1000)
      return;
    Logger.log("WeatherService", "Manual refresh");
    _retryCount = 0;
    retryTimer.stop();
    _fetch();
  }

  function weatherInfo(code = currentWeatherCode): var {
    return WeatherCodes.get(code);
  }

  Component.onCompleted: if (Settings.isLoaded && Settings.isStateLoaded)
    _init()

  Connections {
    function onIsLoadedChanged(): void {
      if (Settings.isLoaded && Settings.isStateLoaded)
        root._init();
    }

    function onIsStateLoadedChanged(): void {
      if (Settings.isLoaded && Settings.isStateLoaded)
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
