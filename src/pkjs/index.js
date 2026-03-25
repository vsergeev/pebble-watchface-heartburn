// pebble-watchface-heartburn v0.1
// https://github.com/vsergeev/pebble-watchface-heartburn

////////////////////////////////////////////////////////////////////////////////
// Helpers
////////////////////////////////////////////////////////////////////////////////

function geolocate() {
  return new Promise((resolve, reject) => {
    navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 15000, maximumAge: 60000 });
  });
}

function fetch(method, url) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.onload = function () {
      if (xhr.status == 200) {
        resolve(xhr.response);
      } else {
        reject(xhr.statusText);
      }
    };
    xhr.onerror = function () {
      reject(xhr.statusText);
    };
    xhr.open(method, url);
    xhr.send();
  });
}

function pebbleSendAppMessage(dictionary) {
  return new Promise((resolve, reject) => {
    Pebble.sendAppMessage(dictionary, resolve, reject);
  });
}

////////////////////////////////////////////////////////////////////////////////
// Weather Fetch
////////////////////////////////////////////////////////////////////////////////

function mapWeatherCode(code) {
  switch (code) {
    case 0: // Clear Sky
    case 1: // Mainly Clear
      return "Clear";
    case 2: // Partly Cloudy
      return "PartlyCloudy";
    case 3: // Overcast
      return "Clouds";
    case 45: // Fog
    case 48: // Depositing Rime Fog
      return "Foggy";
    case 51: // Drizzle: Light
    case 53: // Drizzle: Moderate
    case 55: // Drizzle: Dense
    case 56: // Freezing Drizzle: Light
      return "Drizzle";
    case 57: // Freezing Drizzle: Dense
      return "Hail";
    case 61: // Rain: Slight
      return "Drizzle";
    case 63: // Rain: Moderate
    case 65: // Rain: Heavy
      return "Rain";
    case 66: // Freezing Rain: Light
      return "Drizzle";
    case 67: // Freezing Rain: Heavy
      return "Hail";
    case 71: // Snow Fall: Slight
      return "Snow";
    case 73: // Snow Fall: Moderate
    case 75: // Snow Fall: Heavy
      return "HeavySnow";
    case 77: // Snow Grains
      return "Snow";
    case 80: // Rain Showers: Slight
      return "Drizzle";
    case 81: // Rain Showers: Moderate
    case 82: // Rain Showers: Violent
      return "Rain";
    case 85: // Snow Showers: Slight
      return "Snow";
    case 86: // Snow Showers: Heavy
      return "HeavySnow";
    default:
      return "Unknown";
  }
}

function refreshWeather() {
  return geolocate()
    .then((pos) => {
      return fetch("GET", "https://api.open-meteo.com/v1/forecast?latitude=" + pos.coords.latitude + "&longitude=" + pos.coords.longitude + "&daily=sunrise,sunset&current=temperature_2m,weather_code&forecast_days=3&temperature_unit=fahrenheit");
    })
    .then((response) => JSON.parse(response))
    .then((response) => {
      const currentTime = new Date();

      return pebbleSendAppMessage({
        "WEATHER_CONDITIONS": mapWeatherCode(response.current.weather_code),
        "WEATHER_TEMPERATURE": Math.round(response.current.temperature_2m),
        "WEATHER_SUNRISE": response.daily.sunrise[response.daily.sunrise.map((d) => currentTime < new Date(d + "Z")).indexOf(true)],
        "WEATHER_SUNSET": response.daily.sunset[response.daily.sunset.map((d) => currentTime < new Date(d + "Z")).indexOf(true)],
      });
    })
    .catch((err) => {
      pebbleSendAppMessage({"WEATHER_ERROR": 1});
      throw err;
    });
}

////////////////////////////////////////////////////////////////////////////////
// Event Listeners
////////////////////////////////////////////////////////////////////////////////

Pebble.addEventListener('ready',
  function(e) {
    refreshWeather().catch((e) => console.log('Error fetching weather:', e));
  }
);

Pebble.addEventListener('appmessage',
  function(e) {
    if (e.payload['REQUEST_WEATHER']) {
      refreshWeather().catch((e) => console.log('Error fetching weather:', e));
    }
  }
);
