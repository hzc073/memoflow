import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/memoflow_palette.dart';
import '../../core/url.dart';
import '../../data/api/server_api_profile.dart';
import '../../data/logs/debug_log_store.dart';
import '../../data/models/user.dart';
import '../../state/debug_log_provider.dart';
import '../../state/login_draft_provider.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import '../auth/login_screen.dart';
import '../debug/debug_logs_screen.dart';
import '../onboarding/language_selection_screen.dart';
import '../../i18n/strings.g.dart';

class DebugToolsScreen extends ConsumerStatefulWidget {
  const DebugToolsScreen({super.key});

  @override
  ConsumerState<DebugToolsScreen> createState() => _DebugToolsScreenState();
}

class _DebugSignInResult {
  _DebugSignInResult({
    required this.user,
    required this.token,
    required this.response,
  });

  final User user;
  final String? token;
  final Response response;
}

class _DebugApiResult {
  _DebugApiResult({
    required this.method,
    required this.path,
    required this.status,
    required this.durationMs,
    required this.responseBody,
    required this.error,
  });

  final String method;
  final String path;
  final int? status;
  final int durationMs;
  final String responseBody;
  final String? error;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
    );
  }
}

class _CardGroup extends StatelessWidget {
  const _CardGroup({
    required this.card,
    required this.divider,
    required this.children,
  });

  final Color card;
  final Color divider;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(height: 1, color: divider),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.card, required this.isDark, required this.child});

  final Color card;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.textMain,
    required this.textMuted,
  });

  final String label;
  final String value;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: textMuted),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.obscureText,
    required this.textMain,
    required this.textMuted,
    required this.enabled,
    this.minLines,
    this.maxLines = 1,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final Color textMain;
  final Color textMuted;
  final bool enabled;
  final int? minLines;
  final int maxLines;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: textMuted.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            enabled: enabled,
            minLines: minLines,
            maxLines: maxLines,
            style: TextStyle(color: textMain, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: textMuted.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    );
  }
}

class _ApiResultCard extends StatelessWidget {
  const _ApiResultCard({
    required this.result,
    required this.textMain,
    required this.textMuted,
  });

  final _DebugApiResult result;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    final statusLabel = result.status == null ? '-' : 'HTTP ${result.status}';
    final error = result.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: textMuted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.method} ${result.path}',
            style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 4),
          Text(
            '$statusLabel · ${result.durationMs}ms',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
          if (error != null && error.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              error,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ],
          if (result.responseBody.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              result.responseBody,
              style: TextStyle(fontSize: 12, color: textMain),
            ),
          ],
        ],
      ),
    );
  }
}

class _DebugToolsScreenState extends ConsumerState<DebugToolsScreen> {
  static final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tokenController = TextEditingController();
  final _apiPathController = TextEditingController(text: '/api/v1/auth/me');
  final _apiQueryController = TextEditingController();
  final _apiBodyController = TextEditingController();

  var _loginBusy = false;
  var _apiBusy = false;
  var _obscurePassword = true;
  var _obscureToken = true;
  String? _activeToken;
  String _activeTokenSource = '';
  String? _lastLoginUser;
  _DebugApiResult? _lastApiResult;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    _apiPathController.dispose();
    _apiQueryController.dispose();
    _apiBodyController.dispose();
    super.dispose();
  }

  Uri? _resolveBaseUrl() {
    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    if (account != null) return account.baseUrl;
    final draft = ref.read(loginBaseUrlDraftProvider).trim();
    if (draft.isEmpty) return null;
    final parsed = Uri.tryParse(draft);
    if (parsed == null || parsed.scheme.isEmpty) return null;
    return parsed;
  }

  String _normalizeTokenInput(String raw) {
    var token = raw.trim();
    if (token.isEmpty) return token;
    final match = RegExp(
      r'^(?:authorization:\\s*)?bearer\\s+',
      caseSensitive: false,
    ).firstMatch(token);
    if (match != null) {
      token = token.substring(match.end).trim();
    }
    if (token.contains(RegExp(r'\\s'))) {
      token = token.replaceAll(RegExp(r'\\s+'), '');
    }
    return token;
  }

  String _tokenPreview(String token) {
    if (token.length <= 8) return token;
    final head = token.substring(0, 6);
    final tail = token.substring(token.length - 4);
    return '$head...$tail';
  }

  String _apiVersionBandLabel(MemosVersionNumber? version) {
    if (version == null) return '-';
    if (version.major == 0 && version.minor >= 20 && version.minor < 30) {
      return '0.2x';
    }
    return '${version.major}.${version.minor}x';
  }

  String _apiRouteVersionLabel(MemosVersionResolution? resolution) {
    if (resolution == null) return '-';
    final band = _apiVersionBandLabel(resolution.parsedVersion);
    final effective = resolution.effectiveVersion.trim();
    final flavor = resolution.profile.flavor.name;
    if (effective.isEmpty) return '$band | $flavor';
    return '$band | $effective | $flavor';
  }

  Future<void> _logAction(String label, {String? detail}) async {
    await ref
        .read(debugLogStoreProvider)
        .add(
          DebugLogEntry(
            timestamp: DateTime.now().toUtc(),
            category: 'action',
            label: label,
            detail: detail,
          ),
        );
  }

  Future<void> _logApi({
    required String label,
    required String method,
    required String url,
    int? status,
    int? durationMs,
    String? requestHeaders,
    String? requestBody,
    String? responseHeaders,
    String? responseBody,
    String? error,
  }) async {
    await ref
        .read(debugLogStoreProvider)
        .add(
          DebugLogEntry(
            timestamp: DateTime.now().toUtc(),
            category: 'api',
            label: label,
            method: method,
            url: url,
            status: status,
            durationMs: durationMs,
            requestHeaders: requestHeaders,
            requestBody: requestBody,
            responseHeaders: responseHeaders,
            responseBody: responseBody,
            error: error,
          ),
        );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, String> _flattenHeaders(Headers headers) {
    final out = <String, String>{};
    headers.map.forEach((key, values) {
      out[key] = values.join('; ');
    });
    return out;
  }

  String? _extractAccessToken(Map<String, dynamic> body) {
    final raw = body['accessToken'] ?? body['access_token'] ?? body['token'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw != null) return raw.toString().trim();
    return null;
  }

  String? _extractAccessTokenFromSetCookie(Headers headers) {
    final raw = headers.map['set-cookie'];
    if (raw == null || raw.isEmpty) return null;
    for (final entry in raw) {
      final parts = entry.split(';');
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.startsWith('memos.access-token=')) {
          return trimmed.substring('memos.access-token='.length).trim();
        }
      }
    }
    return null;
  }

  bool _shouldFallback(DioException e) {
    final status = e.response?.statusCode ?? 0;
    return status == 404 || status == 405;
  }

  Future<_DebugSignInResult> _signInV1({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: dioBaseUrlString(baseUrl),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final response = await dio.post(
      'api/v1/auth/signin',
      data: {
        'passwordCredentials': {'username': username, 'password': password},
      },
    );
    final body = _expectJsonMap(response.data);
    final userJson = body['user'] is Map ? body['user'] as Map : body;
    final user = User.fromJson(userJson.cast<String, dynamic>());
    final token =
        _extractAccessToken(body) ??
        _extractAccessTokenFromSetCookie(response.headers);
    return _DebugSignInResult(user: user, token: token, response: response);
  }

  Future<_DebugSignInResult> _signInV2({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: dioBaseUrlString(baseUrl),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final response = await dio.post(
      'api/v2/auth/signin',
      data: {'username': username, 'password': password},
    );
    final body = _expectJsonMap(response.data);
    final userJson = body['user'] is Map ? body['user'] as Map : body;
    final user = User.fromJson(userJson.cast<String, dynamic>());
    final token =
        _extractAccessToken(body) ??
        _extractAccessTokenFromSetCookie(response.headers);
    return _DebugSignInResult(user: user, token: token, response: response);
  }

  Future<void> _signIn() async {
    if (_loginBusy) return;
    final baseUrl = _resolveBaseUrl();
    if (baseUrl == null) {
      _showMessage(context.t.strings.legacy.msg_server_url_unavailable);
      return;
    }
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      _showMessage(context.t.strings.legacy.msg_enter_username_password);
      return;
    }

    setState(() => _loginBusy = true);
    final started = DateTime.now();
    final useLegacyApi = ref.read(appPreferencesProvider).useLegacyApi;
    _DebugSignInResult? result;
    DioException? lastDio;
    Object? lastError;

    final attempts = useLegacyApi
        ? <Future<_DebugSignInResult> Function()>[
            () => _signInV2(
              baseUrl: baseUrl,
              username: username,
              password: password,
            ),
            () => _signInV1(
              baseUrl: baseUrl,
              username: username,
              password: password,
            ),
          ]
        : <Future<_DebugSignInResult> Function()>[
            () => _signInV1(
              baseUrl: baseUrl,
              username: username,
              password: password,
            ),
            () => _signInV2(
              baseUrl: baseUrl,
              username: username,
              password: password,
            ),
          ];

    for (final attempt in attempts) {
      try {
        result = await attempt();
        break;
      } on DioException catch (e) {
        lastDio = e;
        lastError = e;
        if (!_shouldFallback(e)) break;
      } catch (e) {
        lastError = e;
        break;
      }
    }

    if (!mounted) return;
    setState(() => _loginBusy = false);

    if (result == null) {
      final message = lastDio?.response?.data is Map
          ? (lastDio?.response?.data['message']?.toString() ?? lastDio?.message)
          : lastError?.toString();
      await _logApi(
        label: 'Sign in',
        method: lastDio?.requestOptions.method.toUpperCase() ?? 'POST',
        url:
            lastDio?.requestOptions.uri.toString() ??
            joinBaseUrl(baseUrl, 'api/v1/auth/signin'),
        status: lastDio?.response?.statusCode,
        durationMs: DateTime.now().difference(started).inMilliseconds,
        requestHeaders: lastDio == null
            ? null
            : jsonEncode(lastDio.requestOptions.headers),
        requestBody: jsonEncode({'username': username, 'password': password}),
        responseHeaders: lastDio?.response == null
            ? null
            : jsonEncode(_flattenHeaders(lastDio!.response!.headers)),
        responseBody: _stringifyBody(lastDio?.response?.data),
        error: message,
      );
      if (!mounted) return;
      _showMessage(
        context.t.strings.legacy.msg_sign_failed(
          message: message ?? context.t.strings.legacy.msg_request_failed,
        ),
      );
      return;
    }

    final _DebugSignInResult resolved = result;
    final response = resolved.response;
    final requestBody = jsonEncode({
      'username': username,
      'password': password,
    });
    final responseBody = _stringifyBody(response.data);
    await _logApi(
      label: 'Sign in',
      method: response.requestOptions.method.toUpperCase(),
      url: response.requestOptions.uri.toString(),
      status: response.statusCode,
      durationMs: DateTime.now().difference(started).inMilliseconds,
      requestHeaders: jsonEncode(response.requestOptions.headers),
      requestBody: requestBody,
      responseHeaders: jsonEncode(_flattenHeaders(response.headers)),
      responseBody: responseBody,
    );
    if (!mounted) return;

    final user = resolved.user;
    final token = resolved.token?.trim();
    setState(() {
      _lastLoginUser = user.displayName.isNotEmpty
          ? user.displayName
          : user.username;
      if (token != null && token.isNotEmpty) {
        _activeToken = token;
        _activeTokenSource = 'signin';
      }
    });
    if (token == null || token.isEmpty) {
      _showMessage(context.t.strings.legacy.msg_signed_but_no_token_returned);
      return;
    }
    _showMessage(context.t.strings.legacy.msg_signed);
  }

  void _setManualToken() {
    final raw = _tokenController.text;
    final token = _normalizeTokenInput(raw);
    if (token.isEmpty) {
      _showMessage(context.t.strings.legacy.msg_enter_token);
      return;
    }
    setState(() {
      _activeToken = token;
      _activeTokenSource = 'manual';
    });
    _logAction('Set token', detail: 'manual');
    _showMessage(context.t.strings.legacy.msg_token_applied);
  }

  void _clearToken() {
    setState(() {
      _activeToken = null;
      _activeTokenSource = '';
    });
    _logAction('Clear token');
  }

  Future<void> _sendApiRequest({required String method}) async {
    if (_apiBusy) return;
    final baseUrl = _resolveBaseUrl();
    if (baseUrl == null) {
      _showMessage(context.t.strings.legacy.msg_server_url_unavailable);
      return;
    }
    final path = _apiPathController.text.trim();
    if (path.isEmpty) {
      _showMessage(context.t.strings.legacy.msg_enter_api_path);
      return;
    }
    if (path.toLowerCase().startsWith('http')) {
      _showMessage(context.t.strings.legacy.msg_use_relative_path);
      return;
    }

    Map<String, Object?>? query;
    final queryRaw = _apiQueryController.text.trim();
    if (queryRaw.isNotEmpty) {
      query = _parseQuery(queryRaw);
      if (query == null) {
        _showMessage(context.t.strings.legacy.msg_failed_parse_query);
        return;
      }
    }

    Object? body;
    final bodyRaw = _apiBodyController.text.trim();
    if (bodyRaw.isNotEmpty) {
      try {
        body = jsonDecode(bodyRaw);
      } catch (_) {
        _showMessage(context.t.strings.legacy.msg_body_must_json);
        return;
      }
    }

    final token = _activeToken?.trim();
    final dio = Dio(
      BaseOptions(
        baseUrl: dioBaseUrlString(baseUrl),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      ),
    );

    final started = DateTime.now();
    setState(() => _apiBusy = true);
    try {
      final response = await dio.request(
        path,
        data: method == 'GET' ? null : body,
        queryParameters: query,
        options: Options(method: method),
      );
      final durationMs = DateTime.now().difference(started).inMilliseconds;
      final responseBody = _stringifyBody(response.data);
      setState(() {
        _lastApiResult = _DebugApiResult(
          method: method,
          path: path,
          status: response.statusCode,
          durationMs: durationMs,
          responseBody: responseBody,
          error: null,
        );
        _apiBusy = false;
      });
      await _logApi(
        label: '$method $path',
        method: method,
        url: response.requestOptions.uri.toString(),
        status: response.statusCode,
        durationMs: durationMs,
        requestHeaders: jsonEncode(response.requestOptions.headers),
        requestBody: body == null ? null : jsonEncode(body),
        responseHeaders: jsonEncode(_flattenHeaders(response.headers)),
        responseBody: responseBody,
      );
    } on DioException catch (e) {
      final durationMs = DateTime.now().difference(started).inMilliseconds;
      final responseBody = _stringifyBody(e.response?.data);
      setState(() {
        _lastApiResult = _DebugApiResult(
          method: method,
          path: path,
          status: e.response?.statusCode,
          durationMs: durationMs,
          responseBody: responseBody,
          error: e.message,
        );
        _apiBusy = false;
      });
      await _logApi(
        label: '$method $path',
        method: method,
        url: e.requestOptions.uri.toString(),
        status: e.response?.statusCode,
        durationMs: durationMs,
        requestHeaders: jsonEncode(e.requestOptions.headers),
        requestBody: body == null ? null : jsonEncode(body),
        responseHeaders: e.response == null
            ? null
            : jsonEncode(_flattenHeaders(e.response!.headers)),
        responseBody: responseBody,
        error: e.message,
      );
    } catch (e) {
      setState(() {
        _lastApiResult = _DebugApiResult(
          method: method,
          path: path,
          status: null,
          durationMs: DateTime.now().difference(started).inMilliseconds,
          responseBody: '',
          error: e.toString(),
        );
        _apiBusy = false;
      });
    }
  }

  Map<String, Object?>? _parseQuery(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {}
      return null;
    }
    final normalized = trimmed.replaceAll('\n', '&');
    try {
      final parsed = Uri.splitQueryString(normalized);
      return parsed.map((key, value) => MapEntry(key, value));
    } catch (_) {
      return null;
    }
  }

  String _stringifyBody(Object? data) {
    if (data == null) return '';
    if (data is String) return data;
    if (data is List<int>) return '<bytes:${data.length}>';
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  Map<String, dynamic> _expectJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    throw const FormatException('Expected JSON object');
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPreferencesProvider);
    final session = ref.watch(appSessionProvider).valueOrNull;
    final account = session?.currentAccount;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    final baseUrl = account?.baseUrl.toString() ?? '';
    final accountUser = account?.user;
    final userLabel = accountUser == null
        ? context.t.strings.legacy.msg_not_signed
        : (accountUser.displayName.isNotEmpty
              ? accountUser.displayName
              : accountUser.username);
    final apiVersionResolution = account == null
        ? null
        : MemosServerApiProfiles.resolve(
            manualVersionOverride: account.serverVersionOverride,
            detectedVersion: account.instanceProfile.version,
          );
    final apiRouteVersion = _apiRouteVersionLabel(apiVersionResolution);
    final token = _activeToken;
    final tokenLabel = token == null || token.isEmpty
        ? context.t.strings.legacy.msg_none
        : _tokenPreview(token);
    final tokenSource = _activeTokenSource.isEmpty ? '-' : _activeTokenSource;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.t.strings.legacy.msg_back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.t.strings.legacy.msg_debug_tools),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          if (isDark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0xFF0B0B0B), bg, bg],
                  ),
                ),
              ),
            ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _SectionTitle(
                text: context.t.strings.legacy.msg_status,
                color: textMuted,
              ),
              const SizedBox(height: 10),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _InfoRow(
                    label: context.t.strings.legacy.msg_user,
                    value: userLabel,
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                  _InfoRow(
                    label: context.t.strings.legacy.msg_server,
                    value: baseUrl.isEmpty ? '-' : baseUrl,
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                  _InfoRow(
                    label: context.t.strings.legacy.msg_token_source,
                    value: tokenSource,
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                  _InfoRow(
                    label: context.t.strings.legacy.msg_token,
                    value: tokenLabel,
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                  _InfoRow(
                    label: context.t.strings.legacy.msg_legacy_mode,
                    value: prefs.useLegacyApi ? 'ON' : 'OFF',
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                  if (kDebugMode)
                    _InfoRow(
                      label: 'API Route',
                      value: apiRouteVersion,
                      textMain: textMain,
                      textMuted: textMuted,
                    ),
                  FutureBuilder<PackageInfo>(
                    future: _packageInfoFuture,
                    builder: (context, snapshot) {
                      final version = snapshot.data?.version.trim() ?? '';
                      final build = snapshot.data?.buildNumber.trim() ?? '';
                      final label = version.isEmpty
                          ? '-'
                          : (build.isEmpty ? version : 'v$version ($build)');
                      return _InfoRow(
                        label: context.t.strings.legacy.msg_version,
                        value: label,
                        textMain: textMain,
                        textMuted: textMuted,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionTitle(
                text: context.t.strings.legacy.msg_local,
                color: textMuted,
              ),
              const SizedBox(height: 10),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _ActionRow(
                    icon: Icons.language_outlined,
                    label:
                        context.t.strings.legacy.msg_open_language_onboarding,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      _logAction('Open language onboarding');
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LanguageSelectionScreen(),
                        ),
                      );
                    },
                  ),
                  _ActionRow(
                    icon: Icons.restart_alt,
                    label:
                        context.t.strings.legacy.msg_reset_language_selection,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      ref
                          .read(appPreferencesProvider.notifier)
                          .setHasSelectedLanguage(false);
                      _logAction('Reset language selection');
                      _showMessage(context.t.strings.legacy.msg_reset_complete);
                    },
                  ),
                  _ActionRow(
                    icon: Icons.login_outlined,
                    label: context.t.strings.legacy.msg_open_login_screen,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      _logAction('Open login screen');
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionTitle(
                text: context.t.strings.legacy.msg_server_login,
                color: textMuted,
              ),
              const SizedBox(height: 10),
              _Card(
                card: card,
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Field(
                      label: context.t.strings.legacy.msg_username_2,
                      controller: _usernameController,
                      hintText: 'user',
                      obscureText: false,
                      textMain: textMain,
                      textMuted: textMuted,
                      enabled: !_loginBusy,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      label: context.t.strings.legacy.msg_password,
                      controller: _passwordController,
                      hintText: context.t.strings.legacy.msg_enter_password_2,
                      obscureText: _obscurePassword,
                      textMain: textMain,
                      textMuted: textMuted,
                      enabled: !_loginBusy,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18,
                          color: textMuted,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _loginBusy ? null : _signIn,
                        icon: _loginBusy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.key),
                        label: Text(
                          _loginBusy
                              ? context.t.strings.legacy.msg_signing
                              : context.t.strings.legacy.msg_sign_3,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MemoFlowPalette.primary,
                          foregroundColor: Colors.white,
                          elevation: isDark ? 0 : 6,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if ((_lastLoginUser ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        context.t.strings.legacy.msg_signed_2(
                          lastLoginUser: _lastLoginUser ?? '-',
                        ),
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionTitle(
                text: context.t.strings.legacy.msg_manual_token,
                color: textMuted,
              ),
              const SizedBox(height: 10),
              _Card(
                card: card,
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Field(
                      label: 'Token',
                      controller: _tokenController,
                      hintText: 'memos_pat_...',
                      obscureText: _obscureToken,
                      textMain: textMain,
                      textMuted: textMuted,
                      enabled: true,
                      suffix: IconButton(
                        icon: Icon(
                          _obscureToken
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18,
                          color: textMuted,
                        ),
                        onPressed: () =>
                            setState(() => _obscureToken = !_obscureToken),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: OutlinedButton(
                              onPressed: _setManualToken,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: MemoFlowPalette.primary,
                                side: BorderSide(
                                  color: MemoFlowPalette.primary.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: Text(
                                context.t.strings.legacy.msg_apply_token,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 42,
                          child: TextButton(
                            onPressed: _clearToken,
                            child: Text(
                              context.t.strings.legacy.msg_clear_2,
                              style: TextStyle(color: textMuted),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 42,
                          child: TextButton(
                            onPressed: token == null || token.isEmpty
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final message = context
                                        .t
                                        .strings
                                        .legacy
                                        .msg_token_copied;
                                    await Clipboard.setData(
                                      ClipboardData(text: token),
                                    );
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(message)),
                                    );
                                  },
                            child: Text(
                              context.t.strings.legacy.msg_copy,
                              style: TextStyle(color: textMuted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionTitle(
                text: context.t.strings.legacy.msg_api_call,
                color: textMuted,
              ),
              const SizedBox(height: 10),
              _Card(
                card: card,
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Field(
                      label: context.t.strings.legacy.msg_path,
                      controller: _apiPathController,
                      hintText: '/api/v1/memos',
                      obscureText: false,
                      textMain: textMain,
                      textMuted: textMuted,
                      enabled: !_apiBusy,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      label: context.t.strings.legacy.msg_query,
                      controller: _apiQueryController,
                      hintText: 'pageSize=20&filter=',
                      obscureText: false,
                      textMain: textMain,
                      textMuted: textMuted,
                      enabled: !_apiBusy,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      label: context.t.strings.legacy.msg_body_json,
                      controller: _apiBodyController,
                      hintText: '{"content":"hello"}',
                      obscureText: false,
                      textMain: textMain,
                      textMuted: textMuted,
                      enabled: !_apiBusy,
                      minLines: 3,
                      maxLines: 6,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _apiBusy
                                  ? null
                                  : () => _sendApiRequest(method: 'GET'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MemoFlowPalette.primary,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: _apiBusy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('GET'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _apiBusy
                                  ? null
                                  : () => _sendApiRequest(method: 'POST'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MemoFlowPalette.primary,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('POST'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_lastApiResult != null) ...[
                      const SizedBox(height: 14),
                      _ApiResultCard(
                        result: _lastApiResult!,
                        textMain: textMain,
                        textMuted: textMuted,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionTitle(
                text: context.t.strings.legacy.msg_logs,
                color: textMuted,
              ),
              const SizedBox(height: 10),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _ActionRow(
                    icon: Icons.list_alt_outlined,
                    label: context.t.strings.legacy.msg_view_debug_logs,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DebugLogsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
