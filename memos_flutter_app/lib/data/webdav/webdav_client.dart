import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../core/log_sanitizer.dart';
import '../logs/debug_log_store.dart';
import '../models/webdav_settings.dart';

class WebDavResponse {
  WebDavResponse({
    required this.statusCode,
    required this.headers,
    required this.bytes,
    this.reasonPhrase,
  });

  final int statusCode;
  final Map<String, String> headers;
  final List<int> bytes;
  final String? reasonPhrase;

  String get bodyText => utf8.decode(bytes, allowMalformed: true);
}

class WebDavClient {
  WebDavClient({
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.authMode,
    required this.ignoreBadCert,
    this.logWriter,
  }) {
    if (ignoreBadCert) {
      _client.badCertificateCallback = (_, _, _) => true;
    }
  }

  final Uri baseUrl;
  final String username;
  final String password;
  final WebDavAuthMode authMode;
  final bool ignoreBadCert;
  final void Function(DebugLogEntry entry)? logWriter;

  final HttpClient _client = HttpClient();
  _DigestAuthState? _digestState;

  Future<void> close() async {
    _client.close(force: true);
  }

  Future<WebDavResponse> get(Uri url, {Map<String, String>? headers}) {
    return _send('GET', url, headers: headers);
  }

  Future<WebDavResponse> head(Uri url, {Map<String, String>? headers}) {
    return _send('HEAD', url, headers: headers);
  }

  Future<WebDavResponse> put(
    Uri url, {
    Map<String, String>? headers,
    List<int>? body,
  }) {
    return _send('PUT', url, headers: headers, body: body);
  }

  Future<WebDavResponse> mkcol(Uri url, {Map<String, String>? headers}) {
    return _send('MKCOL', url, headers: headers);
  }

  Future<WebDavResponse> delete(Uri url, {Map<String, String>? headers}) {
    return _send('DELETE', url, headers: headers);
  }

  Future<WebDavResponse> _send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    List<int>? body,
  }) async {
    final response = await _sendOnce(method, url, headers: headers, body: body);
    if (response.statusCode != 401 || authMode != WebDavAuthMode.digest) {
      return response;
    }
    final challenge = _parseDigestChallenge(response.headers['www-authenticate']);
    if (challenge == null) return response;
    _digestState = challenge;
    return _sendOnce(method, url, headers: headers, body: body, forceDigest: true);
  }

  Future<WebDavResponse> _sendOnce(
    String method,
    Uri url, {
    Map<String, String>? headers,
    List<int>? body,
    bool forceDigest = false,
  }) async {
    final startedAt = DateTime.now();
    try {
      final request = await _client.openUrl(method, url);
      request.headers.set('User-Agent', 'MemoFlow');
      if (headers != null) {
        headers.forEach(request.headers.set);
      }
      final authHeader = _buildAuthHeader(method, url, forceDigest: forceDigest);
      if (authHeader != null) {
        request.headers.set(HttpHeaders.authorizationHeader, authHeader);
      }
      if (body != null) {
        request.add(body);
      }
      final response = await request.close();
      final bytes =
          await response.fold<List<int>>(<int>[], (p, e) => p..addAll(e));
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        if (values.isNotEmpty) {
          responseHeaders[name.toLowerCase()] = values.join(',');
        }
      });
      _emitLog(
        method: method,
        url: url,
        status: response.statusCode,
        durationMs: DateTime.now().difference(startedAt).inMilliseconds,
      );
      return WebDavResponse(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        headers: responseHeaders,
        bytes: bytes,
      );
    } catch (e) {
      _emitLog(
        method: method,
        url: url,
        durationMs: DateTime.now().difference(startedAt).inMilliseconds,
        error: e,
      );
      rethrow;
    }
  }

  void _emitLog({
    required String method,
    required Uri url,
    int? status,
    int? durationMs,
    Object? error,
  }) {
    final writer = logWriter;
    if (writer == null) return;
    final detailParts = <String>[
      'auth=${authMode.name}',
      ignoreBadCert ? 'tls=ignored' : 'tls=verified',
    ];
    writer(
      DebugLogEntry(
        timestamp: DateTime.now(),
        category: 'webdav',
        label: 'WebDAV $method',
        detail: detailParts.join(' · '),
        method: method,
        url: LogSanitizer.maskUrl(url.toString()),
        status: status,
        durationMs: durationMs,
        error: error == null
            ? null
            : LogSanitizer.sanitizeText(error.toString()),
      ),
    );
  }

  String? _buildAuthHeader(String method, Uri url, {required bool forceDigest}) {
    if (authMode == WebDavAuthMode.basic) {
      if (username.isEmpty && password.isEmpty) return null;
      final credentials = base64Encode(utf8.encode('$username:$password'));
      return 'Basic $credentials';
    }
    if (authMode != WebDavAuthMode.digest) return null;
    if (username.isEmpty && password.isEmpty) return null;
    final state = _digestState;
    if (state == null && !forceDigest) {
      return null;
    }
    final resolved = state ?? _digestState;
    if (resolved == null) return null;
    final uri = _requestUri(url);
    resolved.nonceCount += 1;
    final nc = resolved.nonceCount.toRadixString(16).padLeft(8, '0');
    final cnonce = _randomHex(16);
    final qop = resolved.qop;
    final ha1 = _md5('$username:$resolved.realm:$password');
    final ha2 = _md5('$method:$uri');
    final response = qop.isNotEmpty
        ? _md5('$ha1:$resolved.nonce:$nc:$cnonce:$qop:$ha2')
        : _md5('$ha1:$resolved.nonce:$ha2');

    final buffer = StringBuffer('Digest ');
    buffer.write('username="$username", realm="$resolved.realm", nonce="$resolved.nonce", uri="$uri", ');
    buffer.write('response="$response"');
    if (resolved.opaque.isNotEmpty) {
      buffer.write(', opaque="$resolved.opaque"');
    }
    if (resolved.algorithm.isNotEmpty) {
      buffer.write(', algorithm=$resolved.algorithm');
    }
    if (qop.isNotEmpty) {
      buffer.write(', qop=$qop, nc=$nc, cnonce="$cnonce"');
    }
    return buffer.toString();
  }

  String _requestUri(Uri url) {
    final path = url.path.isEmpty ? '/' : url.path;
    if (url.hasQuery) {
      return '$path?${url.query}';
    }
    return path;
  }

  _DigestAuthState? _parseDigestChallenge(String? header) {
    if (header == null || header.trim().isEmpty) return null;
    final match = RegExp(r'digest', caseSensitive: false).firstMatch(header);
    if (match == null) return null;
    final params = header.substring(match.end).trim();
    final map = <String, String>{};
    final parts = params.split(RegExp(r',\s*'));
    for (final part in parts) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      final key = part.substring(0, idx).trim();
      var value = part.substring(idx + 1).trim();
      if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
        value = value.substring(1, value.length - 1);
      }
      map[key] = value;
    }
    final realm = map['realm'] ?? '';
    final nonce = map['nonce'] ?? '';
    if (realm.isEmpty || nonce.isEmpty) return null;
    final qop = _resolveQop(map['qop'] ?? '');
    final algorithm = map['algorithm'] ?? 'MD5';
    return _DigestAuthState(
      realm: realm,
      nonce: nonce,
      qop: qop,
      algorithm: algorithm,
      opaque: map['opaque'] ?? '',
    );
  }

  String _resolveQop(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(',').map((e) => e.trim()).toList();
    if (parts.contains('auth')) return 'auth';
    return parts.first;
  }

  String _md5(String input) => md5.convert(utf8.encode(input)).toString();

  String _randomHex(int length) {
    final rng = Random.secure();
    final bytes = List<int>.generate(length, (_) => rng.nextInt(256));
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

class _DigestAuthState {
  _DigestAuthState({
    required this.realm,
    required this.nonce,
    required this.qop,
    required this.algorithm,
    required this.opaque,
  });

  final String realm;
  final String nonce;
  final String qop;
  final String algorithm;
  final String opaque;
  int nonceCount = 0;
}
