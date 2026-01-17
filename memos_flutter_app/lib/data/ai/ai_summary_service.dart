import 'dart:convert';

import 'package:dio/dio.dart';

import '../settings/ai_settings_repository.dart';

class AiSummaryResult {
  const AiSummaryResult({
    required this.insights,
    required this.moodTrend,
    required this.keywords,
    required this.raw,
  });

  final List<String> insights;
  final String moodTrend;
  final List<String> keywords;
  final String raw;

  static const empty = AiSummaryResult(
    insights: <String>[],
    moodTrend: '',
    keywords: <String>[],
    raw: '',
  );
}

class AiSummaryService {
  AiSummaryService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
              ),
            );

  final Dio _dio;

  Future<AiSummaryResult> generateSummary({
    required AiSettings settings,
    required String memoText,
    required String rangeLabel,
    required int memoCount,
    required int includedCount,
    String? customPrompt,
  }) async {
    final trimmedKey = settings.apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw StateError('API Key 为空');
    }

    final isAnthropic = _isAnthropic(settings);
    final baseUrl = _normalizeBase(settings.apiUrl, ensureV1: true);
    final endpoint = _resolveEndpoint(
      baseUrl,
      isAnthropic ? 'messages' : 'chat/completions',
    );
    final systemPrompt = _buildSystemPrompt(settings);
    final userPrompt = _buildUserPrompt(
      settings: settings,
      memoText: memoText,
      rangeLabel: rangeLabel,
      memoCount: memoCount,
      includedCount: includedCount,
      customPrompt: customPrompt,
    );

    final response = isAnthropic
        ? await _callAnthropic(
            endpoint: endpoint,
            apiKey: trimmedKey,
            model: settings.model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
          )
        : await _callOpenAi(
            endpoint: endpoint,
            apiKey: trimmedKey,
            model: settings.model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
          );

    return _parseSummary(response);
  }

  bool _isAnthropic(AiSettings settings) {
    final url = settings.apiUrl.toLowerCase();
    final model = settings.model.toLowerCase();
    return url.contains('anthropic') || model.contains('claude');
  }

  String _buildSystemPrompt(AiSettings settings) {
    final base = settings.prompt.trim();
    return [
      if (base.isNotEmpty) base,
      '请严格输出 JSON，不要使用代码块，不要额外说明文字。',
      'JSON 格式：{"insights":["..."],"moodTrend":"...","keywords":["#..."]}',
      'insights 控制在 2-5 条，keywords 为 4-8 个带 # 的词。',
    ].join('\n');
  }

  String _buildUserPrompt({
    required AiSettings settings,
    required String memoText,
    required String rangeLabel,
    required int memoCount,
    required int includedCount,
    String? customPrompt,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('时间范围：$rangeLabel');
    buffer.writeln('笔记条数：$memoCount（提供用于总结：$includedCount）');
    final profile = settings.userProfile.trim();
    if (profile.isNotEmpty) {
      buffer.writeln('用户背景：$profile');
    }
    if (customPrompt != null && customPrompt.trim().isNotEmpty) {
      buffer.writeln('用户补充指令：${customPrompt.trim()}');
    }
    buffer.writeln('笔记内容：');
    buffer.writeln(memoText.trim());
    return buffer.toString();
  }

  Future<String> _callOpenAi({
    required String endpoint,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final response = await _dio.post(
      endpoint,
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': model,
        'temperature': 0.4,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw StateError('AI 响应格式不正确');
    }
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw StateError('AI 响应为空');
    }
    final first = choices.first;
    if (first is Map) {
      final message = first['message'];
      if (message is Map && message['content'] is String) {
        return message['content'] as String;
      }
      if (first['text'] is String) {
        return first['text'] as String;
      }
    }
    throw StateError('AI 响应内容缺失');
  }

  Future<String> _callAnthropic({
    required String endpoint,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final response = await _dio.post(
      endpoint,
      options: Options(
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': model,
        'max_tokens': 900,
        'temperature': 0.4,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': userPrompt},
        ],
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw StateError('AI 响应格式不正确');
    }
    final content = data['content'];
    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is Map && item['text'] is String) {
          buffer.write(item['text']);
        }
      }
      final text = buffer.toString();
      if (text.isNotEmpty) return text;
    }
    if (content is String && content.isNotEmpty) {
      return content;
    }
    throw StateError('AI 响应内容缺失');
  }

  AiSummaryResult _parseSummary(String rawText) {
    final cleaned = _stripCodeFence(rawText.trim());
    final jsonText = _extractJson(cleaned);
    if (jsonText != null) {
      try {
        final decoded = jsonDecode(jsonText);
        if (decoded is Map) {
          final insights = _readStringList(decoded['insights']);
          final moodTrend = _readString(decoded['moodTrend']);
          final keywords = _readStringList(decoded['keywords']);
          return AiSummaryResult(
            insights: insights,
            moodTrend: moodTrend,
            keywords: keywords,
            raw: rawText,
          );
        }
      } catch (_) {}
    }

    final fallbackInsights = _splitLines(cleaned);
    return AiSummaryResult(
      insights: fallbackInsights,
      moodTrend: '',
      keywords: _extractKeywords(cleaned),
      raw: rawText,
    );
  }

  String _stripCodeFence(String text) {
    if (!text.startsWith('```')) return text;
    final trimmed = text.replaceAll(RegExp(r'^```[a-zA-Z]*'), '');
    return trimmed.replaceAll('```', '').trim();
  }

  String? _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    return text.substring(start, end + 1);
  }

  List<String> _readStringList(Object? value) {
    if (value is List) {
      return value.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  String _readString(Object? value) {
    if (value is String) return value.trim();
    return '';
  }

  List<String> _splitLines(String text) {
    final lines = text.split(RegExp(r'[\r\n]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.isEmpty) return const [];
    return lines.take(4).toList(growable: false);
  }

  List<String> _extractKeywords(String text) {
    final matches = RegExp(r'#[\\w\\u4e00-\\u9fa5]+').allMatches(text);
    final keywords = <String>{};
    for (final match in matches) {
      final value = match.group(0);
      if (value != null && value.trim().isNotEmpty) {
        keywords.add(value.trim());
      }
    }
    return keywords.toList(growable: false);
  }

  String _normalizeBase(String base, {required bool ensureV1}) {
    var trimmed = base.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (ensureV1 && !trimmed.contains('/v1')) {
      trimmed = '$trimmed/v1';
    }
    return trimmed;
  }

  String _resolveEndpoint(String base, String path) {
    if (base.endsWith('/$path') || base.contains('/$path')) {
      return base;
    }
    return '$base/$path';
  }
}
