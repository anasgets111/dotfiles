import QtQuick
import QtQuick.Controls

Item {
    id: weatherWidget
    property string currentTemp: "Loading..."
    property int refreshInterval: 3.6e+06 // 1 hour in milliseconds
    property real latitude: NaN
    property real longitude: NaN
    property string locationName: ""
    property int currentWeatherCode: -1
    property var weatherIconMap: ({
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

    function getWeatherIconFromCode() {
        if (weatherIconMap.hasOwnProperty(currentWeatherCode))
            return weatherIconMap[currentWeatherCode].icon;

        return "❓";
    }

    function getWeatherDescriptionFromCode() {
        if (weatherIconMap.hasOwnProperty(currentWeatherCode))
            return weatherIconMap[currentWeatherCode].desc;

        return "Unknown";
    }

    function getWeatherIconAndDesc(code) {
        if (weatherIconMap.hasOwnProperty(code))
            return weatherIconMap[code];

        return {
            "icon": "❓",
            "desc": "Unknown"
        };
    }

    function updateWeather() {
        if (isNaN(latitude) || isNaN(longitude)) {
            var geoXhr = new XMLHttpRequest();
            geoXhr.open("GET", "https://ipapi.co/json/");
            geoXhr.onreadystatechange = function () {
                if (geoXhr.readyState !== XMLHttpRequest.DONE)
                    return;

                if (geoXhr.status === 200) {
                    var ipData = JSON.parse(geoXhr.responseText);
                    latitude = ipData.latitude;
                    longitude = ipData.longitude;
                    // Compose a readable location string
                    locationName = ipData.city + ", " + ipData.country_name;
                    fetchCurrentTemp(latitude, longitude);
                } else {
                    currentTemp = "Loc error";
                    locationName = "";
                }
            };
            geoXhr.send();
        } else {
            // Use cached coordinates
            fetchCurrentTemp(latitude, longitude);
        }
    }

    function fetchCurrentTemp(lat, lon) {
        var wxXhr = new XMLHttpRequest();
        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon + "&current_weather=true&timezone=auto";
        wxXhr.open("GET", url);
        wxXhr.onreadystatechange = function () {
            if (wxXhr.readyState !== XMLHttpRequest.DONE)
                return;

            if (wxXhr.status === 200) {
                var data = JSON.parse(wxXhr.responseText);
                currentWeatherCode = data.current_weather.weathercode;
                var icon = getWeatherIconFromCode();
                currentTemp = Math.round(data.current_weather.temperature) + "°C" + ' ' + icon;
            } else {
                currentTemp = "Weather error";
            }
        };
        wxXhr.send();
    }

    Component.onCompleted: {
        updateWeather();
        weatherTimer.start();
    }

    Timer {
        id: weatherTimer

        interval: weatherWidget.refreshInterval
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: weatherWidget.updateWeather()
    }
}
