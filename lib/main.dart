import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sylph/services/network_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0a0a0f),
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
        scaffoldBackgroundColor: const Color(0xFF0a0a0f),
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'DM Sans',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFc8f04e),
          secondary: Color(0xFF4ecbf0),
          surface: Color(0xFF111118),
          background: Color(0xFF0a0a0f),
          error: Color(0xFFf04e6a),
        ),
      ),
      home: const WeatherHomePage(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CONSTANTS & THEME
// ═══════════════════════════════════════════════════════════
class AppColors {
  static const bg = Color(0xFF0a0a0f);
  static const surface = Color(0xFF111118);
  static const border = Color.fromRGBO(255, 255, 255, 0.07);
  static const text = Color(0xFFf0ede8);
  static const muted = Color.fromRGBO(240, 237, 232, 0.68);
  static const accent = Color(0xFFc8f04e);
  static const accent2 = Color(0xFF4ecbf0);
  static const danger = Color(0xFFf04e6a);
  static const warn = Color(0xFFf0a84e);
  static const good = Color(0xFF4ef09a);
  static const cardTint = Color.fromRGBO(205, 185, 155, 0.13);
  static const cardBorder = Color.fromRGBO(205, 185, 145, 0.22);
}

class AppFonts {
  static TextStyle display({double size = 24, Color? color}) {
    return TextStyle(
      fontFamily: 'Boldonse',
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.text,
      letterSpacing: -0.02,
    );
  }

  static TextStyle body({double size = 16, FontWeight weight = FontWeight.w400, Color? color}) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.text,
    );
  }

  static TextStyle boldonse({double size = 24, Color? color}) {
    return TextStyle(
      fontFamily: 'Boldonse',
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.text,
      letterSpacing: 0.04,
    );
  }

  static TextStyle label({double size = 10, Color? color}) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color ?? AppColors.muted,
      letterSpacing: 0.25,
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  API KEYS (use --dart-define for secure builds)
// ═══════════════════════════════════════════════════════════
const String OWM_KEY = String.fromEnvironment('OWM_KEY', defaultValue: 'fa736ae62b05126fda481140ce2f39ef');
const String WAQI_KEY = String.fromEnvironment('WAQI_KEY', defaultValue: '8a0e521b8a539d30e682f61b71cf7413ad20d7ae');

// ═══════════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════════
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

  WeatherData({
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
    final tz = json['timezone'] ?? 0;
    final utcMs = DateTime.now().millisecondsSinceEpoch + (DateTime.now().timeZoneOffset.inMilliseconds);
    final localMs = utcMs + (tz * 1000);

    return WeatherData(
      city: json['name'] ?? 'Unknown',
      country: json['sys']?['country'] ?? '',
      temp: (json['main']?['temp'] ?? 0).toDouble(),
      feelsLike: (json['main']?['feels_like'] ?? 0).toDouble(),
      humidity: json['main']?['humidity'] ?? 0,
      windSpeed: (json['wind']?['speed'] ?? 0).toDouble(),
      visibility: json['visibility'] ?? 10000,
      pressure: json['main']?['pressure'] ?? 0,
      description: json['weather']?[0]?['description'] ?? 'Unknown',
      weatherCode: json['weather']?[0]?['id'] ?? 800,
      lat: (json['coord']?['lat'] ?? 0).toDouble(),
      lon: (json['coord']?['lon'] ?? 0).toDouble(),
      timezone: tz,
      localTime: DateTime.fromMillisecondsSinceEpoch(localMs.toInt()),
    );
  }
}

class AQIData {
  final int aqi;
  final String? stationName;
  final Map<String, dynamic>? iaqi;

  AQIData({required this.aqi, this.stationName, this.iaqi});

  factory AQIData.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data == null) return AQIData(aqi: 0);

    return AQIData(
      aqi: data['aqi'] is int ? data['aqi'] : int.tryParse(data['aqi'].toString()) ?? 0,
      stationName: data['city']?['name'],
      iaqi: data['iaqi'],
    );
  }
}

class HistoryItem {
  final String city;
  final String country;
  final double tempC;
  final String description;
  final int? aqiNum;
  final DateTime timestamp;

  HistoryItem({
    required this.city,
    required this.country,
    required this.tempC,
    required this.description,
    this.aqiNum,
    required this.timestamp,
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
    city: json['city'],
    country: json['country'],
    tempC: (json['tempC'] ?? 0).toDouble(),
    description: json['description'],
    aqiNum: json['aqiNum'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

// ════════════════════════════════════════════════════════════
//  MAIN PAGE STATE
// ═══════════════════════════════════════════════════════════
class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  WeatherData? _weatherData;
  AQIData? _aqiData;
  bool _isLoading = false;
  String? _errorMessage;
  List<HistoryItem> _history = [];
  bool _isCelsius = true;
  String _userName = '';
  String _homeCity = '';
  bool _onboarded = false;
  Timer? _homeRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _loadHistory();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCelsius = prefs.getBool('isCelsius') ?? true;
      _userName = prefs.getString('userName') ?? '';
      _homeCity = prefs.getString('homeCity') ?? '';
      _onboarded = prefs.getBool('onboarded') ?? false;
    });

    if (!_onboarded) {
      Future.delayed(const Duration(milliseconds: 500), _showOnboarding);
    } else if (_homeCity.isNotEmpty) {
      await _fetchWeather(_homeCity);
      _startHomeCityRefresh();
    }
  }

  void _startHomeCityRefresh() {
    _homeRefreshTimer?.cancel();
    _homeRefreshTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      if (_homeCity.isNotEmpty && _searchController.text == _homeCity) {
        await _fetchWeather(_homeCity);
      }
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('history') ?? [];
    setState(() {
      _history = historyJson.map((item) => HistoryItem.fromJson(jsonDecode(item))).toList();
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final limited = _history.length > 20 ? _history.sublist(0, 20) : _history;
    await prefs.setStringList('history', limited.map((item) => jsonEncode(item.toJson())).toList());
  }

  Future<void> _fetchWeather(String city) async {
    if (city.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final weatherJson = await fetchWeather(city, OWM_KEY);
      final weather = WeatherData.fromJson(weatherJson);

      AQIData? aqi;
      try {
        final aqiJson = await fetchAQI(city, WAQI_KEY);
        if (aqiJson != null) {
          aqi = AQIData.fromJson(aqiJson);
        }
      } catch (e) {
        // AQI is optional
      }

      setState(() {
        _weatherData = weather;
        _aqiData = aqi;
        _isLoading = false;

        _history.removeWhere((e) => e.city == weather.city && e.country == weather.country);
        _history.insert(0, HistoryItem(
          city: weather.city,
          country: weather.country,
          tempC: weather.temp,
          description: weather.description,
          aqiNum: aqi?.aqi,
          timestamp: DateTime.now(),
        ));
        _saveHistory();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().contains('City not found')
            ? 'City not found. Try another.'
            : 'Error: ${e.toString()}';
      });
    }
  }

  String _tempDisplay(double celsius) {
    if (_isCelsius) return celsius.toStringAsFixed(0);
    return ((celsius * 9 / 5) + 32).toStringAsFixed(0);
  }

  void _showOnboarding() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: const Color(0xFF13131e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => OnboardingSheet(
        onSave: (name, city) async {
          final prefs = await SharedPreferences.getInstance();
          if (name.isNotEmpty) await prefs.setString('userName', name);
          if (city.isNotEmpty) await prefs.setString('homeCity', city);
          await prefs.setBool('onboarded', true);

          setState(() {
            _userName = name;
            _homeCity = city;
            _onboarded = true;
            _searchController.text = city;
          });

          Navigator.pop(ctx);
          if (city.isNotEmpty) {
            await _fetchWeather(city);
            _startHomeCityRefresh();
          }
        },
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111118),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SettingsSheet(
        userName: _userName,
        homeCity: _homeCity,
        isCelsius: _isCelsius,
        history: _history,
        onNameChange: (name) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName', name);
          setState(() => _userName = name);
        },
        onHomeCityChange: (city) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('homeCity', city);
          setState(() {
            _homeCity = city;
            _searchController.text = city;
          });
          if (city.isNotEmpty) {
            await _fetchWeather(city);
            _startHomeCityRefresh();
          }
        },
        onUnitChange: (isCelsius) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isCelsius', isCelsius);
          setState(() => _isCelsius = isCelsius);
        },
        onHistoryDelete: (idx) {
          setState(() => _history.removeAt(idx));
          _saveHistory();
        },
        onHistoryLoadItem: (city) {
          Navigator.pop(ctx);
          _searchController.text = city;
          _fetchWeather(city);
        },
        onClearAllHistory: () {
          setState(() => _history.clear());
          _saveHistory();
        },
        onClearAllData: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('history');
          await prefs.remove('userName');
          await prefs.remove('homeCity');
          setState(() {
            _history.clear();
            _userName = '';
            _homeCity = '';
          });
          if (!context.mounted) return;
          Navigator.pop(context);
        },
        onExport: () => _exportData(),
        onImport: () => _importData(),
      ),
    );
  }

  Future<void> _exportData() async {
    final data = {
      'history': _history.map((e) => e.toJson()).toList(),
      'prefs': {
        'userName': _userName,
        'homeCity': _homeCity,
        'isCelsius': _isCelsius,
      },
      'exportedAt': DateTime.now().toIso8601String(),
    };
    final json = jsonEncode(data);
    debugPrint(json);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data exported to clipboard')),
    );
  }

  Future<void> _importData() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import feature coming soon')),
    );
  }

  void _showLeavingNow() {
    if (_weatherData == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => LeavingNowSheet(
        weatherData: _weatherData!,
        aqiData: _aqiData,
        isCelsius: _isCelsius,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _homeRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with greeting & settings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Syl${_userName.isNotEmpty ? '' : ''}ph',
                        style: AppFonts.display(size: 28),
                      ),
                      Text(
                        _userName.isNotEmpty
                            ? 'Good ${_getGreeting()}, ${_userName} 👋'
                            : 'Good ${_getGreeting()} — how\'s the sky?',
                        style: AppFonts.body(size: 12, color: AppColors.muted),
                      ),
                      if (_homeCity.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GestureDetector(
                            onTap: () {
                              _searchController.text = _homeCity;
                              _fetchWeather(_homeCity);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(200, 240, 78, 0.07),
                                border: Border.all(color: const Color.fromRGBO(200, 240, 78, 0.22)),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.home, size: 12, color: AppColors.accent),
                                  const SizedBox(width: 5),
                                  Text(_homeCity, style: AppFonts.body(size: 11, color: AppColors.accent)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (!_isCelsius) {
                                  _onUnitChange(true);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _isCelsius ? AppColors.accent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text('°C',
                                  style: AppFonts.body(
                                    size: 12,
                                    color: _isCelsius ? AppColors.bg : AppColors.muted,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (_isCelsius) {
                                  _onUnitChange(false);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: !_isCelsius ? AppColors.accent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text('°F',
                                  style: AppFonts.body(
                                    size: 12,
                                    color: !_isCelsius ? AppColors.bg : AppColors.muted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.settings, color: AppColors.accent),
                        onPressed: _showSettings,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.location_on, color: AppColors.muted, size: 18),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: AppFonts.body(color: AppColors.text, size: 15),
                        decoration: InputDecoration(
                          hintText: 'Tokyo, London, New York…',
                          hintStyle: AppFonts.body(color: AppColors.muted, size: 14),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onSubmitted: _fetchWeather,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _fetchWeather(_searchController.text),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text('SEARCH',
                          style: AppFonts.body(size: 11, color: AppColors.bg, weight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(240, 78, 106, 0.08),
                    border: Border.all(color: const Color.fromRGBO(240, 78, 106, 0.25)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppFonts.body(color: AppColors.danger, size: 14),
                  ),
                ),

              // Loading indicator
              if (_isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Fetching atmosphere data', style: AppFonts.label(size: 11)),
                      ],
                    ),
                  ),
                ),

              // Weather display
              if (_weatherData != null && !_isLoading) ...[
                const SizedBox(height: 28),

                // City hero
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_weatherData!.city, style: AppFonts.display(size: 48)),
                    Row(
                      children: [
                        Text(_weatherData!.country,
                          style: AppFonts.body(color: AppColors.muted, size: 13),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            width: 3, height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.muted,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Text(
                          _getLocalTime(_weatherData!.localTime),
                          style: AppFonts.body(color: AppColors.muted, size: 13),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Temperature card
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.cardTint,
                    border: Border.all(color: AppColors.cardBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_tempDisplay(_weatherData!.temp)}°',
                            style: AppFonts.display(size: 72),
                          ),
                        ],
                      ),
                      Text(
                        _weatherData!.description.capitalize(),
                        style: AppFonts.body(size: 16, color: AppColors.muted).copyWith(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Feels like ${_tempDisplay(_weatherData!.feelsLike)}°',
                            style: AppFonts.body(size: 13, color: AppColors.muted),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showInfoBottomSheet(
                              'Feels Like',
                              'Feels Like combines temperature with humidity and wind chill to show what your body actually experiences. Hot + humid feels hotter. Cold + windy feels colder.',
                            ),
                            child: Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Center(
                                child: Text('i', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Leaving now button
                GestureDetector(
                  onTap: _showLeavingNow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(200, 240, 78, 0.07),
                      border: Border.all(color: const Color.fromRGBO(200, 240, 78, 0.28)),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_right, size: 14, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text('Leaving now', style: AppFonts.body(size: 13, color: AppColors.accent)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Metrics grid
                GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildMetricCard('Humidity', '${_weatherData!.humidity}%'),
                    _buildMetricCard('Wind', '${_weatherData!.windSpeed.toStringAsFixed(1)} m/s'),
                    _buildMetricCard('Visibility', '${(_weatherData!.visibility / 1000).toStringAsFixed(1)} km'),
                    _buildMetricCard('Pressure', '${_weatherData!.pressure} hPa'),
                    _buildMetricCard('UV Index', _getUVLabel()),
                  ],
                ),
                const SizedBox(height: 20),

                // AQI Card
                if (_aqiData != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardTint,
                      border: Border.all(color: AppColors.cardBorder),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Air Quality Index', style: AppFonts.label(size: 11)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _getAQIColor(_aqiData!.aqi).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6, height: 6,
                                    decoration: BoxDecoration(
                                      color: _getAQIColor(_aqiData!.aqi),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(_getAQILabel(_aqiData!.aqi),
                                    style: AppFonts.body(size: 11, color: _getAQIColor(_aqiData!.aqi)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('${_aqiData!.aqi}', style: AppFonts.display(size: 40)),
                        if (_aqiData!.stationName != null)
                          Text(_aqiData!.stationName!, style: AppFonts.body(size: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),

                // History
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Search History', style: AppFonts.label(size: 11)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final item = _history[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () => _fetchWeather(item.city),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.cardTint,
                                border: Border.all(color: AppColors.cardBorder),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.city, style: AppFonts.body(size: 13, weight: FontWeight.w500)),
                                      Text('${item.country} · ${item.tempC.toStringAsFixed(0)}°C',
                                        style: AppFonts.body(size: 11, color: AppColors.muted),
                                      ),
                                    ],
                                  ),
                                  if (item.aqiNum != null)
                                    Text('AQI ${item.aqiNum}', style: AppFonts.label(size: 9)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 40),
              Center(
                child: Text('Made by Vijayarka', style: AppFonts.body(size: 11, color: AppColors.muted)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _onUnitChange(bool isCelsius) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isCelsius', isCelsius);
    setState(() => _isCelsius = isCelsius);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'late';
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    if (hour < 21) return 'evening';
    return 'night';
  }

  String _getLocalTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getUVLabel() {
    if (_weatherData!.weatherCode == 800 && _weatherData!.temp > 25) return 'High';
    if (_weatherData!.weatherCode == 800) return 'Moderate';
    if (_weatherData!.weatherCode >= 801 && _weatherData!.weatherCode < 803) return 'Low';
    return 'Low';
  }

  String _getAQILabel(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy';
    if (aqi <= 200) return 'Very Unhealthy';
    if (aqi <= 300) return 'Hazardous';
    return 'Critical';
  }

  Color _getAQIColor(int aqi) {
    if (aqi <= 50) return AppColors.good;
    if (aqi <= 100) return AppColors.warn;
    if (aqi <= 150) return const Color(0xFFf07f4e);
    if (aqi <= 200) return AppColors.danger;
    if (aqi <= 300) return const Color(0xFFb34ef0);
    return const Color(0xFFcc0000);
  }

  Widget _buildMetricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardTint,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppFonts.label(size: 10)),
          Text(value, style: AppFonts.display(size: 20)),
        ],
      ),
    );
  }

  void _showInfoBottomSheet(String title, String body) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppFonts.label(size: 12)),
            const SizedBox(height: 12),
            Text(body, style: AppFonts.body(size: 14, color: AppColors.text)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('Got it',
                    style: AppFonts.body(size: 12, color: AppColors.bg),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ONBOARDING SHEET
// ═══════════════════════════════════════════════════════════
class OnboardingSheet extends StatefulWidget {
  final Function(String, String) onSave;

  const OnboardingSheet({super.key, required this.onSave});

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet> {
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 32,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Syl', style: AppFonts.display(size: 32)),
            Text('ph', style: AppFonts.display(size: 32, color: AppColors.accent)),
            const SizedBox(height: 8),
            Text('Weather & air, with personality.', style: AppFonts.body(size: 13, color: AppColors.muted)),
            const SizedBox(height: 28),

            Text('What should we call you?', style: AppFonts.label(size: 11)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              style: AppFonts.body(color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Your name (optional)',
                hintStyle: AppFonts.body(color: AppColors.muted),
                filled: true,
                fillColor: const Color.fromRGBO(255, 255, 255, 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            Text('Your home city (for live updates)', style: AppFonts.label(size: 11)),
            const SizedBox(height: 8),
            TextField(
              controller: _cityCtrl,
              style: AppFonts.body(color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'e.g. Delhi, Tokyo, London…',
                hintStyle: AppFonts.body(color: AppColors.muted),
                filled: true,
                fillColor: const Color.fromRGBO(255, 255, 255, 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: () => widget.onSave(_nameCtrl.text, _cityCtrl.text),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Center(
                  child: Text('Let\'s go →', style: AppFonts.body(size: 13, color: AppColors.bg)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: () => widget.onSave('', ''),
                child: Text('Skip for now', style: AppFonts.body(size: 12, color: AppColors.muted).copyWith(decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════
//  SETTINGS SHEET
// ═══════════════════════════════════════════════════════════
class SettingsSheet extends StatefulWidget {
  final String userName;
  final String homeCity;
  final bool isCelsius;
  final List<HistoryItem> history;
  final Function(String) onNameChange;
  final Function(String) onHomeCityChange;
  final Function(bool) onUnitChange;
  final Function(int) onHistoryDelete;
  final Function(String) onHistoryLoadItem;
  final Function() onClearAllHistory;
  final Function() onClearAllData;
  final Function() onExport;
  final Function() onImport;

  const SettingsSheet({
    super.key,
    required this.userName,
    required this.homeCity,
    required this.isCelsius,
    required this.history,
    required this.onNameChange,
    required this.onHomeCityChange,
    required this.onUnitChange,
    required this.onHistoryDelete,
    required this.onHistoryLoadItem,
    required this.onClearAllHistory,
    required this.onClearAllData,
    required this.onExport,
    required this.onImport,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (ctx, controller) => SingleChildScrollView(
        controller: controller,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text('Settings', style: AppFonts.display(size: 28)),
              const SizedBox(height: 4),
              Text('Manage your Sylph preferences, history & data.',
                style: AppFonts.body(size: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 28),

              // Personalisation
              Text('PERSONALISATION', style: AppFonts.label(size: 10)),
              const SizedBox(height: 12),
              _buildSettingRow(
                'Your Name',
                widget.userName.isEmpty ? '—' : widget.userName,
                'Used for your greeting.',
                () => _promptChangeName(),
              ),
              _buildSettingRow(
                'Home City',
                widget.homeCity.isEmpty ? 'Not set' : widget.homeCity,
                'Auto-loads on startup & refreshes.',
                () => _promptChangeHomeCity(),
              ),
              const SizedBox(height: 24),

              // Display
              Text('DISPLAY', style: AppFonts.label(size: 10)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Temperature Unit', style: AppFonts.body(size: 13)),
                      Text('Switch between Celsius and Fahrenheit.',
                        style: AppFonts.body(size: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => widget.onUnitChange(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.isCelsius ? AppColors.accent : Colors.transparent,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text('°C',
                            style: AppFonts.body(size: 11, color: widget.isCelsius ? AppColors.bg : AppColors.muted),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => widget.onUnitChange(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: !widget.isCelsius ? AppColors.accent : Colors.transparent,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text('°F',
                            style: AppFonts.body(size: 11, color: !widget.isCelsius ? AppColors.bg : AppColors.muted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // History
              Text('SEARCH HISTORY', style: AppFonts.label(size: 10)),
              const SizedBox(height: 12),
              if (widget.history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No searches yet.', style: AppFonts.body(size: 12, color: AppColors.muted)),
                )
              else
                Column(
                  children: widget.history.take(5).map((item) {
                    final idx = widget.history.indexOf(item);
                    return GestureDetector(
                      onTap: () => widget.onHistoryLoadItem(item.city),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.city}, ${item.country}',
                                  style: AppFonts.body(size: 13),
                                ),
                                Text('${item.tempC.toStringAsFixed(0)}°C · ${item.description}',
                                  style: AppFonts.body(size: 11, color: AppColors.muted),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => widget.onHistoryDelete(idx),
                              child: const Icon(Icons.close, size: 16, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              if (widget.history.isNotEmpty)
                GestureDetector(
                  onTap: () => _confirmClearHistory(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text('Clear All History',
                        style: AppFonts.body(size: 12, color: AppColors.danger),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Data
              Text('DATA', style: AppFonts.label(size: 10)),
              const SizedBox(height: 12),
              _buildDataButton('Export History', widget.onExport),
              _buildDataButton('Import History', widget.onImport),
              _buildDataButton('Clear All Data', widget.onClearAllData, isDanger: true),
              const SizedBox(height: 24),

              // About
              Text('ABOUT', style: AppFonts.label(size: 10)),
              const SizedBox(height: 12),
              Text('Sylph Weather & Air',
                style: AppFonts.body(size: 13),
              ),
              Text('Data: OpenWeatherMap · WAQI · Built by Vijayarka',
                style: AppFonts.body(size: 11, color: AppColors.muted),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, String value, String desc, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppFonts.body(size: 13)),
                  Text(desc, style: AppFonts.body(size: 11, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(200, 240, 78, 0.09),
                border: Border.all(color: const Color.fromRGBO(200, 240, 78, 0.28)),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('Change',
                style: AppFonts.body(size: 11, color: AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataButton(String label, VoidCallback onTap, {bool isDanger = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(label,
              style: AppFonts.body(
                size: 12,
                color: isDanger ? AppColors.danger : AppColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _promptChangeName() {
    final ctrl = TextEditingController(text: widget.userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Your Name', style: AppFonts.body()),
        content: TextField(
          controller: ctrl,
          style: AppFonts.body(),
          decoration: InputDecoration(
            hintStyle: AppFonts.body(color: AppColors.muted),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onNameChange(ctrl.text);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _promptChangeHomeCity() {
    final ctrl = TextEditingController(text: widget.homeCity);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Home City', style: AppFonts.body()),
        content: TextField(
          controller: ctrl,
          style: AppFonts.body(),
          decoration: InputDecoration(
            hintStyle: AppFonts.body(color: AppColors.muted),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onHomeCityChange(ctrl.text);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear History?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onClearAllHistory();
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  LEAVING NOW SHEET
// ═══════════════════════════════════════════════════════════
class LeavingNowSheet extends StatelessWidget {
  final WeatherData weatherData;
  final AQIData? aqiData;
  final bool isCelsius;

  const LeavingNowSheet({
    super.key,
    required this.weatherData,
    this.aqiData,
    required this.isCelsius,
  });

  @override
  Widget build(BuildContext context) {
    final tempStr = isCelsius
        ? weatherData.temp.toStringAsFixed(0)
        : ((weatherData.temp * 9 / 5) + 32).toStringAsFixed(0);
    final feelsStr = isCelsius
        ? weatherData.feelsLike.toStringAsFixed(0)
        : ((weatherData.feelsLike * 9 / 5) + 32).toStringAsFixed(0);
    final sym = isCelsius ? '°C' : '°F';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text('Leaving now?', style: AppFonts.display(size: 28)),
            const SizedBox(height: 4),
            Text('${weatherData.city}, ${weatherData.country} · $tempStr$sym',
              style: AppFonts.body(size: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 20),

            _buildLeavingRow('🧥', 'What to wear', _getOutfitRecommendation()),
            _buildLeavingRow('☂️', 'Umbrella?', _getUmbrellaRecommendation()),
            _buildLeavingRow('😮‍💨', 'Air quality', _getAQIRecommendation()),
            _buildLeavingRow('🌡️', 'Feels like', '$feelsStr$sym · Humidity ${weatherData.humidity}%'),
            _buildLeavingRow('👁️', 'Visibility', '${(weatherData.visibility / 1000).toStringAsFixed(1)} km'),
            _buildLeavingRow('💨', 'Wind', '${weatherData.windSpeed.toStringAsFixed(1)} m/s'),

            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(200, 240, 78, 0.09),
                  border: Border.all(color: const Color.fromRGBO(200, 240, 78, 0.22)),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Center(
                  child: Text('Back to full view',
                    style: AppFonts.body(size: 12, color: AppColors.accent),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeavingRow(String icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppFonts.label(size: 10)),
                const SizedBox(height: 2),
                Text(value, style: AppFonts.body(size: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getOutfitRecommendation() {
    if (weatherData.temp < 0) return 'Max layers. Every single one.';
    if (weatherData.temp < 8) return 'Coat weather. No debate.';
    if (weatherData.temp < 16) return 'Jacket territory.';
    if (weatherData.weatherCode >= 300 && weatherData.weatherCode < 700) return 'Waterproof up.';
    if (weatherData.temp > 34) return 'As little as socially acceptable.';
    if (weatherData.temp > 27) return 'Light layers, you\'re good.';
    return 'Comfortable out there.';
  }

  String _getUmbrellaRecommendation() {
    final needsUmbrella = weatherData.weatherCode >= 300 && weatherData.weatherCode < 700;
    return needsUmbrella ? 'Yes, take one.' : 'Nope, you\'re good.';
  }

  String _getAQIRecommendation() {
    if (aqiData == null || aqiData!.aqi <= 100) return 'AQI ${aqiData?.aqi ?? '—'} · Breathable.';
    if (aqiData!.aqi <= 150) return 'AQI ${aqiData!.aqi} · Consider a mask.';
    return 'AQI ${aqiData!.aqi} · Wear a mask.';
  }
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
