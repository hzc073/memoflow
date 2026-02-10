import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/models/personal_access_token.dart';
import '../../state/memos_providers.dart';
import '../../state/personal_access_token_repository_provider.dart';
import '../../state/session_provider.dart';
import '../../i18n/strings.g.dart';

enum _TokenExpiration {
  h8,
  d30,
  never,
}

extension on _TokenExpiration {
  String label(BuildContext context) => switch (this) {
        _TokenExpiration.h8 => '8h',
        _TokenExpiration.d30 => context.t.strings.legacy.msg_v_30_days,
        _TokenExpiration.never => context.t.strings.legacy.msg_never,
      };

  int get expiresInDays => switch (this) {
        // Memos API uses days. "8h" is approximated as 1 day.
        _TokenExpiration.h8 => 1,
        _TokenExpiration.d30 => 30,
        _TokenExpiration.never => 0,
      };
}

class ApiPluginsScreen extends ConsumerStatefulWidget {
  const ApiPluginsScreen({super.key});

  @override
  ConsumerState<ApiPluginsScreen> createState() => _ApiPluginsScreenState();
}

class _ApiPluginsScreenState extends ConsumerState<ApiPluginsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  var _expiration = _TokenExpiration.d30;
  var _creating = false;
  var _refreshing = false;
  var _pressedCreate = false;
  String? _listError;
  List<PersonalAccessToken> _tokens = const [];
  Map<String, String> _tokenValues = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshTokens());
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatError(Object e, BuildContext context) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      String message = '';
      if (data is Map) {
        final m = data['message'] ?? data['error'] ?? data['detail'];
        if (m is String) message = m.trim();
      } else if (data is String) {
        message = data.trim();
      }
      final base = status == null
          ? context.t.strings.legacy.msg_network_request_failed
          : 'HTTP $status';
      if (message.isEmpty) return base;
      return '$base: $message';
    }
    return e.toString();
  }

  static String _formatDate(DateTime? time) {
    final dt = time?.toLocal();
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  static String? _last4(String value) {
    final s = value.trim();
    if (s.isEmpty) return null;
    if (s.length <= 4) return s;
    return s.substring(s.length - 4);
  }

  String _maskedTokenTail(PersonalAccessToken token) {
    final stored = _tokenValues[token.name];
    final tail = _last4(stored ?? token.id);
    if (tail == null || tail.isEmpty) {
      return context.t.strings.legacy.msg_token_tail_unknown;
    }
    return context.t.strings.legacy.msg_token_tail(tail: tail);
  }

  Future<void> _refreshTokens() async {
    if (_refreshing) return;
    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    if (account == null) return;

    setState(() {
      _refreshing = true;
      _listError = null;
    });

    final api = ref.read(memosApiProvider);
    final repo = ref.read(personalAccessTokenRepositoryProvider);
    try {
      final tokens = await api.listPersonalAccessTokens(userName: account.user.name);
      final values = await repo.readAll(accountKey: account.key);
      if (!mounted) return;
      setState(() {
        _tokens = tokens;
        _tokenValues = values;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _listError = _formatError(e, context));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _selectExpiration() async {
    if (_creating) return;
    final selected = await showModalBottomSheet<_TokenExpiration>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              for (final v in _TokenExpiration.values)
                ListTile(
                  title: Text(v.label(context)),
                  trailing: v == _expiration ? const Icon(Icons.check) : null,
                  onTap: () => context.safePop(v),
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    if (!mounted) return;
    setState(() => _expiration = selected);
  }

  Future<void> _showTokenSheet(String token) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                context.t.strings.legacy.msg_token_created,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                context.t.strings.legacy.msg_shown_only_once_copy_keep_safe,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(token),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: token));
                        if (!context.mounted) return;
                        showTopToast(
                          context,
                          context.t.strings.legacy.msg_copied_clipboard,
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: Text(context.t.strings.legacy.msg_copy),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.safePop(),
                      child: Text(context.t.strings.legacy.msg_done),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createToken() async {
    if (_creating) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_not_signed)),
      );
      return;
    }

    setState(() => _creating = true);
    final api = ref.read(memosApiProvider);
    final repo = ref.read(personalAccessTokenRepositoryProvider);
    try {
      final response = await api.createPersonalAccessToken(
        userName: account.user.name,
        description: _descriptionController.text.trim(),
        expiresInDays: _expiration.expiresInDays,
      );
      final token = response.token;
      final tokenName = response.personalAccessToken.name.trim();
      if (tokenName.isNotEmpty) {
        await repo.saveTokenValue(accountKey: account.key, tokenName: tokenName, tokenValue: token);
      }

      await Clipboard.setData(ClipboardData(text: token));
      if (!mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.msg_token_copied_clipboard,
      );
      await _showTokenSheet(token);
      await _refreshTokens();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_create_failed(formatError_e_context: _formatError(e, context)))),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _copyExistingToken(PersonalAccessToken token) async {
    final value = _tokenValues[token.name]?.trim();
    if (value == null || value.isEmpty) {
      showTopToast(
        context,
        context.t.strings.legacy.msg_token_returned_only_once_cannot_fetched,
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    showTopToast(
      context,
      context.t.strings.legacy.msg_copied_clipboard,
    );
  }

  ({String label, Color bg, Color fg}) _statusBadge(PersonalAccessToken token) {
    final expires = token.expiresAt;
    if (expires == null) {
      return (
        label: context.t.strings.legacy.msg_active,
        bg: Colors.green.withValues(alpha: 0.18),
        fg: Colors.green.shade300,
      );
    }

    final now = DateTime.now();
    if (expires.isBefore(now)) {
      return (
        label: context.t.strings.legacy.msg_expired,
        bg: Colors.red.withValues(alpha: 0.18),
        fg: Colors.red.shade300,
      );
    }

    if (expires.difference(now).inDays <= 7) {
      return (
        label: context.t.strings.legacy.msg_expiring,
        bg: MemoFlowPalette.reviewChipOrangeDark.withValues(alpha: 0.22),
        fg: MemoFlowPalette.reviewChipOrangeDark,
      );
    }

    return (
      label: context.t.strings.legacy.msg_active,
      bg: Colors.green.withValues(alpha: 0.18),
      fg: Colors.green.shade300,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final fieldBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);
    final divider = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

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
        title: Text(context.t.strings.legacy.msg_api_plugins),
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
                    colors: [
                      const Color(0xFF0B0B0B),
                      bg,
                      bg,
                    ],
                  ),
                ),
              ),
            ),
          RefreshIndicator(
            color: MemoFlowPalette.primary,
            onRefresh: _refreshTokens,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              children: [
                Text(
                  context.t.strings.legacy.msg_create_token,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMuted),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: divider),
                    boxShadow: isDark
                        ? [
                            BoxShadow(
                              blurRadius: 28,
                              offset: const Offset(0, 16),
                              color: Colors.black.withValues(alpha: 0.45),
                            ),
                          ]
                        : [
                            BoxShadow(
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                              color: Colors.black.withValues(alpha: 0.06),
                            ),
                          ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t.strings.legacy.msg_token_name,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          enabled: !_creating,
                          style: TextStyle(color: textMain, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: context.t.strings.legacy.msg_enter_token_description,
                            hintStyle: TextStyle(color: textMuted),
                            filled: true,
                            fillColor: fieldBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) {
                              return context.t.strings.legacy.msg_enter_token_name;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        Text(
                          context.t.strings.legacy.msg_expiration,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted),
                        ),
                        const SizedBox(height: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _selectExpiration,
                            child: Container(
                              decoration: BoxDecoration(
                                color: fieldBg,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _expiration.label(context),
                                      style: TextStyle(color: textMain, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_down_rounded, color: textMuted),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTapDown: _creating ? null : (_) => setState(() => _pressedCreate = true),
                          onTapCancel: () => setState(() => _pressedCreate = false),
                          onTapUp: _creating
                              ? null
                              : (_) async {
                                  setState(() => _pressedCreate = false);
                                  await _createToken();
                                },
                          child: AnimatedScale(
                            scale: _pressedCreate ? 0.98 : 1,
                            duration: const Duration(milliseconds: 140),
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                color: MemoFlowPalette.primary,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Center(
                                child: _creating
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Text(
                                        context.t.strings.legacy.msg_create_token_2,
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  context.t.strings.legacy.msg_existing_tokens,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMuted),
                ),
                const SizedBox(height: 10),
                if (_listError != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: divider),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(_listError!, style: TextStyle(color: textMain))),
                        TextButton(
                          onPressed: _refreshTokens,
                          child: Text(context.t.strings.legacy.msg_retry),
                        ),
                      ],
                    ),
                  )
                else if (_refreshing && _tokens.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(color: MemoFlowPalette.primary.withValues(alpha: 0.9)),
                    ),
                  )
                else if (_tokens.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: Text(context.t.strings.legacy.msg_no_tokens_yet, style: TextStyle(color: textMuted))),
                  )
                else
                  Column(
                    children: [
                      for (final t in _tokens) ...[
                        _TokenItem(
                          token: t,
                          maskedTail: _maskedTokenTail(t),
                          createdAtLabel: _formatDate(t.createdAt),
                          badge: _statusBadge(t),
                          cardColor: card,
                          borderColor: divider,
                          textMain: textMain,
                          textMuted: textMuted,
                          onCopy: () => _copyExistingToken(t),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    context.t.strings.legacy.msg_keep_token_safe_not_share_api,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.35, color: textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenItem extends StatefulWidget {
  const _TokenItem({
    required this.token,
    required this.maskedTail,
    required this.createdAtLabel,
    required this.badge,
    required this.cardColor,
    required this.borderColor,
    required this.textMain,
    required this.textMuted,
    required this.onCopy,
  });

  final PersonalAccessToken token;
  final String maskedTail;
  final String createdAtLabel;
  final ({String label, Color bg, Color fg}) badge;
  final Color cardColor;
  final Color borderColor;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onCopy;

  @override
  State<_TokenItem> createState() => _TokenItemState();
}

class _TokenItemState extends State<_TokenItem> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.badge.label;
    final badgeBg = widget.badge.bg;
    final badgeFg = widget.badge.fg;

    final title = widget.token.description.trim().isEmpty
        ? context.t.strings.legacy.msg_unnamed_token
        : widget.token.description.trim();
    return Container(
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: widget.borderColor),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: widget.textMain),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: badgeFg)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.t.strings.legacy.msg_created(widget_createdAtLabel: widget.createdAtLabel),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.textMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.maskedTail,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) {
              setState(() => _pressed = false);
              widget.onCopy();
            },
            child: AnimatedScale(
              scale: _pressed ? 0.9 : 1.0,
              duration: const Duration(milliseconds: 140),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.06 : 0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.copy_rounded, size: 18, color: widget.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
