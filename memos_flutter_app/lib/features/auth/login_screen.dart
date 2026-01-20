import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/url.dart';
import '../../state/login_draft_provider.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';

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
    super.dispose();
  }

  String _normalizeTokenInput(String raw) {
    var token = raw.trim();
    if (token.isEmpty) return token;
    final match = RegExp(r'^(?:authorization:\s*)?bearer\s+', caseSensitive: false).firstMatch(token);
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
          return context.tr(
            zh: '认证失败，请确认 Token 是否有效或未过期',
            en: 'Authentication failed. Check that the token is valid and not expired.',
          );
        }
        return context.tr(
          zh: '认证失败。新版 Memos 请使用以 memos_pat_ 开头的 PAT（不要粘贴 Bearer 前缀）',
          en: 'Authentication failed. For new Memos use a PAT starting with memos_pat_ (do not paste the Bearer prefix).',
        );
      }
      final serverMessage = _extractServerMessage(error.response?.data);
      if (serverMessage.isNotEmpty) {
        return context.tr(
          zh: '连接失败：$serverMessage',
          en: 'Connection failed: $serverMessage',
        );
      }
    } else if (error is FormatException) {
      final message = error.message.trim();
      if (message.isNotEmpty) {
        return context.tr(
          zh: '连接失败：$message',
          en: 'Connection failed: $message',
        );
      }
    }
    return context.tr(zh: '连接失败：$error', en: 'Connection failed: $error');
  }

  Future<void> _connect() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final baseUrlRaw = _baseUrlController.text.trim();
    final tokenRaw = _tokenController.text.trim();
    final token = _normalizeTokenInput(tokenRaw);
    if (token != tokenRaw) {
      _tokenController.text = token;
    }
    final baseUrl = Uri.tryParse(baseUrlRaw);
    if (baseUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '服务器地址无效', en: 'Invalid server URL'))),
      );
      return;
    }

    final sanitizedBaseUrl = sanitizeUserBaseUrl(baseUrl);
    if (sanitizedBaseUrl.toString() != baseUrl.toString()) {
      _baseUrlController.text = sanitizedBaseUrl.toString();
      ref.read(loginBaseUrlDraftProvider.notifier).state = _baseUrlController.text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(zh: '已规范化服务器地址（移除多余路径）', en: 'Server URL normalized (removed extra path segments)')
          ),
        ),
      );
    }

    await ref.read(appSessionProvider.notifier).addAccountWithPat(
          baseUrl: sanitizedBaseUrl,
          personalAccessToken: token,
        );

    final sessionAsync = ref.read(appSessionProvider);
    if (sessionAsync.hasError) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatLoginError(sessionAsync.error!, token: token))),
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
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted)),
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
              hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(appSessionProvider);
    final isBusy = sessionAsync.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.7);
    final useLegacyApi = ref.watch(appPreferencesProvider.select((p) => p.useLegacyApi));

    if (!_shownInitialError) {
      _shownInitialError = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final error = widget.initialError;
        if (error != null && error.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        }
      });
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.tr(zh: '返回', en: 'Back'),
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.tr(zh: '连接 Memos', en: 'Connect to Memos')),
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
              context.tr(zh: '使用个人访问令牌登录', en: 'Sign in with Personal Access Token'),
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
                    label: context.tr(zh: '服务器地址', en: 'Server URL'),
                    hint: 'http://localhost:5230',
                    enabled: !isBusy,
                    obscureText: false,
                    keyboardType: TextInputType.url,
                    isDark: isDark,
                    card: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    onChanged: (v) => ref.read(loginBaseUrlDraftProvider.notifier).state = v,
                    validator: (v) {
                      final raw = (v ?? '').trim();
                      if (raw.isEmpty) return context.tr(zh: '请输入服务器地址', en: 'Please enter server URL');
                      final uri = Uri.tryParse(raw);
                      if (uri == null || !(uri.hasScheme && uri.hasAuthority)) {
                        return context.tr(
                          zh: '请输入完整地址（包含 http/https 与端口）',
                          en: 'Enter full URL (including http/https and port)',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _tokenController,
                    label: 'Token (PAT)',
                    hint: 'Token (PAT)',
                    enabled: !isBusy,
                    obscureText: true,
                    isDark: isDark,
                    card: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return context.tr(zh: '请输入 Token', en: 'Please enter token');
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr(zh: '兼容模式', en: 'Compatibility Mode'),
                          style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
                        ),
                      ),
                      Switch(
                        value: useLegacyApi,
                        onChanged: isBusy
                            ? null
                            : (v) => ref.read(appPreferencesProvider.notifier).setUseLegacyApi(v),
                        activeThumbColor: Colors.white,
                        activeTrackColor: MemoFlowPalette.primary,
                        inactiveTrackColor:
                            isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.12),
                        inactiveThumbColor: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(zh: '使用旧版接口（适配旧版 Memos）', en: 'Use legacy endpoints (for older Memos servers)'),
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isBusy ? null : _connect,
                      icon: isBusy
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.link),
                      label: Text(isBusy ? context.tr(zh: '连接中…', en: 'Connecting?') : context.tr(zh: '连接', en: 'Connect')),
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
