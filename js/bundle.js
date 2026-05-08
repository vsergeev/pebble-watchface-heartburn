"use strict";
(() => {
  // src/index.ts
  async function geolocate() {
    return new Promise((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 15e3, maximumAge: 6e4 });
    });
  }
  async function fetch(method, url) {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.onload = function() {
        if (xhr.status === 200) {
          resolve(xhr.response);
        } else {
          reject(xhr.statusText);
        }
      };
      xhr.onerror = function() {
        reject(xhr.statusText);
      };
      xhr.open(method, url);
      xhr.send();
    });
  }
  async function pebbleSendAppMessage(dictionary) {
    return new Promise((resolve, reject) => {
      Pebble.sendAppMessage(dictionary, resolve, reject);
    });
  }
  function mapWeatherCode(code) {
    switch (code) {
      case 0:
      // Clear Sky
      case 1:
        return "Clear";
      case 2:
        return "PartlyCloudy";
      case 3:
        return "Clouds";
      case 45:
      // Fog
      case 48:
        return "Foggy";
      case 51:
      // Drizzle: Light
      case 53:
      // Drizzle: Moderate
      case 55:
      // Drizzle: Dense
      case 56:
        return "Drizzle";
      case 57:
        return "Hail";
      case 61:
        return "Drizzle";
      case 63:
      // Rain: Moderate
      case 65:
        return "Rain";
      case 66:
        return "Drizzle";
      case 67:
        return "Hail";
      case 71:
        return "Snow";
      case 73:
      // Snow Fall: Moderate
      case 75:
        return "HeavySnow";
      case 77:
        return "Snow";
      case 80:
        return "Drizzle";
      case 81:
      // Rain Showers: Moderate
      case 82:
        return "Rain";
      case 85:
        return "Snow";
      case 86:
        return "HeavySnow";
      default:
        return "Unknown";
    }
  }
  async function refreshWeather() {
    try {
      const location = await geolocate();
      const weather = JSON.parse(
        await fetch(
          "GET",
          "https://api.open-meteo.com/v1/forecast?latitude=" + location.coords.latitude + "&longitude=" + location.coords.longitude + "&daily=sunrise,sunset&current=temperature_2m,weather_code&forecast_days=3&temperature_unit=fahrenheit"
        )
      );
      const currentTime = /* @__PURE__ */ new Date();
      await pebbleSendAppMessage({
        WEATHER_CONDITIONS: mapWeatherCode(weather.current.weather_code),
        WEATHER_TEMPERATURE: Math.round(weather.current.temperature_2m),
        WEATHER_SUNRISE: weather.daily.sunrise[weather.daily.sunrise.map((d) => currentTime < /* @__PURE__ */ new Date(d + "Z")).indexOf(true)],
        WEATHER_SUNSET: weather.daily.sunset[weather.daily.sunset.map((d) => currentTime < /* @__PURE__ */ new Date(d + "Z")).indexOf(true)]
      });
    } catch (err) {
      await pebbleSendAppMessage({ WEATHER_ERROR: 1 });
      throw err;
    }
  }
  Pebble.addEventListener("ready", async function(_) {
    try {
      await refreshWeather();
    } catch (err) {
      console.log("Error fetching weather:", err);
    }
  });
  Pebble.addEventListener("appmessage", async function(e) {
    if (e.payload["REQUEST_WEATHER"]) {
      try {
        await refreshWeather();
      } catch (err) {
        console.log("Error fetching weather:", err);
      }
    }
  });
})();
