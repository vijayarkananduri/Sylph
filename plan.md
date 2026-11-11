# Sylph implementation plan

## User requirements

- Fix the current weather-request failure so the app does not surface a raw socket exception.
- Keep the existing Boldonse display font and DM Sans body font unchanged.
- Make the home experience tactile, liquid-glass, and animation-led.
- Add useful home dashboard widgets for weather, air quality, metrics, history, and quick actions.
- Make the settings action functional, including temperature units and home-city preference.
- Include a working Sylph logo/launcher icon rather than the current placeholder asset.
- Deliver a working Android debug APK and push the changes into the `vijayarkananduri/Sylph` repository.

## Approach

The existing Flutter app remains the source of truth. The screen will be reorganized around reusable glass surfaces, a layered animated backdrop, a tactile search control, and compact dashboard cards. The current font declarations are preserved exactly: the bundled Boldonse font remains the display face and Google Fonts DM Sans remains the body/label face.

Network calls will be made directly against the configured OpenWeatherMap and WAQI endpoints, but the error path will be normalized into actionable messages. Retries will cover transient socket/client/time-out failures without wrapping exceptions into an unreadable nested string. Last successful weather JSON will be cached in SharedPreferences and displayed with a visible stale-data state when the device is offline or the build has no API key. AQI parsing will accept both the WAQI wrapper and the unwrapped data shape used by the current service.

The home dashboard will include: animated greeting and logo, city search, a live/offline state banner, weather hero card, AQI card with a progress bar and status label, metric widgets for feels-like/humidity/wind/visibility/pressure, activity/precaution suggestions, recent-search chips, and settings controls. All interactions use Flutter animation primitives so the app works without additional runtime assets or services.

The launcher asset will be regenerated as a proper high-resolution Sylph mark with dark glass, lime airflow, and cyan highlight colors. `flutter_launcher_icons` will generate Android launcher variants from that asset.

## Project structure

- `lib/main.dart`: app theme, models, persistence, dashboard UI, animations, settings, and state transitions.
- `lib/services/network_service.dart`: connectivity-aware weather/AQI requests, retries, response validation, and user-safe errors.
- `assets/fonts/Boldonse-Regular.ttf`: existing display font, unchanged.
- `assets/icon/`: launcher source and foreground artwork.
- `android/`: Flutter Android wrapper and launcher configuration.
- `.github/workflows/build.yml`: release build automation; it will be extended with a debug build artifact for direct handoff.

## Design direction

Three possible directions were considered: **liquid night observatory** (0.72), **warm editorial weather journal** (0.06), and **neon transit control room** (0.05). The selected direction is **liquid night observatory**.

- **Design movement:** iOS liquid-glass depth translated into a dark weather instrument, with translucent surfaces over slowly drifting atmospheric light.
- **Core principles:** tactile feedback, legible data hierarchy, calm motion, and graceful degradation when live data is unavailable.
- **Color philosophy:** near-black gives weather data contrast; Sylph lime signals action and freshness; cyan marks air/atmosphere; rose is reserved for actionable failure states.
- **Layout paradigm:** a vertical observatory feed with one large hero reading followed by staggered dashboard widgets, rather than a flat form or dense grid.
- **Signature elements:** refractive glass cards, animated atmospheric orbs/particles, and the custom Sylph airflow mark.
- **Interaction philosophy:** every control has a pressed scale/opacity response; settings and error states are bottom-sheet-like, readable, and reversible.
- **Animation:** 500–900ms eased entrance for dashboard sections, slow background drift, a pulsing loading ring, and short press-scale feedback. Reduced-motion preference is respected where practical by avoiding infinite high-frequency effects.
- **Typography system:** preserve Boldonse for display numbers/headlines and DM Sans for labels, supporting text, and controls.
- **Brand essence:** weather and air quality that feels observant, human, and lightly playful; personality adjectives: atmospheric, tactile, candid.
- **Brand voice:** headlines are direct and lightly human ("How's the sky looking?"), while errors explain what to do ("The sky is out of reach — try again when you're back online.").
- **Wordmark & logo:** a compact lime/cyan airflow S-mark that reads as a wind curl inside a rounded glass tile, paired with the existing Sylph wordmark.
- **Signature brand color:** Sylph lime `#C8F04E`.

## Delivery

Validate with `dart format`/`flutter analyze` when the Flutter toolchain is available, build `app-debug.apk`, verify the APK exists and has a valid Android package, commit to `main`, and push to `origin/main`.
