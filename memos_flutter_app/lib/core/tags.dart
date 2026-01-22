const int _maxTagLength = 100;
final RegExp _tagRuneRe = RegExp(r'[\p{L}\p{N}\p{S}]', unicode: true);

bool _isValidTagRune(int rune) {
  if (rune == 0x5F || rune == 0x2D || rune == 0x2F) {
    return true;
  }
  return _tagRuneRe.hasMatch(String.fromCharCode(rune));
}

List<String> extractTags(String content) {
  final tags = <String>{};
  if (content.isEmpty) return const [];

  final lines = content.split('\n');
  int? firstLine;
  int? lastLine;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim().isEmpty) continue;
    firstLine ??= i;
    lastLine = i;
  }
  if (firstLine == null || lastLine == null) return const [];

  _extractTagsFromLine(lines[firstLine], tags);
  if (lastLine != firstLine) {
    _extractTagsFromLine(lines[lastLine], tags);
  }

  final list = tags.toList(growable: false);
  list.sort();
  return list;
}

void _extractTagsFromLine(String line, Set<String> tags) {
  if (line.isEmpty) return;
  final runes = line.runes.toList(growable: false);
  for (var i = 0; i < runes.length; i++) {
    if (runes[i] != 0x23) continue;
    if (i + 1 >= runes.length) continue;
    final next = runes[i + 1];
    if (next == 0x23 || next == 0x20) continue;

    var j = i + 1;
    var runeCount = 0;
    while (j < runes.length && _isValidTagRune(runes[j])) {
      runeCount++;
      if (runeCount > _maxTagLength) break;
      j++;
    }
    if (j == i + 1) continue;
    final tag = String.fromCharCodes(runes.sublist(i + 1, j));
    if (tag.isNotEmpty) tags.add(tag);
  }
}
