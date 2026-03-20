import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../core/url.dart';
import '../../core/version_probe_gate.dart';
import '../../i18n/strings.g.dart';
import '../../state/system/login_draft_provider.dart';
import '../../state/system/home_loading_overlay_provider.dart';
import '../../state/memos/login_provider.dart';
import '../../state/settings/preferences_provider.dart';
import '../../state/system/session_provider.dart';

enum _LoginMode { token, password }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialError});

  final String? initialError;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const List<String> _serverVersionOptions = <String>[
    '0.26.0',
    '0.25.0',
    '0.24.0',
    '0.23.0',
    '0.22.0',
    '0.21.0',
  ];

  final _formKey = GlobalKey<FormState>();
  final _baseUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  var _loginMode = _LoginMode.password;
  var _useHttps = true;
  var _selectedServerVersion = '0.26.0';
  var _probing = false;
  var _versionMenuExpanded = false;
  var _shownInitialError = false;
  var _shownHttpsHandshakeHelp = false;
  var _activeLoginOpId = 0;

  @override
  void initState() {
    super.initState();
    _restoreBaseUrlDraft(ref.read(loginBaseUrlDraftProvider));
    _selectedServerVersion = _resolveInitialServerVersion();
  }

  @override
  void dispose() {
    _activeLoginOpId++;
    _baseUrlController.dispose();
    _tokenController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  int _beginLoginOp() => ++_activeLoginOpId;

  bool _isLoginOpActive(int opId) => mounted && opId == _activeLoginOpId;

  void _setStateIfActive(int opId, VoidCallback callback) {
    if (_isLoginOpActive(opId)) {
      setState(callback);
    }
  }

  void _showSnackIfActive(int opId, String message) {
    if (!_isLoginOpActive(opId)) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<T?> _showDialogIfActive<T>(
    int opId, {
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    if (!_isLoginOpActive(opId)) {
      return Future<T?>.value(null);
    }
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  String _normalizeTokenInput(String raw) {
    var token = raw.trim();
    if (token.isEmpty) return token;
    final match = RegExp(
      r'^(?:authorization:\s*)?bearer\s+',
      caseSensitive: false,
    ).firstMatch(token);
    if (match != null) {
      token = token.substring(match.end).trim();
    }
    if (token.contains(RegExp(r'\s'))) {
      token = token.replaceAll(RegExp(r'\s+'), '');
    }
    return token;
  }

  String _extractServerMessage(Object? data) {
    if (data is Map) {
      final message = data['message'] ?? data['error'] ?? data['detail'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return '';
  }

  String _formatLoginError(Object error, {required String token}) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) {
        if (token.startsWith('memos_pat_')) {
          return context.t.strings.login.errors.authFailedToken;
        }
        return context.t.strings.login.errors.authFailedPat;
      }
      final serverMessage = _extractServerMessage(error.response?.data);
      if (serverMessage.isNotEmpty) {
        return context.t.strings.login.errors.connectionFailedWithMessage(
          message: serverMessage,
        );
      }
    } else if (error is FormatException) {
      final message = error.message.trim();
      if (message.isNotEmpty) {
        return context.t.strings.login.errors.connectionFailedWithMessage(
          message: message,
        );
      }
    }
    return context.t.strings.login.errors.connectionFailed(
      error: error.toString(),
    );
  }

  String _formatPasswordLoginError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        return context.t.strings.login.errors.signInFailed;
      }
      final serverMessage = _extractServerMessage(error.response?.data);
      if (serverMessage.isNotEmpty) {
        return context.t.strings.login.errors.signInFailedWithMessage(
          message: serverMessage,
        );
      }
    } else if (error is FormatException) {
      final message = error.message.trim();
      if (message.isNotEmpty) {
        return context.t.strings.login.errors.signInFailedWithMessage(
          message: message,
        );
      }
    }
    return context.t.strings.login.errors.signInFailedWithMessage(
      message: error.toString(),
    );
  }

  bool _isLikelyHttpsHandshakeFailure(Object error) {
    if (error is! DioException) return false;

    if (error.type == DioExceptionType.badCertificate) {
      return true;
    }

    if (error.type != DioExceptionType.connectionError &&
        error.type != DioExceptionType.unknown) {
      return false;
    }

    final combined = <String>[
      error.message ?? '',
      error.error?.toString() ?? '',
      _extractServerMessage(error.response?.data),
    ].join(' | ').toLowerCase();

    if (combined.trim().isEmpty) return false;

    return combined.contains('handshake') ||
        combined.contains('tls') ||
        combined.contains('ssl') ||
        combined.contains('certificate') ||
        combined.contains('wrong version number') ||
        combined.contains('record overflow') ||
        combined.contains('protocol version') ||
        combined.contains('secure connection');
  }

  Future<bool> _maybeHandleHttpsHandshakeFailure(int opId, Object error) async {
    if (!_isLoginOpActive(opId) || !_useHttps || _shownHttpsHandshakeHelp) {
      return false;
    }
    if (!_isLikelyHttpsHandshakeFailure(error)) return false;

    _shownHttpsHandshakeHelp = true;
    final switchToHttp =
        await _showDialogIfActive<bool>(
          opId,
          builder: (context) => AlertDialog(
            title: Text(
              context.t.strings.login.dialogs.httpsHandshakeFailedTitle,
            ),
            content: Text(
              context.t.strings.login.dialogs.httpsHandshakeFailedMessage,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.t.strings.common.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.t.strings.login.dialogs.switchToHttp),
              ),
            ],
          ),
        ) ??
        false;
    if (!_isLoginOpActive(opId)) return true;

    if (switchToHttp) {
      setState(() => _useHttps = false);
      _syncBaseUrlDraft();
      await _connect();
    }
    return true;
  }

  void _restoreBaseUrlDraft(String draft) {
    final trimmed = draft.trim();
    if (trimmed.isEmpty) {
      _useHttps = true;
      _baseUrlController.text = '';
      return;
    }

    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme && parsed.hasAuthority) {
      _useHttps = parsed.scheme.toLowerCase() != 'http';
      _baseUrlController.text = _baseUrlSuffixFromUri(parsed);
      return;
    }

    _useHttps = true;
    _baseUrlController.text = _normalizeBaseUrlSuffix(trimmed);
  }

  String _normalizeBaseUrlSuffix(String raw) {
    return raw.trim().replaceFirst(
      RegExp(r'^(?:https?:)?//', caseSensitive: false),
      '',
    );
  }

  String _baseUrlSuffixFromUri(Uri uri) {
    final buffer = StringBuffer();
    if (uri.authority.isNotEmpty) {
      buffer.write(uri.authority);
    }
    if (uri.path.isNotEmpty && uri.path != '/') {
      buffer.write(uri.path);
    }
    return buffer.toString();
  }

  String _composeBaseUrlString([String? rawSuffix]) {
    final suffix = _normalizeBaseUrlSuffix(
      rawSuffix ?? _baseUrlController.text,
    );
    if (suffix.isEmpty) return '';
    final scheme = _useHttps ? 'https' : 'http';
    return '$scheme://$suffix';
  }

  void _syncBaseUrlDraft([String? rawSuffix]) {
    ref.read(loginBaseUrlDraftProvider.notifier).state = _composeBaseUrlString(
      rawSuffix,
    );
  }

  Future<void> _handleProtocolChanged(bool nextUseHttps) async {
    if (_useHttps == nextUseHttps) return;
    if (nextUseHttps) {
      setState(() => _useHttps = true);
      _syncBaseUrlDraft();
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t.strings.login.dialogs.insecureHttpTitle),
            content: Text(context.t.strings.login.dialogs.insecureHttpMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.t.strings.common.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.t.strings.common.confirm),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !confirmed) return;

    setState(() => _useHttps = false);
    _syncBaseUrlDraft();
  }

  Uri? _resolveBaseUrl() {
    final baseUrlRaw = _composeBaseUrlString();
    final baseUrl = Uri.tryParse(baseUrlRaw);
    if (baseUrl == null || !(baseUrl.hasScheme && baseUrl.hasAuthority)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.login.errors.invalidServerUrl),
        ),
      );
      return null;
    }

    final sanitizedBaseUrl = sanitizeUserBaseUrl(baseUrl);
    if (sanitizedBaseUrl.toString() != baseUrl.toString()) {
      final sanitizedScheme = sanitizedBaseUrl.scheme.toLowerCase();
      final sanitizedSuffix = _baseUrlSuffixFromUri(sanitizedBaseUrl);
      _baseUrlController.text = sanitizedSuffix;
      _baseUrlController.selection = TextSelection.collapsed(
        offset: _baseUrlController.text.length,
      );
      _useHttps = sanitizedScheme != 'http';
      ref.read(loginBaseUrlDraftProvider.notifier).state = sanitizedBaseUrl
          .toString();
      showTopToast(context, context.t.strings.login.errors.serverUrlNormalized);
    }
    return sanitizedBaseUrl;
  }

  Future<void> _connect() async {
    final opId = _beginLoginOp();
    if (_loginMode == _LoginMode.password) {
      return _connectWithPassword(opId);
    }
    return _connectWithToken(opId);
  }

  Future<bool> _addAccountWithPatSafe({
    required int opId,
    required AppSessionController sessionController,
    required Uri baseUrl,
    required String token,
    required String serverVersionOverride,
  }) async {
    try {
      await sessionController.addAccountWithPat(
        baseUrl: baseUrl,
        personalAccessToken: token,
        serverVersionOverride: serverVersionOverride,
      );
      return true;
    } catch (error) {
      if (!_isLoginOpActive(opId)) return false;
      final handled = await _maybeHandleHttpsHandshakeFailure(opId, error);
      if (!_isLoginOpActive(opId)) return false;
      if (handled) return false;
      _showSnackIfActive(opId, _formatLoginError(error, token: token));
      return false;
    }
  }

  Future<bool> _addAccountWithPasswordSafe({
    required int opId,
    required AppSessionController sessionController,
    required Uri baseUrl,
    required String username,
    required String password,
    required String serverVersionOverride,
  }) async {
    try {
      await sessionController.addAccountWithPassword(
        baseUrl: baseUrl,
        username: username,
        password: password,
        useLegacyApi: false,
        serverVersionOverride: serverVersionOverride,
      );
      return true;
    } catch (error) {
      if (!_isLoginOpActive(opId)) return false;
      final handled = await _maybeHandleHttpsHandshakeFailure(opId, error);
      if (!_isLoginOpActive(opId)) return false;
      if (handled) return false;
      _passwordController.clear();
      _showSnackIfActive(opId, _formatPasswordLoginError(error));
      return false;
    }
  }

  String _resolveInitialServerVersion() {
    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    final normalized = _normalizeServerVersion(
      account?.serverVersionOverride ?? account?.instanceProfile.version ?? '',
    );
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return _serverVersionOptions.first;
  }

  String _normalizeServerVersion(String raw) {
    return ref.read(loginControllerProvider).normalizeServerVersion(raw);
  }

  LoginApiVersion? _selectedProbeVersion() {
    final controller = ref.read(loginControllerProvider);
    return controller.parseVersion(
      _normalizeServerVersion(_selectedServerVersion),
    );
  }

  Future<void> _showProbeSuccessDialog(
    int opId,
    LoginApiVersion version,
  ) async {
    await _showDialogIfActive<void>(
      opId,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(context.t.strings.legacy.msg_version_probe_complete),
          content: Text(
            context.t.strings.legacy.msg_currently_using_api(
              version: version.versionString,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t.strings.common.confirm),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showProbeFailureDialog(int opId, String diagnostics) async {
    await _showDialogIfActive<void>(
      opId,
      builder: (context) {
        return AlertDialog(
          title: Text(context.t.strings.legacy.msg_version_probe_failed),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(child: SelectableText(diagnostics)),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final copiedMessage =
                    context.t.strings.legacy.msg_diagnostics_copied;
                await Clipboard.setData(ClipboardData(text: diagnostics));
                if (!context.mounted) return;
                showTopToast(context, copiedMessage);
              },
              child: Text(context.t.strings.legacy.msg_copy_diagnostics),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t.strings.legacy.msg_close),
            ),
          ],
        );
      },
    );
  }

  Future<void> _rollbackProbeFailure({
    required AppSessionController sessionController,
    required String failedAccountKey,
    required String? previousCurrentKey,
    required bool accountExistedBefore,
  }) async {
    if (!accountExistedBefore) {
      await sessionController.removeAccount(failedAccountKey);
    }
    final restoredKey = (previousCurrentKey ?? '').trim();
    if (restoredKey.isNotEmpty) {
      await sessionController.setCurrentKey(restoredKey);
    }
  }

  Future<LoginProbeReport?> _probeSingleVersion({
    required int opId,
    required Uri baseUrl,
    required String personalAccessToken,
    required LoginApiVersion version,
    required LoginController loginController,
  }) async {
    _setStateIfActive(opId, () => _probing = true);
    final legacyStrings = context.t.strings.legacy;
    try {
      final report = await loginController.probeSingleVersion(
        baseUrl: baseUrl,
        personalAccessToken: personalAccessToken,
        version: version,
        probeMemoNotice: legacyStrings.msg_probe_memo_can_delete,
      );
      if (!_isLoginOpActive(opId)) return null;
      return report;
    } catch (error) {
      _showSnackIfActive(opId, legacyStrings.msg_probe_failed(error: error));
      return null;
    } finally {
      _setStateIfActive(opId, () => _probing = false);
    }
  }

  Future<void> _cleanupProbeArtifactsAfterSync({
    required int opId,
    required LoginApiVersion version,
    required LoginProbeCleanup cleanup,
    required Uri baseUrl,
    required String personalAccessToken,
    required LoginController loginController,
  }) async {
    if (!_isLoginOpActive(opId)) return;
    await loginController.cleanupProbeArtifactsAfterSync(
      version: version,
      cleanup: cleanup,
      baseUrl: baseUrl,
      personalAccessToken: personalAccessToken,
    );
  }

  Future<bool> _runSelectedVersionProbeGate({
    required int opId,
    required AppSessionController sessionController,
    required LoginApiVersion version,
    required String? previousCurrentKey,
    required Set<String> previousAccountKeys,
    required LoginController loginController,
  }) async {
    if (!_isLoginOpActive(opId)) return false;
    final currentAccount = ref
        .read(appSessionProvider)
        .valueOrNull
        ?.currentAccount;
    if (currentAccount == null) {
      _showSnackIfActive(
        opId,
        context.t.strings.login.errors.connectionFailedWithMessage(
          message: context.t.strings.legacy.msg_no_active_session_after_sign_in,
        ),
      );
      return false;
    }

    final accountExistedBefore = previousAccountKeys.contains(
      currentAccount.key,
    );
    final report = await _probeSingleVersion(
      opId: opId,
      baseUrl: currentAccount.baseUrl,
      personalAccessToken: currentAccount.personalAccessToken,
      version: version,
      loginController: loginController,
    );
    if (!_isLoginOpActive(opId)) return false;
    if (report == null) {
      await _rollbackProbeFailure(
        sessionController: sessionController,
        failedAccountKey: currentAccount.key,
        previousCurrentKey: previousCurrentKey,
        accountExistedBefore: accountExistedBefore,
      );
      return false;
    }
    if (!report.passed) {
      await _showProbeFailureDialog(opId, report.diagnostics);
      if (!_isLoginOpActive(opId)) return false;
      await _rollbackProbeFailure(
        sessionController: sessionController,
        failedAccountKey: currentAccount.key,
        previousCurrentKey: previousCurrentKey,
        accountExistedBefore: accountExistedBefore,
      );
      return false;
    }

    await sessionController.setCurrentAccountServerVersionOverride(
      version.versionString,
    );
    if (!_isLoginOpActive(opId)) return false;
    await _cleanupProbeArtifactsAfterSync(
      opId: opId,
      version: version,
      cleanup: report.cleanup,
      baseUrl: currentAccount.baseUrl,
      personalAccessToken: currentAccount.personalAccessToken,
      loginController: loginController,
    );
    if (!_isLoginOpActive(opId)) return false;
    await _showProbeSuccessDialog(opId, version);
    if (!_isLoginOpActive(opId)) return false;
    return true;
  }

  void _navigateAfterLogin() {
    if (Navigator.of(context).canPop()) {
      context.safePop();
    } else {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  void _requestHomeLoadingOverlayForNextEntry() {
    ref.read(homeLoadingOverlayForceProvider.notifier).state = true;
  }

  Future<void> _handleBackPressed() async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    ref.read(appPreferencesProvider.notifier).setHasSelectedLanguage(false);
  }

  Future<void> _connectWithToken(int opId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final loginController = ref.read(loginControllerProvider);
    final sessionController = ref.read(appSessionProvider.notifier);
    final tokenRaw = _tokenController.text.trim();
    final token = _normalizeTokenInput(tokenRaw);
    if (token != tokenRaw) {
      _tokenController.text = token;
    }
    final baseUrl = _resolveBaseUrl();
    if (baseUrl == null) {
      return;
    }
    final selectedVersion = _selectedProbeVersion();
    if (selectedVersion == null) {
      _showSnackIfActive(
        opId,
        context.t.strings.common.selectValidServerVersion,
      );
      return;
    }

    if (!isVersionProbeEnabled) {
      final added = await _addAccountWithPatSafe(
        opId: opId,
        sessionController: sessionController,
        baseUrl: baseUrl,
        token: token,
        serverVersionOverride: selectedVersion.versionString,
      );
      if (!added) return;
      if (!_isLoginOpActive(opId)) return;

      final sessionAsync = ref.read(appSessionProvider);
      if (sessionAsync.hasError) {
        final handled = await _maybeHandleHttpsHandshakeFailure(
          opId,
          sessionAsync.error!,
        );
        if (!_isLoginOpActive(opId)) return;
        if (handled) return;
        _showSnackIfActive(
          opId,
          _formatLoginError(sessionAsync.error!, token: token),
        );
        return;
      }

      if (selectedVersion.isV025) {
        _requestHomeLoadingOverlayForNextEntry();
      }
      _navigateAfterLogin();
      return;
    }

    final probeReport = await _probeSingleVersion(
      opId: opId,
      baseUrl: baseUrl,
      personalAccessToken: token,
      version: selectedVersion,
      loginController: loginController,
    );
    if (probeReport == null) return;
    if (!_isLoginOpActive(opId)) return;
    if (!probeReport.passed) {
      await _showProbeFailureDialog(opId, probeReport.diagnostics);
      if (!_isLoginOpActive(opId)) return;
      return;
    }

    final added = await _addAccountWithPatSafe(
      opId: opId,
      sessionController: sessionController,
      baseUrl: baseUrl,
      token: token,
      serverVersionOverride: selectedVersion.versionString,
    );
    if (!added) return;
    if (!_isLoginOpActive(opId)) return;

    final sessionAsync = ref.read(appSessionProvider);
    if (sessionAsync.hasError) {
      final handled = await _maybeHandleHttpsHandshakeFailure(
        opId,
        sessionAsync.error!,
      );
      if (!_isLoginOpActive(opId)) return;
      if (handled) return;
      _showSnackIfActive(
        opId,
        _formatLoginError(sessionAsync.error!, token: token),
      );
      return;
    }

    final currentAccount = ref
        .read(appSessionProvider)
        .valueOrNull
        ?.currentAccount;
    if (currentAccount != null) {
      await _cleanupProbeArtifactsAfterSync(
        opId: opId,
        version: selectedVersion,
        cleanup: probeReport.cleanup,
        baseUrl: currentAccount.baseUrl,
        personalAccessToken: currentAccount.personalAccessToken,
        loginController: loginController,
      );
    }

    if (!_isLoginOpActive(opId)) return;
    await _showProbeSuccessDialog(opId, selectedVersion);
    if (!_isLoginOpActive(opId)) return;
    if (selectedVersion.isV025) {
      _requestHomeLoadingOverlayForNextEntry();
    }
    _navigateAfterLogin();
    return;
  }

  Future<void> _connectWithPassword(int opId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final loginController = ref.read(loginControllerProvider);
    final sessionController = ref.read(appSessionProvider.notifier);
    final baseUrl = _resolveBaseUrl();
    if (baseUrl == null) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final previousSession = ref.read(appSessionProvider).valueOrNull;
    final previousCurrentKey = previousSession?.currentKey;
    final previousAccountKeys =
        previousSession?.accounts.map((account) => account.key).toSet() ??
        <String>{};
    final selectedVersion = _selectedProbeVersion();
    if (selectedVersion == null) {
      _showSnackIfActive(
        opId,
        context.t.strings.common.selectValidServerVersion,
      );
      return;
    }

    final added = await _addAccountWithPasswordSafe(
      opId: opId,
      sessionController: sessionController,
      baseUrl: baseUrl,
      username: username,
      password: password,
      serverVersionOverride: selectedVersion.versionString,
    );
    if (!added) return;
    if (!_isLoginOpActive(opId)) return;

    final sessionAsync = ref.read(appSessionProvider);
    if (sessionAsync.hasError) {
      final handled = await _maybeHandleHttpsHandshakeFailure(
        opId,
        sessionAsync.error!,
      );
      if (!_isLoginOpActive(opId)) return;
      if (handled) return;
      _passwordController.clear();
      _showSnackIfActive(opId, _formatPasswordLoginError(sessionAsync.error!));
      return;
    }

    if (!isVersionProbeEnabled) {
      if (selectedVersion.isV025) {
        _requestHomeLoadingOverlayForNextEntry();
      }
      _navigateAfterLogin();
      return;
    }

    // The full probe suite is expensive on 0.23 and significantly delays login.
    // For an explicitly selected 0.23 target, proceed after successful sign-in.
    if (selectedVersion.isV023) {
      _navigateAfterLogin();
      return;
    }

    final ready = await _runSelectedVersionProbeGate(
      opId: opId,
      sessionController: sessionController,
      version: selectedVersion,
      previousCurrentKey: previousCurrentKey,
      previousAccountKeys: previousAccountKeys,
      loginController: loginController,
    );
    if (!ready) return;
    if (!_isLoginOpActive(opId)) return;
    if (selectedVersion.isV025) {
      _requestHomeLoadingOverlayForNextEntry();
    }
    _navigateAfterLogin();
    return;
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool enabled,
    required bool obscureText,
    required String? Function(String?) validator,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    required bool isDark,
    required Color card,
    required Color textMain,
    required Color textMuted,
    String? prefixText,
    Widget? labelTrailing,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
            ),
            if (labelTrailing != null) ...[
              const SizedBox(width: 12),
              labelTrailing,
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ],
          ),
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: TextStyle(color: textMain, fontWeight: FontWeight.w500),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: prefixText == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: 16, right: 4),
                      child: Text(
                        prefixText,
                        style: TextStyle(
                          color: textMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
              prefixIconConstraints: prefixText == null
                  ? null
                  : const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: suffixIcon,
              suffixIconConstraints: suffixIcon == null
                  ? null
                  : const BoxConstraints(minWidth: 52, minHeight: 44),
              hintStyle: TextStyle(
                color: textMuted.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(
                left: prefixText == null ? 16 : 0,
                right: 16,
                top: 14,
                bottom: 14,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildProtocolShieldButton({
    required bool enabled,
    required Color textMuted,
  }) {
    final iconColor = _useHttps
        ? Colors.green.shade600
        : textMuted.withValues(alpha: 0.75);
    final backgroundColor = _useHttps
        ? Colors.green.withValues(alpha: 0.10)
        : textMuted.withValues(alpha: 0.10);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: _useHttps ? 'HTTPS' : 'HTTP',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? () => _handleProtocolChanged(!_useHttps) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.shield_outlined, size: 20, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHttpSwitchHint({required Color textMuted}) {
    final message = context.tr(
      zh: '\u53f3\u4fa7\u76fe\u724c\u56fe\u6807\u53ef\u7528\u4e8e\u5207\u6362\u8fde\u63a5\u534f\u8bae\u3002',
      en: 'Use the shield icon on the right to switch connection protocols.',
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: textMuted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: textMuted.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginModeToggle({
    required bool enabled,
    required bool isDark,
    required Color card,
    required Color textMain,
  }) {
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;

    Widget buildButton({required _LoginMode mode, required String label}) {
      final active = _loginMode == mode;
      return Expanded(
        child: InkWell(
          onTap: enabled ? () => setState(() => _loginMode = mode) : null,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? MemoFlowPalette.primary : card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? MemoFlowPalette.primary : border,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : textMain,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildButton(
          mode: _LoginMode.password,
          label: context.t.strings.login.mode.password,
        ),
        const SizedBox(width: 10),
        buildButton(
          mode: _LoginMode.token,
          label: context.t.strings.login.mode.token,
        ),
      ],
    );
  }

  Widget _buildServerVersionSelector({
    required bool enabled,
    required bool isDark,
    required Color card,
    required Color textMain,
    required Color textMuted,
  }) {
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final displayColor = enabled ? textMain : textMuted;

    return LayoutBuilder(
      builder: (context, constraints) {
        return PopupMenuButton<String>(
          enabled: enabled,
          tooltip: '',
          padding: EdgeInsets.zero,
          initialValue: _selectedServerVersion,
          position: PopupMenuPosition.under,
          offset: const Offset(0, 2),
          menuPadding: EdgeInsets.zero,
          elevation: isDark ? 10 : 14,
          color: card,
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
            maxWidth: constraints.maxWidth,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          popUpAnimationStyle: const AnimationStyle(
            duration: Duration(milliseconds: 200),
            reverseDuration: Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
          onOpened: () {
            if (!mounted) return;
            setState(() => _versionMenuExpanded = true);
          },
          onCanceled: () {
            if (!mounted) return;
            setState(() => _versionMenuExpanded = false);
          },
          onSelected: (value) {
            final normalized = value.trim();
            if (normalized.isEmpty) return;
            setState(() {
              _versionMenuExpanded = false;
              _selectedServerVersion = normalized;
            });
          },
          itemBuilder: (context) {
            return _serverVersionOptions
                .map(
                  (version) => PopupMenuItem<String>(
                    value: version,
                    child: Text('v$version'),
                  ),
                )
                .toList(growable: false);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'v$_selectedServerVersion',
                    style: TextStyle(
                      color: displayColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _versionMenuExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(appSessionProvider);
    final isBusy = sessionAsync.isLoading || _probing;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.7);
    final modeDescription = _loginMode == _LoginMode.password
        ? context.t.strings.login.mode.descPassword
        : context.t.strings.login.mode.descToken;

    if (!_shownInitialError) {
      _shownInitialError = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final error = widget.initialError;
        if (error != null && error.isNotEmpty && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      });
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.t.strings.common.back,
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () async {
            await _handleBackPressed();
          },
        ),
        title: Text(context.t.strings.login.title),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              children: [
                const SizedBox(height: 6),
                Text(
                  modeDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.t.strings.login.mode.signInMethod,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildLoginModeToggle(
                        enabled: !isBusy,
                        isDark: isDark,
                        card: card,
                        textMain: textMain,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _baseUrlController,
                        label: context.t.strings.login.field.serverUrlLabel,
                        hint: context.t.strings.login.field.serverUrlHint,
                        enabled: !isBusy,
                        obscureText: false,
                        keyboardType: TextInputType.url,
                        isDark: isDark,
                        card: card,
                        textMain: textMain,
                        textMuted: textMuted,
                        prefixText: _useHttps ? 'https://' : 'http://',
                        suffixIcon: _buildProtocolShieldButton(
                          enabled: !isBusy,
                          textMuted: textMuted,
                        ),
                        onChanged: _syncBaseUrlDraft,
                        validator: (v) {
                          final raw = _normalizeBaseUrlSuffix(v ?? '');
                          if (raw.isEmpty) {
                            return context
                                .t
                                .strings
                                .login
                                .validation
                                .serverUrlRequired;
                          }
                          final uri = Uri.tryParse(_composeBaseUrlString(raw));
                          if (uri == null ||
                              !(uri.hasScheme && uri.hasAuthority)) {
                            return context
                                .t
                                .strings
                                .login
                                .validation
                                .serverUrlInvalid;
                          }
                          return null;
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _buildHttpSwitchHint(textMuted: textMuted),
                      ),
                      const SizedBox(height: 14),
                      if (_loginMode == _LoginMode.password) ...[
                        _buildField(
                          controller: _usernameController,
                          label: context.t.strings.login.field.usernameLabel,
                          hint: context.t.strings.login.field.usernameHint,
                          enabled: !isBusy,
                          obscureText: false,
                          isDark: isDark,
                          card: card,
                          textMain: textMain,
                          textMuted: textMuted,
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) {
                              return context
                                  .t
                                  .strings
                                  .login
                                  .validation
                                  .usernameRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _passwordController,
                          label: context.t.strings.login.field.passwordLabel,
                          hint: context.t.strings.login.field.passwordHint,
                          enabled: !isBusy,
                          obscureText: true,
                          isDark: isDark,
                          card: card,
                          textMain: textMain,
                          textMuted: textMuted,
                          keyboardType: TextInputType.visiblePassword,
                          validator: (v) {
                            if ((v ?? '').isEmpty) {
                              return context
                                  .t
                                  .strings
                                  .login
                                  .validation
                                  .passwordRequired;
                            }
                            return null;
                          },
                        ),
                      ] else ...[
                        _buildField(
                          controller: _tokenController,
                          label: context.t.strings.login.field.tokenLabel,
                          hint: context.t.strings.login.field.tokenHint,
                          enabled: !isBusy,
                          obscureText: true,
                          isDark: isDark,
                          card: card,
                          textMain: textMain,
                          textMuted: textMuted,
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) {
                              return context
                                  .t
                                  .strings
                                  .login
                                  .validation
                                  .tokenRequired;
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                    color: Colors.black.withValues(alpha: 0.08),
                                  ),
                                ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t.strings.common.serverVersion,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: textMain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildServerVersionSelector(
                              enabled: !isBusy,
                              isDark: isDark,
                              card: card,
                              textMain: textMain,
                              textMuted: textMuted,
                            ),
                            if (isVersionProbeEnabled)
                              Text(
                                context.t.strings.common.serverVersionProbeHint,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: isBusy ? null : _connect,
                          icon: isBusy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.link),
                          label: Text(
                            isBusy
                                ? context.t.strings.login.connect.connecting
                                : context.t.strings.login.connect.action,
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
