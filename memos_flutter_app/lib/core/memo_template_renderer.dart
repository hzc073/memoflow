import 'package:intl/intl.dart';

import '../data/location/amap_weather.dart';
import '../data/logs/log_manager.dart';
import '../data/models/location_settings.dart';
import '../data/models/memo_template_settings.dart';

class MemoTemplateRenderer {
  MemoTemplateRenderer({AmapWeatherClient? weatherClient})
    : _weatherClient = weatherClient ?? AmapWeatherClient();

  final AmapWeatherClient _weatherClient;

  static final RegExp _tokenPattern = RegExp(
    r'\{\{\s*([A-Za-z0-9._-]+)\s*\}\}',
  );

  Future<String> render({
    required String templateContent,
    required MemoTemplateVariableSettings variableSettings,
    required LocationSettings locationSettings,
    DateTime? now,
  }) async {
    if (templateContent.isEmpty) return templateContent;

    final at = now ?? DateTime.now();
    final date = _safeFormat(at, variableSettings.dateFormat, 'yyyy-MM-dd');
    final time = _safeFormat(at, variableSettings.timeFormat, 'HH:mm');
    final dateTime = _safeFormat(
      at,
      variableSettings.dateTimeFormat,
      'yyyy-MM-dd HH:mm',
    );
    final weekday = _safeFormat(at, 'EEEE', 'EEEE');

    final tokens = <String, String>{
      'date': date,
      'time': time,
      'datetime': dateTime,
      'weekday': weekday,
    };

    final needsWeather = _tokenPattern
        .allMatches(templateContent)
        .any(
          (match) =>
              (match.group(1) ?? '').trim().toLowerCase().startsWith('weather'),
        );
    final weatherFallback = variableSettings.weatherFallback.trim().isEmpty
        ? MemoTemplateVariableSettings.defaults.weatherFallback
        : variableSettings.weatherFallback.trim();

    if (needsWeather) {
      final weather = await _resolveWeather(
        variableSettings: variableSettings,
        locationSettings: locationSettings,
      );
      final weatherTokens = _weatherTokens(weather, fallback: weatherFallback);
      tokens.addAll(weatherTokens);
    }

    return templateContent.replaceAllMapped(_tokenPattern, (match) {
      final rawToken = match.group(0) ?? '';
      final key = (match.group(1) ?? '').trim().toLowerCase();
      if (key.isEmpty) return rawToken;
      final value = tokens[key];
      if (value != null) return value;
      if (key.startsWith('weather')) return weatherFallback;
      if (variableSettings.keepUnknownVariables) return rawToken;
      return '';
    });
  }

  String _safeFormat(DateTime value, String pattern, String fallbackPattern) {
    final normalized = pattern.trim().isEmpty
        ? fallbackPattern
        : pattern.trim();
    try {
      return DateFormat(normalized).format(value);
    } catch (_) {
      return DateFormat(fallbackPattern).format(value);
    }
  }

  Future<AmapWeatherLive?> _resolveWeather({
    required MemoTemplateVariableSettings variableSettings,
    required LocationSettings locationSettings,
  }) async {
    if (!variableSettings.weatherEnabled) {
      LogManager.instance.debug(
        'Template weather skipped: weather variable is disabled',
      );
      return null;
    }

    final city = variableSettings.weatherCity.trim();
    final apiKey = locationSettings.amapWebKey.trim();
    if (city.isEmpty || apiKey.isEmpty) {
      LogManager.instance.warn(
        'Template weather skipped: city or AMap Web Key is empty',
        context: {
          'city': city.isEmpty ? '<empty>' : city,
          'hasApiKey': apiKey.isNotEmpty,
          'hasSecurityKey': locationSettings.amapSecurityKey.trim().isNotEmpty,
        },
      );
      return null;
    }

    LogManager.instance.debug(
      'Template weather fetch requested',
      context: {
        'city': city,
        'hasApiKey': true,
        'hasSecurityKey': locationSettings.amapSecurityKey.trim().isNotEmpty,
      },
    );

    final live = await _weatherClient.fetchLiveWeather(
      apiKey: apiKey,
      securityKey: locationSettings.amapSecurityKey,
      city: city,
    );

    if (live == null) {
      LogManager.instance.warn(
        'Template weather fetch returned null, fallback text will be used',
      );
    }
    return live;
  }

  Map<String, String> _weatherTokens(
    AmapWeatherLive? live, {
    required String fallback,
  }) {
    if (live == null) {
      return <String, String>{
        'weather': fallback,
        'weather.summary': fallback,
        'weather.city': fallback,
        'weather.province': fallback,
        'weather.condition': fallback,
        'weather.temperature': fallback,
        'weather.humidity': fallback,
        'weather.wind_direction': fallback,
        'weather.wind_power': fallback,
        'weather.report_time': fallback,
        'weather.adcode': fallback,
      };
    }

    final city = live.city.isEmpty ? live.province : live.city;
    final condition = live.weather.isEmpty ? fallback : live.weather;
    final temperature = live.temperature.isEmpty
        ? fallback
        : '${live.temperature}℃';

    final weatherParts = <String>[
      if (condition.trim().isNotEmpty) condition.trim(),
      if (temperature.trim().isNotEmpty) temperature.trim(),
    ];
    final weather = weatherParts.isEmpty ? fallback : weatherParts.join(' ');

    final summaryParts = <String>[
      if (city.trim().isNotEmpty) city.trim(),
      ...weatherParts,
    ];
    final summary = summaryParts.isEmpty ? fallback : summaryParts.join(' ');

    String readOrFallback(String value) {
      final normalized = value.trim();
      return normalized.isEmpty ? fallback : normalized;
    }

    return <String, String>{
      'weather': weather,
      'weather.summary': summary,
      'weather.city': readOrFallback(live.city),
      'weather.province': readOrFallback(live.province),
      'weather.condition': readOrFallback(live.weather),
      'weather.temperature': readOrFallback(live.temperature),
      'weather.humidity': readOrFallback(live.humidity),
      'weather.wind_direction': readOrFallback(live.windDirection),
      'weather.wind_power': readOrFallback(live.windPower),
      'weather.report_time': readOrFallback(live.reportTime),
      'weather.adcode': readOrFallback(live.adcode),
    };
  }
}
