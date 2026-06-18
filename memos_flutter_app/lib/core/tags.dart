const int _maxTagLength = 100;
final RegExp _tagRuneRe = RegExp(r'[\p{L}\p{N}\p{S}\p{M}]', unicode: true);
final RegExp _tagNumericOnlyRe = RegExp(r'^\p{N}+$', unicode: true);
final RegExp _tagSymbolRe = RegExp(r'[\p{S}]', unicode: true);
final RegExp _tagInlinePattern = RegExp(
  r'#(?!#|\s)([\p{L}\p{N}\p{S}\p{M}_/\-&\u200D]{1,100})',
  unicode: true,
);
final RegExp _codeFencePattern = RegExp(r'^\s*(```|~~~)');
final List<RegExp> _protectedInlineTagPatterns = <RegExp>[
  RegExp(r'!\[[^\]]*]\([^)\n]*\)'),
  RegExp(r'\[[^\]]*]\([^)\n]*\)'),
  RegExp(r'<(?:https?|ftp):[^>\s]+>', caseSensitive: false),
  RegExp(r'<(?:mailto|tel):[^>\s]+>', caseSensitive: false),
  RegExp(r'<[^>\n]+>'),
  RegExp(
    r'(?:(?:https?|ftp):\/\/|mailto:|tel:|www\.)[^\s<>()]+',
    caseSensitive: false,
  ),
];
final RegExp _memoInternalMarkerLinePattern = RegExp(
  r'^<!--\s*(?:memoflow-third-party-share|memoflow_quick_clip:[^>]*|memoflow-share-inline:[^>]*)\s*-->$',
);

enum TagRecognitionPolicyKind { memoflowStrict, memosCompatible, custom }

enum RemoteTagHandling { localContentAuthority, mergeRemote }

class TagRecognitionCustomOptions {
  const TagRecognitionCustomOptions({
    this.strictFirstLine = true,
    this.strictLastLine = true,
    this.strictAnyLine = false,
    this.inlineBodyTags = false,
    this.numericOnlyTags = true,
    this.hierarchicalTags = true,
    this.emojiAndSymbolTags = true,
    this.remoteTagHandling = RemoteTagHandling.localContentAuthority,
  });

  static const strictDefaults = TagRecognitionCustomOptions();

  static const compatibleDefaults = TagRecognitionCustomOptions(
    strictFirstLine: false,
    strictLastLine: false,
    inlineBodyTags: true,
    numericOnlyTags: true,
    hierarchicalTags: true,
    emojiAndSymbolTags: true,
    remoteTagHandling: RemoteTagHandling.mergeRemote,
  );

  final bool strictFirstLine;
  final bool strictLastLine;
  final bool strictAnyLine;
  final bool inlineBodyTags;
  final bool numericOnlyTags;
  final bool hierarchicalTags;
  final bool emojiAndSymbolTags;
  final RemoteTagHandling remoteTagHandling;

  Map<String, dynamic> toJson() => {
    'strictFirstLine': strictFirstLine,
    'strictLastLine': strictLastLine,
    'strictAnyLine': strictAnyLine,
    'inlineBodyTags': inlineBodyTags,
    'numericOnlyTags': numericOnlyTags,
    'hierarchicalTags': hierarchicalTags,
    'emojiAndSymbolTags': emojiAndSymbolTags,
    'remoteTagHandling': remoteTagHandling.name,
  };

  factory TagRecognitionCustomOptions.fromJson(Object? raw) {
    if (raw is! Map) return strictDefaults;
    final json = raw.cast<Object?, Object?>();
    return TagRecognitionCustomOptions(
      strictFirstLine: _readBool(json['strictFirstLine'], fallback: true),
      strictLastLine: _readBool(json['strictLastLine'], fallback: true),
      strictAnyLine: _readBool(json['strictAnyLine']),
      inlineBodyTags: _readBool(json['inlineBodyTags']),
      numericOnlyTags: _readBool(json['numericOnlyTags'], fallback: true),
      hierarchicalTags: _readBool(json['hierarchicalTags'], fallback: true),
      emojiAndSymbolTags: _readBool(json['emojiAndSymbolTags'], fallback: true),
      remoteTagHandling: _readRemoteTagHandling(json['remoteTagHandling']),
    );
  }

  TagRecognitionCustomOptions copyWith({
    bool? strictFirstLine,
    bool? strictLastLine,
    bool? strictAnyLine,
    bool? inlineBodyTags,
    bool? numericOnlyTags,
    bool? hierarchicalTags,
    bool? emojiAndSymbolTags,
    RemoteTagHandling? remoteTagHandling,
  }) {
    return TagRecognitionCustomOptions(
      strictFirstLine: strictFirstLine ?? this.strictFirstLine,
      strictLastLine: strictLastLine ?? this.strictLastLine,
      strictAnyLine: strictAnyLine ?? this.strictAnyLine,
      inlineBodyTags: inlineBodyTags ?? this.inlineBodyTags,
      numericOnlyTags: numericOnlyTags ?? this.numericOnlyTags,
      hierarchicalTags: hierarchicalTags ?? this.hierarchicalTags,
      emojiAndSymbolTags: emojiAndSymbolTags ?? this.emojiAndSymbolTags,
      remoteTagHandling: remoteTagHandling ?? this.remoteTagHandling,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TagRecognitionCustomOptions &&
        strictFirstLine == other.strictFirstLine &&
        strictLastLine == other.strictLastLine &&
        strictAnyLine == other.strictAnyLine &&
        inlineBodyTags == other.inlineBodyTags &&
        numericOnlyTags == other.numericOnlyTags &&
        hierarchicalTags == other.hierarchicalTags &&
        emojiAndSymbolTags == other.emojiAndSymbolTags &&
        remoteTagHandling == other.remoteTagHandling;
  }

  @override
  int get hashCode => Object.hash(
    strictFirstLine,
    strictLastLine,
    strictAnyLine,
    inlineBodyTags,
    numericOnlyTags,
    hierarchicalTags,
    emojiAndSymbolTags,
    remoteTagHandling,
  );
}

class TagRecognitionPolicy {
  const TagRecognitionPolicy._({required this.kind, required this.options});

  static const memoflowStrict = TagRecognitionPolicy._(
    kind: TagRecognitionPolicyKind.memoflowStrict,
    options: TagRecognitionCustomOptions.strictDefaults,
  );

  static const memosCompatible = TagRecognitionPolicy._(
    kind: TagRecognitionPolicyKind.memosCompatible,
    options: TagRecognitionCustomOptions.compatibleDefaults,
  );

  static const defaultPolicy = memoflowStrict;

  factory TagRecognitionPolicy.custom(TagRecognitionCustomOptions options) {
    return TagRecognitionPolicy._(
      kind: TagRecognitionPolicyKind.custom,
      options: options,
    );
  }

  factory TagRecognitionPolicy.fromStorage(Object? raw) {
    if (raw is String) {
      return _policyFromKind(raw);
    }
    if (raw is! Map) return defaultPolicy;
    final json = raw.cast<Object?, Object?>();
    final kind = (json['kind'] ?? json['type'])?.toString().trim();
    if (kind == TagRecognitionPolicyKind.custom.name) {
      return TagRecognitionPolicy.custom(
        TagRecognitionCustomOptions.fromJson(json['options']),
      );
    }
    return _policyFromKind(kind);
  }

  final TagRecognitionPolicyKind kind;
  final TagRecognitionCustomOptions options;

  bool get isCustom => kind == TagRecognitionPolicyKind.custom;

  String get storageValue => kind.name;

  String get cacheToken {
    if (!isCustom) return kind.name;
    final options = this.options;
    return [
      kind.name,
      options.strictFirstLine ? 1 : 0,
      options.strictLastLine ? 1 : 0,
      options.strictAnyLine ? 1 : 0,
      options.inlineBodyTags ? 1 : 0,
      options.numericOnlyTags ? 1 : 0,
      options.hierarchicalTags ? 1 : 0,
      options.emojiAndSymbolTags ? 1 : 0,
      options.remoteTagHandling.name,
    ].join(':');
  }

  Map<String, dynamic> toJson() {
    if (!isCustom) return {'kind': kind.name};
    return {'kind': kind.name, 'options': options.toJson()};
  }

  TagRecognitionPolicy asCustom() =>
      isCustom ? this : TagRecognitionPolicy.custom(options);

  @override
  bool operator ==(Object other) {
    return other is TagRecognitionPolicy &&
        kind == other.kind &&
        options == other.options;
  }

  @override
  int get hashCode => Object.hash(kind, options);
}

class ContentTagMatch {
  const ContentTagMatch({required this.lineIndex, required this.match});

  final int lineIndex;
  final InlineTagMatch match;
}

class InlineTagMatch {
  const InlineTagMatch({
    required this.start,
    required this.end,
    required this.tag,
  });

  final int start;
  final int end;
  final String tag;
}

class _ProtectedRange {
  const _ProtectedRange(this.start, this.end);

  final int start;
  final int end;

  bool contains(int index) => index >= start && index < end;
}

bool _readBool(Object? raw, {bool fallback = false}) {
  if (raw is bool) return raw;
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return fallback;
}

RemoteTagHandling _readRemoteTagHandling(Object? raw) {
  final value = raw?.toString().trim();
  for (final handling in RemoteTagHandling.values) {
    if (handling.name == value) return handling;
  }
  return RemoteTagHandling.localContentAuthority;
}

TagRecognitionPolicy _policyFromKind(String? kind) {
  return switch (kind) {
    'memosCompatible' => TagRecognitionPolicy.memosCompatible,
    'memoflowStrict' => TagRecognitionPolicy.memoflowStrict,
    _ => TagRecognitionPolicy.defaultPolicy,
  };
}

bool _isValidTagRune(int rune) {
  if (rune == 0x5F ||
      rune == 0x2D ||
      rune == 0x2F ||
      rune == 0x26 ||
      rune == 0x200D) {
    return true;
  }
  return _tagRuneRe.hasMatch(String.fromCharCode(rune));
}

String normalizeTagPath(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final withoutHash = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
  final parts = withoutHash.split('/');
  final normalizedParts = <String>[];
  for (final part in parts) {
    final normalized = _normalizeTagSegment(part);
    if (normalized.isEmpty) continue;
    normalizedParts.add(normalized);
  }
  if (normalizedParts.isEmpty) return '';
  return normalizedParts.join('/');
}

String _normalizeTagSegment(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final buffer = StringBuffer();
  for (final rune in trimmed.runes) {
    if (rune == 0x2F) continue; // slash is a path separator
    if (_isValidTagRune(rune)) {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

bool isMemoInternalMarkerLine(String line) {
  return _memoInternalMarkerLinePattern.hasMatch(line.trim());
}

bool isMemoTagNonContentLine(String line) {
  final trimmed = line.trim();
  return trimmed.isEmpty || isMemoInternalMarkerLine(trimmed);
}

List<String> extractTags(
  String content, {
  TagRecognitionPolicy policy = TagRecognitionPolicy.defaultPolicy,
}) {
  final tags = <String>{};
  if (content.isEmpty) return const [];

  for (final contentMatch in findContentTagMatches(content, policy: policy)) {
    if (contentMatch.match.tag.isEmpty) continue;
    tags.add(contentMatch.match.tag);
  }

  final list = tags.toList(growable: false);
  list.sort();
  return list;
}

List<String> deriveVisibleMemoTags({
  required String content,
  Iterable<String> remoteTags = const <String>[],
  TagRecognitionPolicy policy = TagRecognitionPolicy.defaultPolicy,
}) {
  final tags = <String>{...extractTags(content, policy: policy)};
  if (policy.options.remoteTagHandling == RemoteTagHandling.mergeRemote) {
    for (final remoteTag in remoteTags) {
      final normalized = normalizeTagPath(remoteTag);
      if (normalized.isNotEmpty && _tagAllowedByPolicy(normalized, policy)) {
        tags.add(normalized);
      }
    }
  }
  final list = tags.toList(growable: false);
  list.sort();
  return list;
}

List<ContentTagMatch> findContentTagMatches(
  String content, {
  TagRecognitionPolicy policy = TagRecognitionPolicy.defaultPolicy,
  bool Function(String line)? isNonContentLine,
}) {
  if (content.isEmpty) return const [];

  final lines = content.split('\n');
  final codeLineIndexes = _collectCodeLineIndexes(lines);
  final zoneLineIndexes = _findPolicyTagZoneLineIndexes(
    lines,
    policy: policy,
    isNonContentLine: isNonContentLine,
  );
  final seen = <String>{};
  final matches = <ContentTagMatch>[];

  void addMatch(int lineIndex, InlineTagMatch match) {
    if (codeLineIndexes.contains(lineIndex)) return;
    if (!_tagAllowedByPolicy(match.tag, policy)) return;
    final key = '$lineIndex:${match.start}:${match.end}';
    if (!seen.add(key)) return;
    matches.add(ContentTagMatch(lineIndex: lineIndex, match: match));
  }

  for (final index in zoneLineIndexes) {
    if (index < 0 || index >= lines.length) continue;
    for (final match in findStrictTagZonePrefixMatches(lines[index])) {
      addMatch(index, match);
    }
  }

  if (policy.options.inlineBodyTags) {
    final nonContentLine = isNonContentLine ?? isMemoTagNonContentLine;
    for (var i = 0; i < lines.length; i++) {
      if (codeLineIndexes.contains(i) || nonContentLine(lines[i])) continue;
      for (final match in findInlineTagMatches(lines[i])) {
        addMatch(i, match);
      }
    }
  }

  matches.sort((left, right) {
    final byLine = left.lineIndex.compareTo(right.lineIndex);
    if (byLine != 0) return byLine;
    return left.match.start.compareTo(right.match.start);
  });
  return matches;
}

List<InlineTagMatch> findInlineTagMatches(String line) {
  if (line.isEmpty) return const [];
  final rawMatches = _tagInlinePattern.allMatches(line).toList(growable: false);
  if (rawMatches.isEmpty) return const [];

  final protectedRanges = _collectProtectedRanges(line);
  final matches = <InlineTagMatch>[];
  for (final match in rawMatches) {
    final tag = match.group(1);
    if (tag == null || tag.isEmpty || tag.length > _maxTagLength) {
      continue;
    }
    if (_isIndexProtected(match.start, protectedRanges)) {
      continue;
    }
    final previousRune = _previousRuneBefore(line, match.start);
    if (_shouldSkipInlineTag(previousRune)) {
      continue;
    }
    matches.add(InlineTagMatch(start: match.start, end: match.end, tag: tag));
  }
  return matches;
}

List<int> _findPolicyTagZoneLineIndexes(
  List<String> lines, {
  required TagRecognitionPolicy policy,
  bool Function(String line)? isNonContentLine,
}) {
  final options = policy.options;
  final indexes = <int>{};
  if (options.strictFirstLine || options.strictLastLine) {
    final strictIndexes = findStrictTagZoneLineIndexes(
      lines,
      isNonContentLine: isNonContentLine,
    );
    if (strictIndexes.isNotEmpty) {
      if (options.strictFirstLine) indexes.add(strictIndexes.first);
      if (options.strictLastLine) indexes.add(strictIndexes.last);
    }
  }
  if (options.strictAnyLine) {
    final nonContentLine = isNonContentLine ?? isMemoTagNonContentLine;
    for (var i = 0; i < lines.length; i++) {
      if (nonContentLine(lines[i])) continue;
      if (isStrictTagZoneLine(lines[i])) indexes.add(i);
    }
  }
  final list = indexes.toList(growable: false)..sort();
  return list;
}

List<int> findStrictTagZoneLineIndexes(
  List<String> lines, {
  bool Function(String line)? isNonContentLine,
}) {
  if (lines.isEmpty) return const <int>[];

  final nonContentLine = isNonContentLine ?? isMemoTagNonContentLine;
  int? firstLine;
  int? lastLine;
  for (var i = 0; i < lines.length; i++) {
    if (nonContentLine(lines[i])) continue;
    firstLine ??= i;
    lastLine = i;
  }

  if (firstLine == null || lastLine == null) return const <int>[];

  final indexes = <int>[];
  if (isStrictTagZoneLine(lines[firstLine])) {
    indexes.add(firstLine);
  }
  if (lastLine != firstLine && isStrictTagZoneLine(lines[lastLine])) {
    indexes.add(lastLine);
  }
  return indexes;
}

bool isStrictTagZoneLine(String line) {
  return findStrictTagZonePrefixMatches(line).isNotEmpty;
}

List<InlineTagMatch> findStrictTagZonePrefixMatches(String line) {
  if (_hasIndentedCodeBlockPrefix(line)) return const [];

  if (line.trim().isEmpty) return const [];

  final matches = findInlineTagMatches(line);
  if (matches.isEmpty) return const [];

  var cursor = 0;
  final prefixMatches = <InlineTagMatch>[];
  for (final match in matches) {
    if (!_isWhitespaceOnly(line.substring(cursor, match.start))) {
      break;
    }
    if (!_hasTokenBoundaryAfter(line, match.end)) {
      break;
    }
    prefixMatches.add(match);
    cursor = match.end;
  }

  return prefixMatches;
}

bool _hasIndentedCodeBlockPrefix(String line) {
  var columns = 0;
  for (final codeUnit in line.codeUnits) {
    if (codeUnit == 0x20) {
      columns++;
    } else if (codeUnit == 0x09) {
      columns += 4;
    } else {
      break;
    }
    if (columns >= 4) return true;
  }
  return false;
}

bool _isWhitespaceOnly(String value) => value.trim().isEmpty;

bool _hasTokenBoundaryAfter(String line, int index) {
  if (index >= line.length) return true;
  return String.fromCharCode(line.codeUnitAt(index)).trim().isEmpty;
}

bool _shouldSkipInlineTag(int? previousRune) {
  if (previousRune == null) return false;
  if (previousRune == 0x23 || previousRune == 0x5C) {
    return true;
  }
  return _isValidTagRune(previousRune);
}

int? _previousRuneBefore(String text, int index) {
  if (index <= 0) return null;
  final previousCodeUnit = text.codeUnitAt(index - 1);
  if (previousCodeUnit >= 0xDC00 && previousCodeUnit <= 0xDFFF && index >= 2) {
    final highSurrogate = text.codeUnitAt(index - 2);
    if (highSurrogate >= 0xD800 && highSurrogate <= 0xDBFF) {
      return 0x10000 +
          ((highSurrogate - 0xD800) << 10) +
          (previousCodeUnit - 0xDC00);
    }
  }
  return previousCodeUnit;
}

List<_ProtectedRange> _collectProtectedRanges(String line) {
  final ranges = <_ProtectedRange>[..._collectInlineCodeRanges(line)];
  for (final pattern in _protectedInlineTagPatterns) {
    for (final match in pattern.allMatches(line)) {
      if (match.start >= match.end) continue;
      ranges.add(_ProtectedRange(match.start, match.end));
    }
  }
  if (ranges.length < 2) return ranges;

  ranges.sort((left, right) => left.start.compareTo(right.start));
  final merged = <_ProtectedRange>[ranges.first];
  for (final range in ranges.skip(1)) {
    final last = merged.last;
    if (range.start <= last.end) {
      merged[merged.length - 1] = _ProtectedRange(
        last.start,
        range.end > last.end ? range.end : last.end,
      );
      continue;
    }
    merged.add(range);
  }
  return merged;
}

bool _isIndexProtected(int index, List<_ProtectedRange> ranges) {
  for (final range in ranges) {
    if (index < range.start) return false;
    if (range.contains(index)) return true;
  }
  return false;
}

List<_ProtectedRange> _collectInlineCodeRanges(String line) {
  final ranges = <_ProtectedRange>[];
  var index = 0;
  while (index < line.length) {
    if (line.codeUnitAt(index) != 0x60) {
      index++;
      continue;
    }
    var markerEnd = index + 1;
    while (markerEnd < line.length && line.codeUnitAt(markerEnd) == 0x60) {
      markerEnd++;
    }
    final markerLength = markerEnd - index;
    final marker = ''.padLeft(markerLength, '`');
    final close = line.indexOf(marker, markerEnd);
    if (close < 0) {
      index = markerEnd;
      continue;
    }
    ranges.add(_ProtectedRange(index, close + markerLength));
    index = close + markerLength;
  }
  return ranges;
}

Set<int> _collectCodeLineIndexes(List<String> lines) {
  final indexes = <int>{};
  var inFence = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_codeFencePattern.hasMatch(line.trimLeft())) {
      indexes.add(i);
      inFence = !inFence;
      continue;
    }
    if (inFence || _hasIndentedCodeBlockPrefix(line)) {
      indexes.add(i);
    }
  }
  return indexes;
}

bool _tagAllowedByPolicy(String tag, TagRecognitionPolicy policy) {
  final normalized = normalizeTagPath(tag);
  if (normalized.isEmpty) return false;
  final options = policy.options;
  if (!options.numericOnlyTags && _tagNumericOnlyRe.hasMatch(normalized)) {
    return false;
  }
  if (!options.hierarchicalTags && normalized.contains('/')) {
    return false;
  }
  if (!options.emojiAndSymbolTags && _tagSymbolRe.hasMatch(normalized)) {
    return false;
  }
  return true;
}
