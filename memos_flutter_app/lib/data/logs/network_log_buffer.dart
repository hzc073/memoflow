class NetworkRequestLog {
  NetworkRequestLog({
    required this.timestamp,
    required this.method,
    required this.path,
    this.query,
    this.requestBody,
    this.statusCode,
    this.statusMessage,
    this.durationMs,
    this.responseBody,
    this.errorMessage,
    this.pageSize,
    this.pageToken,
    this.nextPageToken,
    this.memosCount,
  });

  final DateTime timestamp;
  final String method;
  final String path;
  final String? query;
  final String? requestBody;
  final int? statusCode;
  final String? statusMessage;
  final int? durationMs;
  final String? responseBody;
  final String? errorMessage;
  final int? pageSize;
  final String? pageToken;
  final String? nextPageToken;
  final int? memosCount;
}

class NetworkLogBuffer {
  NetworkLogBuffer({this.maxEntries = 10});

  final int maxEntries;
  final List<NetworkRequestLog> _entries = [];

  void add(NetworkRequestLog entry) {
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
  }

  List<NetworkRequestLog> list({int limit = 10}) {
    if (limit <= 0 || _entries.isEmpty) return const [];
    final start = _entries.length > limit ? _entries.length - limit : 0;
    return List<NetworkRequestLog>.unmodifiable(_entries.sublist(start));
  }
}
