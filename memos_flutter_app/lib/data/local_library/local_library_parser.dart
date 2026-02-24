import 'dart:convert';

class LocalLibraryParsedMemo {
  const LocalLibraryParsedMemo({
    required this.uid,
    required this.content,
    required this.createTime,
    required this.updateTime,
    required this.visibility,
    required this.pinned,
    required this.state,
    required this.tags,
  });

  final String uid;
  final String content;
  final DateTime createTime;
  final DateTime updateTime;
  final String visibility;
  final bool pinned;
  final String state;
  final List<String> tags;
}

LocalLibraryParsedMemo parseLocalLibraryMarkdown(String raw) {
  final lines = const LineSplitter().convert(raw);
  var meta = <String, String>{};
  var contentStart = 0;

  if (lines.isNotEmpty && lines.first.trim() == '---') {
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        meta = _parseFrontMatter(lines.sublist(1, i));
        contentStart = i + 1;
        break;
      }
    }
  }

  var contentLines = contentStart > 0 ? lines.sublist(contentStart) : lines;
  if (contentStart > 0 &&
      contentLines.isNotEmpty &&
      contentLines.first.trim().isEmpty) {
    contentLines = contentLines.sublist(1);
  }

  final content = contentLines.join('\n');
  final uid = (meta['uid'] ?? '').trim();
  final created = _parseTime(meta['created'], DateTime.now());
  final updated = _parseTime(meta['updated'], created);
  final visibility = _normalizeVisibility(meta['visibility']);
  final pinned = _parseBool(meta['pinned']);
  final state = _normalizeState(meta['state']);
  final tags = _parseTags(meta['tags']);

  return LocalLibraryParsedMemo(
    uid: uid,
    content: content,
    createTime: created,
    updateTime: updated,
    visibility: visibility,
    pinned: pinned,
    state: state,
    tags: tags,
  );
}

Map<String, String> _parseFrontMatter(List<String> lines) {
  final out = <String, String>{};
  for (final line in lines) {
    final idx = line.indexOf(':');
    if (idx <= 0) continue;
    final key = line.substring(0, idx).trim().toLowerCase();
    final value = line.substring(idx + 1).trim();
    if (key.isEmpty || value.isEmpty) continue;
    out[key] = value;
  }
  return out;
}

DateTime _parseTime(String? raw, DateTime fallback) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return fallback;
  return DateTime.tryParse(value) ?? fallback;
}

bool _parseBool(String? raw) {
  final value = raw?.trim().toLowerCase() ?? '';
  return value == 'true' || value == '1' || value == 'yes';
}

String _normalizeVisibility(String? raw) {
  final value = raw?.trim().toUpperCase() ?? '';
  return switch (value) {
    'PUBLIC' || 'PROTECTED' || 'PRIVATE' => value,
    _ => 'PRIVATE',
  };
}

String _normalizeState(String? raw) {
  final value = raw?.trim().toUpperCase() ?? '';
  return switch (value) {
    'ARCHIVED' || 'NORMAL' => value,
    _ => 'NORMAL',
  };
}

List<String> _parseTags(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return const [];
  final tags = <String>{};
  for (final part in value.split(RegExp(r'\s+'))) {
    var t = part.trim();
    if (t.startsWith('#')) {
      t = t.substring(1);
    }
    if (t.endsWith(',')) {
      t = t.substring(0, t.length - 1);
    }
    if (t.isNotEmpty) {
      tags.add(t);
    }
  }
  final list = tags.toList(growable: false);
  list.sort();
  return list;
}
