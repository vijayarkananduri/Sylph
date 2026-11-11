import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sylph/services/network_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SylphApp());
}

class SylphApp extends StatelessWidget {
  const SylphApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sylph — Weather & Air',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        useMaterial3: true,
        fontFamily: 'DM Sans',
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accent2,
          surface: AppColors.surface,
          error: AppColors.danger,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppColors.accent,
          selectionColor: Color.fromRGBO(200, 240, 78, 0.28),
          selectionHandleColor: AppColors.accent,
        ),
      ),
      home: const WeatherHomePage(),
    );
  }
}

class AppColors {
  static const bg = Color(0xFF0A0A0F);
  static const surface = Color(0xFF111118);
  static const text = Color(0xFFF0EDE8);
  static const muted = Color.fromRGBO(240, 237, 232, 0.66);
  static const faint = Color.fromRGBO(240, 237, 232, 0.42);
  static const accent = Color(0xFFC8F04E);
  static const accent2 = Color(0xFF4ECBF0);
  static const danger = Color(0xFFF04E6A);
  static const warn = Color(0xFFF0A84E);
  static const good = Color(0xFF4EF09A);
  static const violet = Color(0xFFB34EF0);
  static const cardTint = Color.fromRGBO(205, 185, 155, 0.12);
  static const cardBorder = Color.fromRGBO(238, 221, 190, 0.22);
}

class AppFonts {
  static TextStyle display({double size = 24, Color? color}) {
    return TextStyle(
      fontFamily: 'Boldonse',
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.text,
      letterSpacing: -0.02,
      height: 1.03,
    );
  }

  static TextStyle body({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.text,
      height: 1.25,
    );
  }

  static TextStyle label({double size = 10, Color? color}) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color ?? AppColors.muted,
      letterSpacing: 1.8,
      height: 1.15,
    );
  }
}

const String owmKey = String.fromEnvironment('OWM_KEY', defaultValue: '');
const String waqiKey = String.fromEnvironment('WAQI_KEY', defaultValue: '');

class WeatherData {
  final String city;
  final String country;
  final double temp;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int visibility;
  final int pressure;
  final String description;
  final int weatherCode;
  final double lat;
  final double lon;
  final int timezone;
  final DateTime localTime;

  const WeatherData({
    required this.city,
    required this.country,
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.visibility,
    required this.pressure,
    required this.description,
    required this.weatherCode,
    required this.lat,
    required this.lon,
    required this.timezone,
    required this.localTime,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final timezone = (json['timezone'] as num?)?.toInt() ?? 0;
    final utcNow = DateTime.now().toUtc();
    final localTime = utcNow.add(Duration(seconds: timezone));
    final main = json['main'] is Map ? json['main'] as Map : const {};
    final wind = json['wind'] is Map ? json['wind'] as Map : const {};
    final weather =
        json['weather'] is List && (json['weather'] as List).isNotEmpty
            ? (json['weather'] as List).first as Map
            : const {};
    final coord = json['coord'] is Map ? json['coord'] as Map : const {};
    final sys = json['sys'] is Map ? json['sys'] as Map : const {};

    return WeatherData(
      city: (json['name'] ?? 'Unknown').toString(),
      country: (sys['country'] ?? '').toString(),
      temp: ((main['temp'] ?? 0) as num).toDouble(),
      feelsLike: ((main['feels_like'] ?? 0) as num).toDouble(),
      humidity: (main['humidity'] as num?)?.toInt() ?? 0,
      windSpeed: ((wind['speed'] ?? 0) as num).toDouble(),
      visibility: (json['visibility'] as num?)?.toInt() ?? 10000,
      pressure: (main['pressure'] as num?)?.toInt() ?? 0,
      description: (weather['description'] ?? 'Unknown').toString(),
      weatherCode: (weather['id'] as num?)?.toInt() ?? 800,
      lat: ((coord['lat'] ?? 0) as num).toDouble(),
      lon: ((coord['lon'] ?? 0) as num).toDouble(),
      timezone: timezone,
      localTime: localTime,
    );
  }

  factory WeatherData.preview(String query) {
    final name = query.trim().isEmpty ? 'Hyderabad' : query.trim().titleCase;
    return WeatherData(
      city: name,
      country: 'IN',
      temp: 27.4,
      feelsLike: 29.1,
      humidity: 57,
      windSpeed: 3.8,
      visibility: 10000,
      pressure: 1012,
      description: 'soft evening air',
      weatherCode: 801,
      lat: 17.385,
      lon: 78.4867,
      timezone: 19800,
      localTime: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': city,
        'sys': {'country': country},
        'main': {
          'temp': temp,
          'feels_like': feelsLike,
          'humidity': humidity,
          'pressure': pressure,
        },
        'wind': {'speed': windSpeed},
        'visibility': visibility,
        'weather': [
          {'description': description, 'id': weatherCode},
        ],
        'coord': {'lat': lat, 'lon': lon},
        'timezone': timezone,
      };
}

class AQIData {
  final int aqi;
  final String? stationName;

  const AQIData({required this.aqi, this.stationName});

  factory AQIData.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] is Map ? json['data'] as Map : json;
    final city = raw['city'] is Map ? raw['city'] as Map : const {};
    final rawAqi = raw['aqi'];
    return AQIData(
      aqi: rawAqi is num ? rawAqi.toInt() : int.tryParse('$rawAqi') ?? 0,
      stationName: city['name']?.toString(),
    );
  }

  factory AQIData.preview() =>
      const AQIData(aqi: 42, stationName: 'Sylph preview station');

  Map<String, dynamic> toJson() => {
        'status': 'ok',
        'data': {
          'aqi': aqi,
          'city': {'name': stationName ?? ''}
        },
      };
}

class HistoryItem {
  final String city;
  final String country;
  final double tempC;
  final String description;
  final int? aqiNum;
  final DateTime timestamp;

  const HistoryItem({
    required this.city,
    required this.country,
    required this.tempC,
    required this.description,
    required this.timestamp,
    this.aqiNum,
  });

  Map<String, dynamic> toJson() => {
        'city': city,
        'country': country,
        'tempC': tempC,
        'description': description,
        'aqiNum': aqiNum,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        city: (json['city'] ?? 'Unknown').toString(),
        country: (json['country'] ?? '').toString(),
        tempC: ((json['tempC'] ?? 0) as num).toDouble(),
        description: (json['description'] ?? '').toString(),
        aqiNum: (json['aqiNum'] as num?)?.toInt(),
        timestamp: DateTime.tryParse('${json['timestamp']}') ?? DateTime.now(),
      );
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  WeatherData? _weatherData;
  AQIData? _aqiData;
  WeatherData? _cachedWeather;
  AQIData? _cachedAqi;
  bool _isLoading = false;
  bool _isCelsius = true;
  bool _isStale = false;
  bool _isPreview = false;
  String? _errorMessage;
  String? _noticeMessage;
  String _homeCity = '';
  String _userName = '';
  List<HistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    unawaited(_restoreState());
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getStringList('history') ?? <String>[];
    final restoredHistory = <HistoryItem>[];
    for (final raw in rawHistory) {
      try {
        restoredHistory
            .add(HistoryItem.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Ignore one malformed history entry instead of blocking the app.
      }
    }

    WeatherData? cachedWeather;
    AQIData? cachedAqi;
    final weatherJson = prefs.getString('lastWeather');
    final aqiJson = prefs.getString('lastAqi');
    try {
      if (weatherJson != null) {
        cachedWeather = WeatherData.fromJson(jsonDecode(weatherJson));
      }
      if (aqiJson != null) {
        cachedAqi = AQIData.fromJson(jsonDecode(aqiJson));
      }
    } catch (_) {
      cachedWeather = null;
      cachedAqi = null;
    }

    if (!mounted) return;
    setState(() {
      _history = restoredHistory;
      _cachedWeather = cachedWeather;
      _cachedAqi = cachedAqi;
      _homeCity = prefs.getString('homeCity') ?? '';
      _userName = prefs.getString('userName') ?? '';
      _isCelsius = prefs.getBool('celsius') ?? true;
    });

    if (_homeCity.isNotEmpty) {
      _searchController.text = _homeCity;
      unawaited(_fetchWeather(_homeCity));
    }
  }

  Future<void> _fetchWeather(String city) async {
    final query = city.trim();
    if (query.isEmpty) {
      setState(() => _errorMessage = 'Type a city to check its atmosphere.');
      _searchFocusNode.requestFocus();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _noticeMessage = null;
      _isStale = false;
      _isPreview = false;
    });

    if (owmKey.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      if (_cachedWeather != null) {
        _showCached(query,
            'Live weather is not configured, so your last saved atmosphere is shown.');
      } else {
        final preview = WeatherData.preview(query);
        final previewAqi = AQIData.preview();
        setState(() {
          _weatherData = preview;
          _aqiData = previewAqi;
          _isLoading = false;
          _isPreview = true;
          _noticeMessage =
              'Preview mode is on. Add an OpenWeatherMap key for live atmosphere data.';
        });
      }
      return;
    }

    try {
      final weatherJson = await fetchWeather(query, owmKey);
      final weather = WeatherData.fromJson(weatherJson);
      AQIData? aqi;
      final aqiJson = await fetchAQI(query, waqiKey);
      if (aqiJson != null) {
        aqi = AQIData.fromJson(aqiJson);
      }
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastWeather', jsonEncode(weatherJson));
      if (aqiJson != null) {
        await prefs.setString('lastAqi', jsonEncode(aqiJson));
      }

      final newHistory = [
        HistoryItem(
          city: weather.city,
          country: weather.country,
          tempC: weather.temp,
          description: weather.description,
          aqiNum: aqi?.aqi,
          timestamp: DateTime.now(),
        ),
        ..._history.where(
            (item) => item.city.toLowerCase() != weather.city.toLowerCase()),
      ].take(8).toList();
      await prefs.setStringList('history',
          newHistory.map((item) => jsonEncode(item.toJson())).toList());

      setState(() {
        _weatherData = weather;
        _aqiData = aqi;
        _cachedWeather = weather;
        _cachedAqi = aqi;
        _history = newHistory;
        _isLoading = false;
        _isStale = false;
        _isPreview = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (_cachedWeather != null) {
        _showCached(query, _errorCopy(error));
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = _errorCopy(error);
        });
      }
    }
  }

  void _showCached(String query, String notice) {
    setState(() {
      _weatherData = _cachedWeather;
      _aqiData = _cachedAqi;
      _isLoading = false;
      _isStale = true;
      _noticeMessage = notice;
      _errorMessage = null;
    });
  }

  String _errorCopy(Object error) {
    if (error is WeatherServiceException) return error.message;
    if (error is http.ClientException) {
      return 'The sky is out of reach right now. Check your connection and try again.';
    }
    return 'Something interrupted the atmosphere check. Try again in a moment.';
  }

  Future<void> _refresh() async {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) await _fetchWeather(query);
  }

  Future<void> _saveHomeCity(String city) async {
    final clean = city.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('homeCity', clean);
    if (!mounted) return;
    setState(() => _homeCity = clean);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');
    if (!mounted) return;
    setState(() => _history = []);
  }

  String _tempDisplay(double celsius) {
    if (_isCelsius) return celsius.toStringAsFixed(1);
    return ((celsius * 9 / 5) + 32).toStringAsFixed(1);
  }

  String get _unit => _isCelsius ? '°C' : '°F';

  String get _greeting {
    final hour = DateTime.now().hour;
    final base = hour < 5
        ? 'Up late?'
        : hour < 12
            ? 'Good morning'
            : hour < 17
                ? 'Good afternoon'
                : hour < 21
                    ? 'Good evening'
                    : 'Good night';
    return _userName.isEmpty ? base : '$base, $_userName';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
              child:
                  AtmosphereBackdrop(weatherCode: _weatherData?.weatherCode)),
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 44),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 26),
                      _buildSearch(),
                      if (_homeCity.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildHomeCityChip(),
                      ],
                      if (_noticeMessage != null) ...[
                        const SizedBox(height: 14),
                        Reveal(child: _buildNotice()),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Reveal(child: _buildError()),
                      ],
                      if (_isLoading) ...[
                        const SizedBox(height: 28),
                        Reveal(child: _buildLoading()),
                      ] else if (_weatherData != null) ...[
                        const SizedBox(height: 30),
                        _buildDashboard(),
                      ] else ...[
                        const SizedBox(height: 30),
                        _buildEmptyHome(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SylphMark(size: 46),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sylph', style: AppFonts.display(size: 21)),
                Text('WEATHER & AIR',
                    style: AppFonts.label(size: 9, color: AppColors.accent2)),
              ],
            ),
            const Spacer(),
            _Tactile(
              onTap: _showSettings,
              child: const GlassIconButton(
                  icon: Icons.tune_rounded, color: AppColors.accent),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(_greeting, style: AppFonts.display(size: 39)),
        const SizedBox(height: 6),
        Text(
          _weatherData == null
              ? 'Search a city first.'
              : 'Here is what the air is doing right now.',
          style: AppFonts.body(size: 14, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      radius: 28,
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.location_on_rounded,
                size: 19, color: AppColors.faint),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: _fetchWeather,
              style: AppFonts.body(size: 16, color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Search a city',
                hintStyle: AppFonts.body(size: 16, color: AppColors.muted),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
              ),
            ),
          ),
          _Tactile(
            onTap: () => _fetchWeather(_searchController.text),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                  color: AppColors.accent, shape: BoxShape.circle),
              child: const Icon(Icons.search_rounded,
                  color: AppColors.bg, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeCityChip() {
    return Row(
      children: [
        const Icon(Icons.home_rounded, size: 14, color: AppColors.accent),
        const SizedBox(width: 7),
        Text('Home city · $_homeCity',
            style: AppFonts.body(size: 12, color: AppColors.muted)),
        const Spacer(),
        GestureDetector(
          onTap: () => _fetchWeather(_homeCity),
          child: Text('REFRESH',
              style: AppFonts.label(size: 9, color: AppColors.accent)),
        ),
      ],
    );
  }

  Widget _buildNotice() {
    final color = _isPreview ? AppColors.accent2 : AppColors.accent;
    return GlassCard(
      tint: color.withOpacity(0.08),
      borderColor: color.withOpacity(0.25),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
              _isPreview
                  ? Icons.auto_awesome_rounded
                  : Icons.cloud_queue_rounded,
              size: 17,
              color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_noticeMessage!,
                  style: AppFonts.body(size: 12, color: AppColors.muted))),
        ],
      ),
    );
  }

  Widget _buildError() {
    return GlassCard(
      tint: AppColors.danger.withOpacity(0.09),
      borderColor: AppColors.danger.withOpacity(0.3),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 19, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Could not reach the sky',
                    style: AppFonts.body(
                        size: 14,
                        weight: FontWeight.w500,
                        color: AppColors.text)),
                const SizedBox(height: 5),
                Text(_errorMessage!,
                    style: AppFonts.body(size: 12, color: AppColors.muted)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _fetchWeather(_searchController.text),
                  child: Text('TRY AGAIN',
                      style: AppFonts.label(size: 9, color: AppColors.accent)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 18),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.75, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            onEnd: () {},
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.accent.withOpacity(0.22), blurRadius: 24)
                ],
              ),
              child: const Icon(Icons.air_rounded,
                  color: AppColors.accent, size: 24),
            ),
          ),
          const SizedBox(height: 17),
          Text('READING THE ATMOSPHERE',
              style: AppFonts.label(size: 9, color: AppColors.accent)),
        ],
      ),
    );
  }

  Widget _buildEmptyHome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Reveal(
          child: GlassCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SylphMark(size: 38),
                    const Spacer(),
                    Text('READY WHEN YOU ARE',
                        style:
                            AppFonts.label(size: 9, color: AppColors.accent)),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Your little atmosphere desk.',
                    style: AppFonts.display(size: 26)),
                const SizedBox(height: 8),
                Text(
                  'Search a city and Sylph will turn temperature, air quality, and the feel of the day into one calm glance.',
                  style: AppFonts.body(size: 14, color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _miniStat(Icons.thermostat_rounded, 'TEMP'),
                    const SizedBox(width: 10),
                    _miniStat(Icons.air_rounded, 'AIR'),
                    const SizedBox(width: 10),
                    _miniStat(Icons.wb_sunny_rounded, 'UV'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('TRY A CITY', style: AppFonts.label(size: 10)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: ['Hyderabad', 'Bengaluru', 'Mumbai'].map((city) {
            return _Tactile(
              onTap: () {
                _searchController.text = city;
                _fetchWeather(city);
              },
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                radius: 18,
                child: Text(city,
                    style: AppFonts.body(size: 12, color: AppColors.text)),
              ),
            );
          }).toList(),
        ),
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 28),
          _buildHistory(),
        ],
      ],
    );
  }

  Widget _miniStat(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: AppColors.accent2),
            const SizedBox(height: 7),
            Text(label, style: AppFonts.label(size: 8)),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final weather = _weatherData!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Reveal(child: _buildCityHeading(weather)),
        const SizedBox(height: 16),
        Reveal(delay: 80, child: _buildWeatherHero(weather)),
        const SizedBox(height: 14),
        Reveal(delay: 140, child: _buildAqiWidget()),
        const SizedBox(height: 26),
        Text('AT A GLANCE', style: AppFonts.label(size: 10)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 600 ? 4 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: columns == 4 ? 1.08 : 1.24,
              children: [
                Reveal(
                    delay: 180,
                    child: _metricWidget(
                        Icons.thermostat_rounded,
                        'FEELS LIKE',
                        '${_tempDisplay(weather.feelsLike)} $_unit',
                        AppColors.accent)),
                Reveal(
                    delay: 220,
                    child: _metricWidget(Icons.water_drop_rounded, 'HUMIDITY',
                        '${weather.humidity}%', AppColors.accent2)),
                Reveal(
                    delay: 260,
                    child: _metricWidget(
                        Icons.air_rounded,
                        'WIND',
                        '${weather.windSpeed.toStringAsFixed(1)} m/s',
                        AppColors.accent)),
                Reveal(
                    delay: 300,
                    child: _metricWidget(
                        Icons.visibility_rounded,
                        'VISIBILITY',
                        '${(weather.visibility / 1000).toStringAsFixed(1)} km',
                        AppColors.accent2)),
                Reveal(
                    delay: 340,
                    child: _metricWidget(Icons.speed_rounded, 'PRESSURE',
                        '${weather.pressure} hPa', AppColors.violet)),
                Reveal(
                    delay: 380,
                    child: _metricWidget(Icons.explore_rounded, 'LATITUDE',
                        weather.lat.toStringAsFixed(2), AppColors.warn)),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Reveal(delay: 420, child: _buildActivities(weather)),
        const SizedBox(height: 14),
        Reveal(delay: 460, child: _buildPrecautions(weather)),
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 28),
          _buildHistory(),
        ],
      ],
    );
  }

  Widget _buildCityHeading(WeatherData weather) {
    final localTime =
        '${weather.localTime.hour.toString().padLeft(2, '0')}:${weather.localTime.minute.toString().padLeft(2, '0')}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(weather.city, style: AppFonts.display(size: 39)),
              const SizedBox(height: 8),
              Text(
                '${weather.country.isEmpty ? 'LIVE' : weather.country}  ·  $localTime  ·  ${_isStale ? 'LAST SAVED' : _isPreview ? 'PREVIEW' : 'LIVE'}',
                style: AppFonts.label(
                    size: 9,
                    color: _isStale ? AppColors.warn : AppColors.accent2),
              ),
            ],
          ),
        ),
        if (_homeCity.toLowerCase() != weather.city.toLowerCase())
          _Tactile(
            onTap: () async {
              await _saveHomeCity(weather.city);
              if (mounted) {
                setState(() =>
                    _noticeMessage = '${weather.city} is now your home city.');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withOpacity(0.28)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_home_rounded,
                      size: 15, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text('SET HOME',
                      style: AppFonts.label(size: 8, color: AppColors.accent)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWeatherHero(WeatherData weather) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(21, 22, 18, 20),
      tint: AppColors.cardTint.withOpacity(0.96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENT ATMOSPHERE',
                        style:
                            AppFonts.label(size: 9, color: AppColors.accent2)),
                    const SizedBox(height: 17),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_tempDisplay(weather.temp),
                            style: AppFonts.display(size: 67)),
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 5),
                          child: Text(_unit,
                              style: AppFonts.body(
                                  size: 16, color: AppColors.muted)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(weather.description.titleCase,
                        style: AppFonts.body(size: 16, color: AppColors.muted)),
                  ],
                ),
              ),
              WeatherGlyph(code: weather.weatherCode, size: 86),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.16),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              children: [
                const Icon(Icons.accessibility_new_rounded,
                    size: 17, color: AppColors.accent),
                const SizedBox(width: 9),
                Expanded(
                    child: Text(
                        'Feels like ${_tempDisplay(weather.feelsLike)} $_unit — your skin does not do facts, only vibes.',
                        style:
                            AppFonts.body(size: 12, color: AppColors.muted))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAqiWidget() {
    final aqi = _aqiData?.aqi;
    final status = aqi == null ? 'NO STATION' : _aqiLabel(aqi);
    final color = aqi == null ? AppColors.muted : _aqiColor(aqi);
    final progress = aqi == null ? 0.0 : min(aqi / 300, 1.0);
    return GlassCard(
      tint: color.withOpacity(0.08),
      borderColor: color.withOpacity(0.28),
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.air_rounded, size: 18, color: color),
              const SizedBox(width: 9),
              Text('AIR QUALITY', style: AppFonts.label(size: 9, color: color)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child:
                    Text(status, style: AppFonts.label(size: 8, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(aqi?.toString() ?? '—',
                  style: AppFonts.display(size: 42, color: color)),
              const SizedBox(width: 10),
              Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                      'AQI  ·  ${_aqiData?.stationName ?? 'Waiting for a nearby station'}',
                      style: AppFonts.body(size: 12, color: AppColors.muted))),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricWidget(IconData icon, String label, String value, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 12),
          Text(label, style: AppFonts.label(size: 8)),
          const SizedBox(height: 5),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(value, style: AppFonts.display(size: 20)),
          ),
        ],
      ),
    );
  }

  Widget _buildActivities(WeatherData weather) {
    final pleasant =
        weather.temp >= 18 && weather.temp <= 31 && weather.humidity < 78;
    final activities = pleasant
        ? [
            (
              Icons.directions_walk_rounded,
              'Walk it out',
              'The air is on your side.'
            ),
            (
              Icons.local_cafe_rounded,
              'Coffee outside',
              'A good day for a slow one.'
            ),
            (
              Icons.photo_camera_rounded,
              'Golden hour',
              'Keep the camera close.'
            ),
          ]
        : [
            (Icons.home_rounded, 'Stay tucked in', 'Let the room do the work.'),
            (
              Icons.water_drop_rounded,
              'Hydrate',
              'The atmosphere is asking nicely.'
            ),
            (
              Icons.menu_book_rounded,
              'Indoor reset',
              'A good day for a quiet ritual.'
            ),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RECOMMENDED NOW', style: AppFonts.label(size: 10)),
        const SizedBox(height: 12),
        ...activities.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Icon(item.$1, color: AppColors.accent, size: 20),
                  const SizedBox(width: 12),
                  Text(item.$2,
                      style: AppFonts.body(size: 13, weight: FontWeight.w500)),
                  const Spacer(),
                  Text(item.$3,
                      style: AppFonts.body(size: 11, color: AppColors.muted)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPrecautions(WeatherData weather) {
    final items = <String>[];
    if (weather.humidity >= 75) {
      items.add(
          'Humidity is high. Light layers will feel better than anything clingy.');
    }
    if (weather.windSpeed >= 8) {
      items.add(
          'Wind is picking up. Secure loose things and expect your hair to have opinions.');
    }
    if (weather.visibility < 4000) {
      items.add('Visibility is reduced. Take it slower on the road.');
    }
    if (_aqiData != null && _aqiData!.aqi > 100) {
      items.add(
          'Air quality is rough for sensitive lungs. Keep longer outdoor plans short.');
    }
    if (items.isEmpty) {
      items.add(
          'No big atmospheric red flags. Take the long way if you feel like it.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SMALL PRECAUTIONS', style: AppFonts.label(size: 10)),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child:
                            Icon(Icons.circle, size: 6, color: AppColors.warn)),
                    const SizedBox(width: 11),
                    Expanded(
                        child: Text(item,
                            style: AppFonts.body(
                                size: 12, color: AppColors.muted))),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('RECENTLY CHECKED', style: AppFonts.label(size: 10)),
            const Spacer(),
            GestureDetector(
              onTap: _clearHistory,
              child: Text('CLEAR',
                  style: AppFonts.label(size: 9, color: AppColors.danger)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = _history[index];
              return _Tactile(
                onTap: () {
                  _searchController.text = item.city;
                  _fetchWeather(item.city);
                },
                child: GlassCard(
                  width: 150,
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppFonts.body(size: 13, weight: FontWeight.w500)),
                      Row(
                        children: [
                          Text('${_tempDisplay(item.tempC)} $_unit',
                              style: AppFonts.body(
                                  size: 14, color: AppColors.accent)),
                          const Spacer(),
                          if (item.aqiNum != null)
                            Text('${item.aqiNum}',
                                style: AppFonts.label(
                                    size: 9, color: _aqiColor(item.aqiNum!))),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _aqiLabel(int aqi) {
    if (aqi <= 50) return 'GOOD';
    if (aqi <= 100) return 'MODERATE';
    if (aqi <= 150) return 'SENSITIVE';
    if (aqi <= 200) return 'UNHEALTHY';
    if (aqi <= 300) return 'VERY UNHEALTHY';
    return 'HAZARDOUS';
  }

  Color _aqiColor(int aqi) {
    if (aqi <= 50) return AppColors.good;
    if (aqi <= 100) return AppColors.warn;
    if (aqi <= 150) return const Color(0xFFF07F4E);
    if (aqi <= 200) return AppColors.danger;
    if (aqi <= 300) return AppColors.violet;
    return const Color(0xFFE84B4B);
  }

  Future<void> _showSettings() async {
    final homeController = TextEditingController(text: _homeCity);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF15151E).withOpacity(0.98),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                          child: Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4)))),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const SylphMark(size: 36),
                          const SizedBox(width: 11),
                          Text('Sylph settings',
                              style: AppFonts.display(size: 22)),
                          const Spacer(),
                          GestureDetector(
                              onTap: () => Navigator.pop(sheetContext),
                              child: const Icon(Icons.close_rounded,
                                  color: AppColors.muted)),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Text('TEMPERATURE UNIT', style: AppFonts.label(size: 9)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _unitChoice('°C', _isCelsius, () async {
                            setState(() => _isCelsius = true);
                            setSheetState(() {});
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('celsius', true);
                          }),
                          const SizedBox(width: 9),
                          _unitChoice('°F', !_isCelsius, () async {
                            setState(() => _isCelsius = false);
                            setSheetState(() {});
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('celsius', false);
                          }),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('HOME CITY', style: AppFonts.label(size: 9)),
                      const SizedBox(height: 10),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        child: TextField(
                          controller: homeController,
                          style: AppFonts.body(size: 14),
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                              hintText: 'e.g. Hyderabad',
                              hintStyle: AppFonts.body(
                                  size: 14, color: AppColors.muted),
                              border: InputBorder.none),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _Tactile(
                              onTap: () async {
                                final home = homeController.text.trim();
                                await _saveHomeCity(home);
                                if (home.isNotEmpty) {
                                  _searchController.text = home;
                                  unawaited(_fetchWeather(home));
                                }
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(18)),
                                child: Center(
                                    child: Text('SAVE HOME CITY',
                                        style: AppFonts.label(
                                            size: 9, color: AppColors.bg))),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 17),
                      GestureDetector(
                        onTap: () async {
                          await _clearHistory();
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                              child: Text('Clear recent searches',
                                  style: AppFonts.body(
                                      size: 12, color: AppColors.danger))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    homeController.dispose();
  }

  Widget _unitChoice(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: _Tactile(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withOpacity(0.14)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: active
                    ? AppColors.accent.withOpacity(0.65)
                    : Colors.white.withOpacity(0.08)),
          ),
          child: Center(
              child: Text(label,
                  style: AppFonts.body(
                      size: 14,
                      color: active ? AppColors.accent : AppColors.muted))),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color tint;
  final Color? borderColor;
  final double? width;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.tint = AppColors.cardTint,
    this.borderColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor ?? AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 22,
                    offset: const Offset(0, 10))
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;

  const GlassIconButton({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.35)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 18)],
      ),
      child: Icon(icon, size: 19, color: color),
    );
  }
}

class _Tactile extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _Tactile({required this.child, required this.onTap});

  @override
  State<_Tactile> createState() => _TactileState();
}

class _TactileState extends State<_Tactile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.84 : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

class Reveal extends StatelessWidget {
  final Widget child;
  final int delay;

  const Reveal({super.key, required this.child, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 560 + delay ~/ 2),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
              offset: Offset(0, 16 * (1 - value)), child: child),
        );
      },
      child: child,
    );
  }
}

class SylphMark extends StatelessWidget {
  final double size;

  const SylphMark({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(color: AppColors.accent.withOpacity(0.12), blurRadius: 18)
        ],
      ),
      child: CustomPaint(painter: SylphMarkPainter()),
    );
  }
}

class SylphMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 46;
    final rect = Rect.fromLTWH(10 * scale, 8 * scale, 27 * scale, 30 * scale);
    final lime = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4 * scale
      ..strokeCap = StrokeCap.round;
    final cyan = Paint()
      ..color = AppColors.accent2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi * 0.95, pi * 1.12, false, lime);
    canvas.drawArc(rect.shift(Offset(3 * scale, 2 * scale)), pi * 0.98,
        pi * 1.03, false, cyan);
    final tip = Paint()..color = AppColors.accent;
    canvas.drawPath(
        Path()
          ..moveTo(33 * scale, 22 * scale)
          ..lineTo(39 * scale, 19 * scale)
          ..lineTo(36 * scale, 25 * scale)
          ..close(),
        tip);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WeatherGlyph extends StatelessWidget {
  final int code;
  final double size;

  const WeatherGlyph({super.key, required this.code, this.size = 76});

  @override
  Widget build(BuildContext context) {
    final isRain = code >= 200 && code < 600;
    final isSnow = code >= 600 && code < 700;
    final isCloud = code >= 801 && code < 900;
    final icon = isRain
        ? Icons.grain_rounded
        : isSnow
            ? Icons.ac_unit_rounded
            : isCloud
                ? Icons.cloud_rounded
                : Icons.wb_sunny_rounded;
    final color = isRain
        ? AppColors.accent2
        : isSnow
            ? Colors.white
            : isCloud
                ? AppColors.accent2
                : AppColors.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.18), blurRadius: 25)],
      ),
      child: Icon(icon, size: size * 0.46, color: color),
    );
  }
}

class AtmosphereBackdrop extends StatefulWidget {
  final int? weatherCode;

  const AtmosphereBackdrop({super.key, this.weatherCode});

  @override
  State<AtmosphereBackdrop> createState() => _AtmosphereBackdropState();
}

class _AtmosphereBackdropState extends State<AtmosphereBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 18))
          ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: AtmospherePainter(
            progress: _controller.value, weatherCode: widget.weatherCode),
        child: const SizedBox.expand(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class AtmospherePainter extends CustomPainter {
  final double progress;
  final int? weatherCode;

  AtmospherePainter({required this.progress, required this.weatherCode});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(AppColors.bg, BlendMode.srcOver);
    final phase = progress * pi * 2;
    final rain = (weatherCode ?? 800) >= 200 && (weatherCode ?? 800) < 700;
    _blob(
        canvas,
        Offset(size.width * 0.08 + sin(phase) * 24,
            size.height * 0.04 + cos(phase) * 16),
        size.width * 0.64,
        AppColors.accent2,
        0.11);
    _blob(
        canvas,
        Offset(size.width * 0.96 + cos(phase * 0.72) * 30,
            size.height * 0.83 + sin(phase * 0.72) * 24),
        size.width * 0.58,
        AppColors.accent,
        0.095);
    _blob(
        canvas,
        Offset(size.width * 0.54 + sin(phase * 0.42) * 45,
            size.height * 0.43 + cos(phase * 0.42) * 38),
        size.width * 0.36,
        rain ? AppColors.accent2 : AppColors.violet,
        0.045);

    final particlePaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    for (var index = 0; index < 22; index++) {
      final x = (index * 97.0 + phase * 24) % max(size.width, 1);
      final y = (index * 137.0 + sin(phase + index) * 30) % max(size.height, 1);
      final length = rain ? 11.0 : 4.0;
      canvas.drawLine(
          Offset(x, y), Offset(x + (rain ? 3 : 1), y + length), particlePaint);
    }
  }

  void _blob(Canvas canvas, Offset center, double radius, Color color,
      double opacity) {
    final paint = Paint()
      ..shader = RadialGradient(
              colors: [color.withOpacity(opacity), color.withOpacity(0)])
          .createShader(Rect.fromCircle(center: center, radius: radius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant AtmospherePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.weatherCode != weatherCode;
}

extension StringExtension on String {
  String get titleCase {
    if (trim().isEmpty) return this;
    return trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }
}
