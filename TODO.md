# Sylph delivery checklist

## Fix live-data failure and offline behavior

- [ ] Replace the current raw nested socket exception path with readable, actionable error states for no network, DNS/socket failure, timeout, invalid key, unknown city, and server failure.
- [ ] Retry transient weather requests without showing intermediate implementation details to the user.
- [ ] Keep the last successful weather response locally and show it as stale data when a new request cannot reach the service.
- [ ] Treat AQI as optional and keep the weather result usable when WAQI is unavailable.
- [ ] Parse the WAQI response shape correctly so a successful AQI response is displayed.

## Tactile liquid-glass home dashboard

- [ ] Keep Boldonse and DM Sans exactly as the current app fonts.
- [ ] Add the animated atmospheric backdrop, translucent liquid-glass surfaces, tactile press feedback, and calm entrance/loading motion.
- [ ] Provide the home widgets for temperature/feels-like, AQI, humidity, wind, visibility, pressure, activity suggestions, precautions, and recent searches.
- [ ] Keep city search, Celsius/Fahrenheit switching, recent-search selection, and loading states functional.
- [ ] Make settings functional for temperature units, home city, and clearing history.

## Identity and Android delivery

- [ ] Replace the placeholder icon with a real Sylph logo/launcher asset and generate Android launcher variants.
- [ ] Keep the app label as Sylph and preserve Android internet/network permissions.
- [ ] Produce a direct `app-debug.apk` artifact after validation.
- [ ] Push the completed changes to `vijayarkananduri/Sylph` on `main`.
