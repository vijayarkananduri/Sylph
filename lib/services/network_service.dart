import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class WeatherServiceException implements Exception {
  final String message;
  final WeatherServiceError kind;

  const WeatherServiceException(this.message, this.kind);

  @override
  String toString() => message;
}

enum WeatherServiceError {
  notConfigured,
  offline,
  notFound,
  unauthorized,
  timeout,
  server,
  malformed,
  unknown,
}

Future<bool> hasInternetConnection() async {
  try {
    return await Connectivity().checkConnectivity() != ConnectivityResult.none;
  } catch (_) {
    // Let the real request decide when the platform connectivity plugin is
    // unavailable or temporarily unable to report a state.
    return true;
  }
}

Future<Map<String, dynamic>> fetchWeather(String city, String owmKey) async {
  final query = city.trim();
  if (query.isEmpty) {
    throw const WeatherServiceException(
      'Type a city to check its atmosphere.',
      WeatherServiceError.notFound,
    );
  }
  if (owmKey.trim().isEmpty) {
    throw const WeatherServiceException(
      'Live weather is not configured in this build. You can still explore the dashboard, or add an OpenWeatherMap key for live updates.',
      WeatherServiceError.notConfigured,
    );
  }
  if (!await hasInternetConnection()) {
    throw const WeatherServiceException(
      'You appear to be offline. Showing your last saved atmosphere when available.',
      WeatherServiceError.offline,
    );
  }

  final url = Uri.https(
    'api.openweathermap.org',
    '/data/2.5/weather',
    <String, String>{
      'q': query,
      'appid': owmKey.trim(),
      'units': 'metric',
    },
  );

  Object? lastFailure;
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        throw const WeatherServiceException(
          'The weather service returned an unexpected response.',
          WeatherServiceError.malformed,
        );
      }
      if (response.statusCode == 404) {
        throw WeatherServiceException(
          'I could not find "$query". Try the city name without extra details.',
          WeatherServiceError.notFound,
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const WeatherServiceException(
          'The weather key was rejected. Add a valid OpenWeatherMap key and try again.',
          WeatherServiceError.unauthorized,
        );
      }
      if (response.statusCode >= 500) {
        throw const WeatherServiceException(
          'The weather service is taking a breather. Try again in a moment.',
          WeatherServiceError.server,
        );
      }
      throw WeatherServiceException(
        'The weather service returned status ${response.statusCode}. Try again shortly.',
        WeatherServiceError.server,
      );
    } on WeatherServiceException catch (error) {
      lastFailure = error;
      if (error.kind == WeatherServiceError.notFound ||
          error.kind == WeatherServiceError.unauthorized ||
          error.kind == WeatherServiceError.notConfigured ||
          error.kind == WeatherServiceError.malformed) {
        rethrow;
      }
    } on SocketException catch (error) {
      lastFailure = error;
    } on http.ClientException catch (error) {
      lastFailure = error;
    } on TimeoutException catch (error) {
      lastFailure = error;
    } on FormatException catch (error) {
      lastFailure = error;
      throw const WeatherServiceException(
        'The weather service sent unreadable data. Try again shortly.',
        WeatherServiceError.malformed,
      );
    }
    if (attempt < 2) {
      await Future<void>.delayed(Duration(milliseconds: 700 * (attempt + 1)));
    }
  }

  if (lastFailure is WeatherServiceException) {
    throw lastFailure;
  }
  if (lastFailure is TimeoutException) {
    throw const WeatherServiceException(
      'The request took too long. Check your connection and try again.',
      WeatherServiceError.timeout,
    );
  }
  throw const WeatherServiceException(
    'The sky is out of reach right now. Check your connection and try again.',
    WeatherServiceError.offline,
  );
}

Future<Map<String, dynamic>?> fetchAQI(String city, String waqiKey) async {
  final query = city.trim();
  if (query.isEmpty ||
      waqiKey.trim().isEmpty ||
      !await hasInternetConnection()) {
    return null;
  }

  final url = Uri.https(
    'api.waqi.info',
    '/feed/$query/',
    <String, String>{'token': waqiKey.trim()},
  );

  try {
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['status'] != 'ok') {
      return null;
    }
    // Keep the wrapper so the parser can support both WAQI response shapes.
    return decoded;
  } on SocketException {
    return null;
  } on TimeoutException {
    return null;
  } on http.ClientException {
    return null;
  } on FormatException {
    return null;
  }
}
