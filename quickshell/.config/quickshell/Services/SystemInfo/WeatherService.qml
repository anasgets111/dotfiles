pragma Singleton
import QtQml
import QtQuick
import Quickshell
import qs.Services.Utils

Singleton {
    id: weatherService

    readonly property string openMeteoUrlBase: "https://api.open-meteo.com/v1/forecast"
    readonly property string ipGeoUrl: "https://ipapi.co/json/"
    readonly property int defaultRefreshMs: 3600000 // 1 hour
    readonly property int geoTimeoutMs: 4000
    readonly property int wxTimeoutMs: 5000
    readonly property int defaultRetryDelayMs: 2000

    readonly property real fallbackLat: 30.0507
    readonly property real fallbackLon: 31.2489
    readonly property string fallbackLocationName: ""

    readonly property bool isStale: lastUpdated ? (Date.now() - lastUpdated.getTime()) > staleAfterMs : false
    readonly property int staleAfterMs: refreshInterval * 2
    property int maxRetries: 2
    property int retryDelayMs: defaultRetryDelayMs
    property bool hasError: false
    property int consecutiveErrors: 0
    property var lastUpdated: null

    property int _wxAttempt: 0
    property string _pendingRetry: ""
    property bool _fallbackApplied: false
    property bool includeLocationInDisplay: true
    readonly property string displayText: currentTemp + (includeLocationInDisplay && locationName ? " — " + locationName : "") + (isStale ? " (stale)" : "")
    property string currentTemp: "Loading..."
    property int refreshInterval: defaultRefreshMs
    property real latitude: NaN
    property real longitude: NaN
    property string locationName: ""
    property int currentWeatherCode: -1

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

    PersistentProperties {
        id: persist
        reloadableId: "WeatherService"
        property string savedLocationJson: "{}"

        function hydrate() {
            Logger.log("WeatherService", "persist snapshot:", persist.savedLocationJson);

            try {
                const obj = JSON.parse(persist.savedLocationJson || "{}");
                const lat = Number(obj.lat);
                const lon = Number(obj.lon);
                const name = (obj.name === undefined || obj.name === null) ? "" : String(obj.name);
                if (!isNaN(lat) && !isNaN(lon)) {
                    weatherService.latitude = lat;
                    weatherService.longitude = lon;
                    weatherService.locationName = name;
                }
            } catch (e) {}

            weatherService.startServiceOnce();
        }

        onLoaded: hydrate()
        onReloaded: hydrate()
    }

    function getWeatherIconFromCode() {
        return getWeatherIconAndDesc(currentWeatherCode).icon;
    }

    function getWeatherDescriptionFromCode() {
        return getWeatherIconAndDesc(currentWeatherCode).desc;
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

    function updateWeather() {
        var hasPersist = false;
        var savedLat = NaN, savedLon = NaN, savedName = "";
        try {
            const obj0 = JSON.parse(persist.savedLocationJson || "{}");
            savedLat = Number(obj0.lat);
            savedLon = Number(obj0.lon);
            savedName = (obj0.name === undefined || obj0.name === null) ? "" : String(obj0.name);
            hasPersist = (!isNaN(savedLat) && !isNaN(savedLon));
        } catch (e) {}
        Logger.log("WeatherService", "updateWeather: hasPersist=", hasPersist, "lat=", latitude, "lon=", longitude);
        if (isNaN(latitude) || isNaN(longitude)) {
            // Prefer persisted coordinates if available
            if (hasPersist) {
                latitude = savedLat;
                longitude = savedLon;
                locationName = savedName;
                Logger.log("WeatherService", "Using persisted coords:", latitude + "," + longitude, "name=", locationName);
                fetchCurrentTemp(latitude, longitude);
                return;
            }

            var geoXhr = new XMLHttpRequest();
            geoXhr.open("GET", ipGeoUrl);
            geoXhr.timeout = geoTimeoutMs;
            Logger.log("WeatherService", "IP geo request start:", ipGeoUrl, "timeout=", geoTimeoutMs, "ms");
            geoXhr.onreadystatechange = function () {
                if (geoXhr.readyState !== 4)
                    return;

                if (geoXhr.status === 200) {
                    try {
                        var ipData = JSON.parse(geoXhr.responseText);
                        latitude = ipData.latitude;
                        longitude = ipData.longitude;
                        locationName = (ipData.city || "") + (ipData.country_name ? ", " + ipData.country_name : "");
                        persist.savedLocationJson = JSON.stringify({
                            lat: latitude,
                            lon: longitude,
                            name: locationName
                        });

                        hasError = false;
                        Logger.log("WeatherService", "IP geo success:", latitude + "," + longitude, "name=", locationName);
                        fetchCurrentTemp(latitude, longitude);
                    } catch (e) {
                        Logger.warn("WeatherService", "failed to parse IP geo response");
                        applyFallbackCoords();
                    }
                } else {
                    Logger.warn("WeatherService", "IP geo failed with status", geoXhr.status);
                    applyFallbackCoords();
                }
            };
            geoXhr.ontimeout = function () {
                Logger.warn("WeatherService", "IP geo request timed out");
                applyFallbackCoords();
            };
            geoXhr.send();
        } else {
            Logger.log("WeatherService", "Using existing coords:", latitude + "," + longitude, "name=", locationName);
            fetchCurrentTemp(latitude, longitude);
        }
    }

    function applyFallbackCoords() {
        if (_fallbackApplied)
            return;
        latitude = fallbackLat;
        longitude = fallbackLon;
        locationName = fallbackLocationName || (fallbackLat + ", " + fallbackLon);
        persist.savedLocationJson = JSON.stringify({
            lat: latitude,
            lon: longitude,
            name: locationName
        });
        _fallbackApplied = true;
        hasError = false;
        Logger.warn("WeatherService", "Applying fallback coords:", latitude + "," + longitude, "name=", locationName);
        fetchCurrentTemp(latitude, longitude);
    }

    function fetchCurrentTemp(lat, lon) {
        var wxXhr = new XMLHttpRequest();
        var url = openMeteoUrlBase + "?latitude=" + lat + "&longitude=" + lon + "&current_weather=true&timezone=auto";
        wxXhr.open("GET", url);
        wxXhr.timeout = wxTimeoutMs;
        Logger.log("WeatherService", "Weather request start:", url, "timeout=", wxTimeoutMs, "ms");
        wxXhr.onreadystatechange = function () {
            if (wxXhr.readyState !== 4)
                return;

            if (wxXhr.status === 200) {
                try {
                    var data = JSON.parse(wxXhr.responseText);
                    if (data && data.current_weather) {
                        currentWeatherCode = data.current_weather.weathercode;
                        currentTemp = Math.round(data.current_weather.temperature) + "°C" + ' ' + getWeatherIconFromCode();
                        lastUpdated = new Date();
                        hasError = false;
                        consecutiveErrors = 0;
                        _wxAttempt = 0;
                        Logger.log("WeatherService", "Weather success: temp=", currentTemp, "code=", currentWeatherCode);
                    } else {
                        Logger.warn("WeatherService", "response missing current_weather");
                        scheduleWxRetry();
                    }
                } catch (e) {
                    Logger.warn("WeatherService", "failed to parse weather response");
                    scheduleWxRetry();
                }
            } else {
                Logger.warn("WeatherService", "fetch failed with status", wxXhr.status);
                scheduleWxRetry();
            }
        };
        wxXhr.ontimeout = function () {
            Logger.warn("WeatherService", "fetch timed out");
            scheduleWxRetry();
        };
        wxXhr.send();
    }

    function scheduleWxRetry() {
        hasError = true;
        consecutiveErrors++;
        if (_wxAttempt < maxRetries) {
            _wxAttempt++;
            _pendingRetry = "wx";
            retryTimer.interval = retryDelayMs * _wxAttempt;
            Logger.warn("WeatherService", "Scheduling retry:", _wxAttempt, "in", retryTimer.interval, "ms");
            retryTimer.start();
        }
    }

    // --- Timers ----------------------------------------------------------
    Timer {
        id: weatherTimer
        interval: weatherService.refreshInterval
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: weatherService.updateWeather()
    }

    Timer {
        id: retryTimer
        interval: 0
        repeat: false
        running: false
        triggeredOnStart: false
        onTriggered: {
            Logger.log("WeatherService", "Retry timer triggered; pending=", weatherService._pendingRetry);
            if (weatherService._pendingRetry === "wx") {
                if (!isNaN(weatherService.latitude) && !isNaN(weatherService.longitude))
                    weatherService.fetchCurrentTemp(weatherService.latitude, weatherService.longitude);
                else
                    weatherService.updateWeather();
            }
            weatherService._pendingRetry = "";
        }
    }

    function startServiceOnce() {
        if (!weatherTimer.running) {
            weatherTimer.start();
            Logger.log("WeatherService", "Service started; interval=", weatherService.refreshInterval, "ms");
            updateWeather();
        }
    }

    Component.onCompleted: startServiceOnce()
}
