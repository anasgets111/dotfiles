import QtQuick
import QtQuick.Controls


Item {
    property string currentTemp: "Loading..."
    property int refreshInterval: 3600000 // 1 hour in milliseconds
    property var weatherIconMap: ({
           // Severe phenomena
           "tornado":            "🌪️",
           "hurricane":          "🌀",
           "thunderstorm":       "⛈️",
           "thunder":            "⛈️",
           // Precipitation
           "freezing rain":      "🌧️❄️",
           "rain":               "🌧️",
           "drizzle":            "🌦️",
           "sleet":              "🧊",
           "hail":               "🧊",
           // Snow
           "snow shower":        "🌨️",
           "snow":               "❄️",
           // Fog / haze
           "fog":                "🌫️",
           "mist":               "🌫️",
           "haze":               "🌫️",
           // Wind / dust
           "wind":               "🌬️",
           "blustery":           "🌬️",
           "dust":               "🌪️",
           "sand":               "🌪️",
           "ash":                "🌋",
           // Cloudiness / sun
           "clear":              "☀️",
           "sunny":              "☀️",
           "mostly clear":       "🌤️",
           "partly cloudy":      "⛅",
           "cloudy":             "☁️",
           "overcast":           "☁️"
       })
       function getWeatherIcon(cond, t) {
           var lc = cond.toLowerCase()
           // check condition keywords in order
           for (var key in weatherIconMap) {
               if (lc.indexOf(key) !== -1)
                   return weatherIconMap[key]
           }
           // fallback by temperature alone
           if (t >= 35) return "🥵"   // very hot
           if (t >= 30) return "☀️"   // hot
           if (t >= 20) return "🌤️"   // warm
           if (t >= 10) return "⛅"   // mild
           if (t >= 0)  return "☁️"   // cool
           return "🥶"                  // freezing
       }
    Component.onCompleted: {
        updateWeather()
        refreshTimer.start()
    }

    function updateWeather() {
        var geoXhr = new XMLHttpRequest()
        geoXhr.open("GET", "https://ipapi.co/json/")
        geoXhr.onreadystatechange = function() {
            if (geoXhr.readyState !== XMLHttpRequest.DONE) return
            if (geoXhr.status === 200) {
                var ipData = JSON.parse(geoXhr.responseText)
                fetchCurrentTemp(ipData.latitude, ipData.longitude)
            } else {
                currentTemp = "Loc error"
            }
        }
        geoXhr.send()
    }
    Timer {
        id: refreshTimer
        interval: refreshInterval
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: updateWeather()
    }
    function fetchCurrentTemp(lat, lon) {
        var wxXhr = new XMLHttpRequest()
        var url =
            "https://api.open-meteo.com/v1/forecast?latitude=" +
            lat +
            "&longitude=" +
            lon +
            "&current_weather=true&timezone=auto"
        wxXhr.open("GET", url)
        wxXhr.onreadystatechange = function() {
            if (wxXhr.readyState !== XMLHttpRequest.DONE) return
            if (wxXhr.status === 200) {
                var data = JSON.parse(wxXhr.responseText)
                // Use a simple Unicode sun icon as an example. You can enhance this with logic for different weather codes.
                var icon = "☀️ "
                currentTemp = icon + Math.round(data.current_weather.temperature) + "°C"
            } else {
                currentTemp = "Weather error"
            }
        }
        wxXhr.send()
    }
}
