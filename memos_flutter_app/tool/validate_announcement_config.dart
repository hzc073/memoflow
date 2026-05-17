import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/validate_announcement_config.dart <config.json>',
    );
    exitCode = 64;
    return;
  }

  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('ERROR: Config file not found: ${args.first}');
    exitCode = 66;
    return;
  }

  final result = AnnouncementConfigValidator().validate(
    file.readAsStringSync(),
  );
  for (final error in result.errors) {
    stderr.writeln('ERROR: $error');
  }
  for (final warning in result.warnings) {
    stdout.writeln('WARNING: $warning');
  }
  if (result.errors.isNotEmpty) {
    exitCode = 1;
    return;
  }
  stdout.writeln('Announcement config validation passed.');
}

class AnnouncementValidationResult {
  const AnnouncementValidationResult({
    required this.errors,
    required this.warnings,
  });

  final List<String> errors;
  final List<String> warnings;
}

class AnnouncementConfigValidator {
  AnnouncementValidationResult validate(String rawJson) {
    final errors = <String>[];
    final warnings = <String>[];
    final Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException catch (error) {
      return AnnouncementValidationResult(
        errors: ['Invalid JSON: ${error.message}'],
        warnings: warnings,
      );
    }

    if (decoded is! Map) {
      return AnnouncementValidationResult(
        errors: ['Top-level config must be a JSON object.'],
        warnings: warnings,
      );
    }

    final root = decoded.cast<String, dynamic>();
    final ids = <String>{};
    _validateItems(
      items: _readList(root['notices']),
      kind: 'notice',
      ids: ids,
      errors: errors,
      warnings: warnings,
    );
    _validateItems(
      items: _readList(root['updates']),
      kind: 'update',
      ids: ids,
      errors: errors,
      warnings: warnings,
    );
    _validateReleaseNoteLinks(root, warnings);

    return AnnouncementValidationResult(errors: errors, warnings: warnings);
  }

  void _validateItems({
    required List<dynamic> items,
    required String kind,
    required Set<String> ids,
    required List<String> errors,
    required List<String> warnings,
  }) {
    for (var index = 0; index < items.length; index++) {
      final raw = items[index];
      if (raw is! Map) {
        errors.add('$kind[$index] must be an object.');
        continue;
      }
      final item = raw.cast<String, dynamic>();
      final path = '$kind[$index]';
      final id = _readString(item['id']);
      if (id.isEmpty) {
        errors.add('$path.id is required.');
      } else if (!ids.add(id)) {
        errors.add('Duplicate announcement id: $id.');
      }

      final status = _readString(item['status']).toLowerCase();
      if (status == 'draft') {
        errors.add('$path uses draft status in production config.');
      }

      final publishAt = _readDateTime(item['publish_at'] ?? item['publishAt']);
      final expireAt = _readDateTime(item['expire_at'] ?? item['expireAt']);
      if (status == 'public' && publishAt == null) {
        errors.add('$path.publish_at is required for public items.');
      }
      if (publishAt != null && expireAt != null) {
        if (!expireAt.isAfter(publishAt)) {
          errors.add('$path.expire_at must be after publish_at.');
        }
        if (expireAt.difference(publishAt).inDays > 45) {
          warnings.add('$path has an expiry window longer than 45 days.');
        }
      }

      if (kind == 'notice') {
        _validateNoticeContent(item, path, errors, warnings);
      } else {
        _validateUpdate(item, path, errors, warnings);
      }

      final encoded = jsonEncode(item).toLowerCase();
      if (encoded.contains('test only') ||
          encoded.contains('debug') ||
          encoded.contains('\u8349\u7a3f') ||
          encoded.contains('\u6d4b\u8bd5\u516c\u544a')) {
        warnings.add('$path contains wording that looks like test content.');
      }
    }
  }

  void _validateNoticeContent(
    Map<String, dynamic> item,
    String path,
    List<String> errors,
    List<String> warnings,
  ) {
    final content = _readMap(item['content']) ?? item;
    final body = content['body'] ?? content['contents'];
    if (!_hasLocalizedOrFallbackContent(body)) {
      errors.add('$path content body is required.');
    }
    if (!_hasEnglishContent(body)) {
      warnings.add('$path does not include English body content.');
    }
  }

  void _validateUpdate(
    Map<String, dynamic> item,
    String path,
    List<String> errors,
    List<String> warnings,
  ) {
    final force =
        _readBool(item['force']) ||
        _readBool(item['force_update']) ||
        _readBool(item['is_force']);
    final url = _readString(
      item['download_url'] ?? item['downloadUrl'] ?? item['url'],
    );
    if (force && !_isHttpUrl(url)) {
      errors.add('$path forced update requires a valid HTTP(S) download URL.');
    }
    if (_readString(item['release_note_id'] ?? item['releaseNoteId']).isEmpty) {
      warnings.add('$path does not reference a release note id.');
    }
    final channel = _readString(item['channel']).toLowerCase();
    if (channel == 'play' && url.toLowerCase().endsWith('.apk')) {
      warnings.add('$path Play-channel update points to an APK URL.');
    }
  }

  void _validateReleaseNoteLinks(
    Map<String, dynamic> root,
    List<String> warnings,
  ) {
    final releaseIds = <String>{};
    for (final raw in _readList(root['release_notes'])) {
      if (raw is! Map) continue;
      final item = raw.cast<String, dynamic>();
      final id = _readString(item['id']).ifEmpty(_readString(item['version']));
      if (id.isNotEmpty) releaseIds.add(id);
    }
    for (final raw in _readList(root['updates'])) {
      if (raw is! Map) continue;
      final item = raw.cast<String, dynamic>();
      final releaseNoteId = _readString(
        item['release_note_id'] ?? item['releaseNoteId'],
      );
      if (releaseNoteId.isNotEmpty && !releaseIds.contains(releaseNoteId)) {
        warnings.add('Update references missing release note: $releaseNoteId.');
      }
    }
  }

  bool _hasLocalizedOrFallbackContent(Object? value) {
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) {
      return value.any((entry) => entry is String && entry.trim().isNotEmpty);
    }
    if (value is Map) {
      return value.values.any(_hasLocalizedOrFallbackContent);
    }
    return false;
  }

  bool _hasEnglishContent(Object? value) {
    if (value is! Map) return false;
    final en = value['en'] ?? value['en-US'] ?? value['en_us'];
    return _hasLocalizedOrFallbackContent(en);
  }
}

List<dynamic> _readList(Object? value) => value is List ? value : const [];

Map<String, dynamic>? _readMap(Object? value) {
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

String _readString(Object? value) => value is String ? value.trim() : '';

bool _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  return false;
}

DateTime? _readDateTime(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value.trim())?.toUtc();
}

bool _isHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

extension _StringFallback on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
