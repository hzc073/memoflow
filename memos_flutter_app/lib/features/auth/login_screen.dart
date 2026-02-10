import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../core/url.dart';
import '../../i18n/strings.g.dart';
import '../../state/login_draft_provider.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';

enum _LoginMode { token, password }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialError});

  final String? initialError;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _baseUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  var _loginMode = _LoginMode.password;
  var _shownInitialError = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(loginBaseUrlDraftProvider).trim();
    if (draft.isNotEmpty) {
      _baseUrlController.text = draft;
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
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
        return context.t.strings.login.errors.connectionFailedWithMessage(message: serverMessage);
      }
    } else if (error is FormatException) {
      final message = error.message.trim();
      if (message.isNotEmpty) {
        return context.t.strings.login.errors.connectionFailedWithMessage(message: message);
      }
    }
    return context.t.strings.login.errors.connectionFailed(error: error.toString());
  }

  String _formatPasswordLoginError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        return context.t.strings.login.errors.signInFailed;
      }
      final serverMessage = _extractServerMessage(error.response?.data);
      if (serverMessage.isNotEmpty) {
        return context.t.strings.login.errors.signInFailedWithMessage(message: serverMessage);
      }
    } else if (error is FormatException) {
      final message = error.message.trim();
      if (message.isNotEmpty) {
        return context.t.strings.login.errors.signInFailedWithMessage(message: message);
      }
    }
    return context.t.strings.login.errors.signInFailedWithMessage(message: error.toString());
  }

  Uri? _resolveBaseUrl() {
    final baseUrlRaw = _baseUrlController.text.trim();
    final baseUrl = Uri.tryParse(baseUrlRaw);
    if (baseUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.login.errors.invalidServerUrl),
        ),
      );
      return null;
    }

    final sanitizedBaseUrl = sanitizeUserBaseUrl(baseUrl);
    if (sanitizedBaseUrl.toString() != baseUrl.toString()) {
      _baseUrlController.text = sanitizedBaseUrl.toString();
      ref.read(loginBaseUrlDraftProvider.notifier).state =
          _baseUrlController.text;
      showTopToast(
        context,
        context.t.strings.login.errors.serverUrlNormalized,
      );
    }
    return sanitizedBaseUrl;
  }

  Future<void> _connect() async {
    if (_loginMode == _LoginMode.password) {
      return _connectWithPassword();
    }
    return _connectWithToken();
  }

  Future<void> _connectWithToken() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final tokenRaw = _tokenController.text.trim();
    final token = _normalizeTokenInput(tokenRaw);
    if (token != tokenRaw) {
      _tokenController.text = token;
    }
    final baseUrl = _resolveBaseUrl();
    if (baseUrl == null) {
      return;
    }

    await ref
        .read(appSessionProvider.notifier)
        .addAccountWithPat(baseUrl: baseUrl, personalAccessToken: token);

    final sessionAsync = ref.read(appSessionProvider);
    if (sessionAsync.hasError) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatLoginError(sessionAsync.error!, token: token)),
        ),
      );
      return;
    }

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      context.safePop();
    }
  }

  Future<void> _connectWithPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final baseUrl = _resolveBaseUrl();
    if (baseUrl == null) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final useLegacyApi = ref.read(appPreferencesProvider).useLegacyApi;

    await ref
        .read(appSessionProvider.notifier)
        .addAccountWithPassword(
          baseUrl: baseUrl,
          username: username,
          password: password,
          useLegacyApi: useLegacyApi,
        );

    final sessionAsync = ref.read(appSessionProvider);
    if (sessionAsync.hasError) {
      if (!mounted) return;
      _passwordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatPasswordLoginError(sessionAsync.error!))),
      );
      return;
    }

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      context.safePop();
    }
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
  }) {
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
              hintStyle: TextStyle(
                color: textMuted.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(appSessionProvider);
    final isBusy = sessionAsync.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.7);
    final useLegacyApi = ref.watch(
      appPreferencesProvider.select((p) => p.useLegacyApi),
    );
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
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.t.strings.login.title),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            const SizedBox(height: 6),
            Text(
              modeDescription,
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildField(
                    controller: _baseUrlController,
                    label: context.t.strings.login.field.serverUrlLabel,
                    hint: 'http://localhost:5230',
                    enabled: !isBusy,
                    obscureText: false,
                    keyboardType: TextInputType.url,
                    isDark: isDark,
                    card: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    onChanged: (v) =>
                        ref.read(loginBaseUrlDraftProvider.notifier).state = v,
                    validator: (v) {
                      final raw = (v ?? '').trim();
                      if (raw.isEmpty) {
                        return context.t.strings.login.validation.serverUrlRequired;
                      }
                      final uri = Uri.tryParse(raw);
                      if (uri == null || !(uri.hasScheme && uri.hasAuthority)) {
                        return context.t.strings.login.validation.serverUrlInvalid;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
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
                          return context.t.strings.login.validation.usernameRequired;
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
                          return context.t.strings.login.validation.passwordRequired;
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
                          return context.t.strings.login.validation.tokenRequired;
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.t.strings.login.compatibility.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                        ),
                      ),
                      Switch(
                        value: useLegacyApi,
                        onChanged: isBusy
                            ? null
                            : (v) => ref
                                  .read(appPreferencesProvider.notifier)
                                  .setUseLegacyApi(v),
                        activeThumbColor: Colors.white,
                        activeTrackColor: MemoFlowPalette.primary,
                        inactiveTrackColor: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.12),
                        inactiveThumbColor: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t.strings.login.compatibility.description,
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isBusy ? null : _connect,
                      icon: isBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
