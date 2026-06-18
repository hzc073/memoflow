import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('feature screens and widgets do not own tag parser internals', () async {
    const forbiddenParserApis = <String>{
      'findInlineTagMatches(',
      'findStrictTagZoneLineIndexes(',
      'findStrictTagZonePrefixMatches(',
      'findContentTagMatches(',
    };
    final violations = <String>[];

    await for (final entry in Directory(
      'lib/features',
    ).list(recursive: true, followLinks: false)) {
      if (entry is! File || p.extension(entry.path) != '.dart') continue;
      final source = _relative(entry);
      final isScreenOrWidget =
          source.endsWith('_screen.dart') || source.contains('/widgets/');
      if (!isScreenOrWidget) continue;

      final contents = await entry.readAsString();
      for (final api in forbiddenParserApis) {
        if (contents.contains(api)) {
          violations.add('$source: $api');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Feature screens/widgets must consume shared policy-aware tag '
                'results instead of owning parser internals:\n'
                '${violations.join('\n')}',
    );
  });

  test('all non-core extractTags calls pass an explicit policy', () async {
    final violations = <String>[];

    await for (final entry in Directory(
      'lib',
    ).list(recursive: true, followLinks: false)) {
      if (entry is! File || p.extension(entry.path) != '.dart') continue;
      final source = _relative(entry);
      if (source == 'lib/core/tags.dart') continue;

      final contents = await entry.readAsString();
      for (final call in _extractFunctionCalls(contents, 'extractTags')) {
        if (!call.contains('policy:')) {
          violations.add('$source: ${_singleLine(call)}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'All app call sites must provide the active TagRecognitionPolicy '
                'when extracting visible tags:\n'
                '${violations.join('\n')}',
    );
  });

  test('lower layers do not import memos or settings feature UI', () async {
    const allowedLegacyImports = <String>{
      'lib/application/desktop/desktop_quick_input_controller.dart -> lib/features/memos/link_memo_sheet.dart',
      'lib/application/startup/startup_coordinator.dart -> lib/features/memos/memo_detail_screen.dart',
      'lib/application/startup/startup_coordinator.dart -> lib/features/memos/note_input_sheet.dart',
      'lib/state/memos/desktop_memo_preview_session.dart -> lib/features/memos/memo_detail_screen.dart',
    };
    final violations = <String>[];

    for (final layer in const <String>[
      'core',
      'data',
      'application',
      'state',
    ]) {
      await for (final entry in Directory(
        'lib/$layer',
      ).list(recursive: true, followLinks: false)) {
        if (entry is! File || p.extension(entry.path) != '.dart') continue;
        final source = _relative(entry);
        final contents = await entry.readAsString();
        for (final importPath in _importPaths(contents)) {
          final target = _resolveLocalImport(source, importPath);
          if (target == null) continue;
          final forbidden =
              target.startsWith('lib/features/memos/') ||
              target.startsWith('lib/features/settings/');
          if (!forbidden) continue;
          final edge = '$source -> $target';
          if (!allowedLegacyImports.contains(edge)) violations.add(edge);
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Policy-aware lower layers must not add imports from memos or '
                'settings feature UI:\n${violations.join('\n')}',
    );
  });

  test(
    'memos connection and import flows do not switch recognition policy',
    () async {
      final roots = <Directory>[
        Directory('lib/features/import'),
        Directory('lib/application/sync'),
        Directory('lib/state/sync'),
        Directory('lib/state/system'),
      ];
      final files = <File>[
        ...await _dartFilesUnder(roots),
        ...await _dartFilesMatching(Directory('lib/state/memos'), 'import'),
      ];
      final violations = <String>[];

      for (final file in files) {
        final source = _relative(file);
        final contents = await file.readAsString();
        if (contents.contains('setTagRecognitionPolicy(')) {
          violations.add('$source: setTagRecognitionPolicy');
        }
        if (contents.contains('TagRecognitionPolicy.memosCompatible')) {
          violations.add('$source: TagRecognitionPolicy.memosCompatible');
        }
        if (contents.contains('recomputeTagRecognitionPolicy(')) {
          violations.add('$source: recomputeTagRecognitionPolicy');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Memos connection/import/sync paths must respect the existing '
                  'workspace policy and never prompt or switch to compatible '
                  'mode themselves:\n${violations.join('\n')}',
      );
    },
  );
}

Future<List<File>> _dartFilesUnder(List<Directory> roots) async {
  final files = <File>[];
  for (final root in roots) {
    if (!root.existsSync()) continue;
    await for (final entry in root.list(recursive: true, followLinks: false)) {
      if (entry is File && p.extension(entry.path) == '.dart') {
        files.add(entry);
      }
    }
  }
  return files;
}

Future<List<File>> _dartFilesMatching(Directory root, String segment) async {
  final files = <File>[];
  if (!root.existsSync()) return files;
  await for (final entry in root.list(recursive: true, followLinks: false)) {
    if (entry is! File || p.extension(entry.path) != '.dart') continue;
    if (_relative(entry).contains(segment)) files.add(entry);
  }
  return files;
}

Iterable<String> _importPaths(String contents) sync* {
  for (final match in RegExp(
    r"^import '([^']+)';",
    multiLine: true,
  ).allMatches(contents)) {
    yield match.group(1)!;
  }
}

String? _resolveLocalImport(String source, String importPath) {
  if (importPath.startsWith('package:memos_flutter_app/')) {
    return 'lib/${importPath.substring('package:memos_flutter_app/'.length)}';
  }
  if (importPath.startsWith('dart:') || importPath.startsWith('package:')) {
    return null;
  }
  final sourceDir = p.dirname(source);
  return p.normalize(p.join(sourceDir, importPath)).replaceAll('\\', '/');
}

List<String> _extractFunctionCalls(String contents, String functionName) {
  final calls = <String>[];
  var searchStart = 0;
  final needle = '$functionName(';
  while (true) {
    final start = contents.indexOf(needle, searchStart);
    if (start < 0) break;
    final end = _findClosingParen(contents, start + functionName.length);
    if (end == null) {
      calls.add(contents.substring(start));
      break;
    }
    calls.add(contents.substring(start, end + 1));
    searchStart = end + 1;
  }
  return calls;
}

int? _findClosingParen(String contents, int openingParenIndex) {
  var depth = 0;
  String? quote;
  var escaped = false;
  for (var i = openingParenIndex; i < contents.length; i++) {
    final char = contents[i];
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }
    if (char == '\'' || char == '"') {
      quote = char;
      continue;
    }
    if (char == '(') {
      depth += 1;
      continue;
    }
    if (char == ')') {
      depth -= 1;
      if (depth == 0) return i;
    }
  }
  return null;
}

String _singleLine(String value) {
  final compact = value.split(RegExp(r'\s+')).join(' ').trim();
  if (compact.length <= 120) return compact;
  return '${compact.substring(0, 120)}...';
}

String _relative(File file) {
  return p
      .relative(file.path, from: Directory.current.path)
      .replaceAll('\\', '/');
}
