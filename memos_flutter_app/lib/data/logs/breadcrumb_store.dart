import '../../core/log_sanitizer.dart';

class BreadcrumbEntry {
  BreadcrumbEntry({
    required this.timestamp,
    required this.message,
  });

  final DateTime timestamp;
  final String message;
}

class BreadcrumbStore {
  BreadcrumbStore({this.maxEntries = 20, this.maxMessageLength = 400});

  final int maxEntries;
  final int maxMessageLength;
  final List<BreadcrumbEntry> _entries = [];

  void add(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    var sanitized = LogSanitizer.sanitizeText(trimmed).replaceAll('\n', ' ').trim();
    if (sanitized.isEmpty) return;
    if (sanitized.length > maxMessageLength) {
      sanitized = '${sanitized.substring(0, maxMessageLength)}...';
    }

    _entries.add(BreadcrumbEntry(timestamp: DateTime.now(), message: sanitized));
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
  }

  List<BreadcrumbEntry> list({int limit = 20}) {
    if (limit <= 0 || _entries.isEmpty) return const [];
    final start = _entries.length > limit ? _entries.length - limit : 0;
    return List<BreadcrumbEntry>.unmodifiable(_entries.sublist(start));
  }
}
