import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/models/user_setting.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/user_settings_provider.dart';
import '../../i18n/strings.g.dart';

class WebhooksSettingsScreen extends ConsumerStatefulWidget {
  const WebhooksSettingsScreen({super.key});

  @override
  ConsumerState<WebhooksSettingsScreen> createState() => _WebhooksSettingsScreenState();
}

class _WebhooksSettingsScreenState extends ConsumerState<WebhooksSettingsScreen> {
  var _saving = false;

  Future<void> _openEditor({UserWebhook? webhook}) async {
    final nameController = TextEditingController(text: webhook?.displayName ?? '');
    final urlController = TextEditingController(text: webhook?.url ?? '');
    final isEditing = webhook != null;

    final result = await showDialog<_WebhookDraft>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEditing ? context.t.strings.legacy.msg_edit_webhook : context.t.strings.legacy.msg_add_webhook,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: context.t.strings.legacy.msg_display_name),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                labelText: context.t.strings.legacy.msg_url,
                hintText: 'https://example.com/webhook',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.safePop(),
            child: Text(context.t.strings.legacy.msg_cancel_2),
          ),
          FilledButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isEmpty) return;
              context.safePop(
                _WebhookDraft(
                  displayName: nameController.text.trim(),
                  url: url,
                ),
              );
            },
            child: Text(context.t.strings.legacy.msg_save),
          ),
        ],
      ),
    );

    if (result == null) return;
    await _saveWebhook(
      webhook: webhook,
      displayName: result.displayName,
      url: result.url,
    );
  }

  Future<void> _saveWebhook({
    required UserWebhook? webhook,
    required String displayName,
    required String url,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(memosApiProvider);
      if (webhook == null) {
        await api.createUserWebhook(displayName: displayName, url: url);
      } else {
        await api.updateUserWebhook(webhook: webhook, displayName: displayName, url: url);
      }
      ref.invalidate(userWebhooksProvider);
      if (!mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.msg_saved_2,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_save_failed_3(e: e))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteWebhook(UserWebhook webhook) async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t.strings.legacy.msg_delete_webhook),
            content: Text(context.t.strings.legacy.msg_sure_want_delete_webhook),
            actions: [
              TextButton(
                onPressed: () => context.safePop(false),
                child: Text(context.t.strings.legacy.msg_cancel_2),
              ),
              FilledButton(
                onPressed: () => context.safePop(true),
                child: Text(context.t.strings.legacy.msg_delete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() => _saving = true);
    try {
      await ref.read(memosApiProvider).deleteUserWebhook(webhook: webhook);
      ref.invalidate(userWebhooksProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_delete_failed(e: e))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _displayName(UserWebhook webhook) {
    final displayName = webhook.displayName.trim();
    if (displayName.isNotEmpty) return displayName;
    final name = webhook.name.trim();
    if (name.isNotEmpty) return name;
    return webhook.url;
  }

  String _formatLoadError(BuildContext context, Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode ?? 0;
      if (status == 404 || status == 405) {
        return context.t.strings.legacy.msg_webhooks_not_supported_server;
      }
    }
    return context.t.strings.legacy.msg_failed_load_try;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);
    final hapticsEnabled = ref.watch(appPreferencesProvider.select((p) => p.hapticsEnabled));

    void maybeHaptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    final webhooksAsync = ref.watch(userWebhooksProvider);

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
        title: Text(context.t.strings.legacy.msg_webhooks),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: context.t.strings.legacy.msg_add,
            icon: const Icon(Icons.add),
            onPressed: _saving
                ? null
                : () {
                    maybeHaptic();
                    _openEditor();
                  },
          ),
        ],
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
          webhooksAsync.when(
            data: (webhooks) {
              if (webhooks.isEmpty) {
                return Center(
                  child: Text(context.t.strings.legacy.msg_no_webhooks_configured, style: TextStyle(color: textMuted)),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  _Group(
                    card: card,
                    divider: divider,
                    children: [
                      for (final webhook in webhooks)
                        _WebhookRow(
                          title: _displayName(webhook),
                          url: webhook.url,
                          textMain: textMain,
                          textMuted: textMuted,
                          onEdit: () {
                            maybeHaptic();
                            _openEditor(webhook: webhook);
                          },
                          onDelete: () {
                            maybeHaptic();
                            _deleteWebhook(webhook);
                          },
                        ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t.strings.legacy.msg_failed_load_2,
                      style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatLoadError(context, error),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(userWebhooksProvider),
                      child: Text(context.t.strings.legacy.msg_retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebhookRow extends StatelessWidget {
  const _WebhookRow({
    required this.title,
    required this.url,
    required this.textMain,
    required this.textMuted,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String url;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: textMain)),
                const SizedBox(height: 4),
                Text(url, style: TextStyle(fontSize: 12, color: textMuted)),
              ],
            ),
          ),
          IconButton(
            tooltip: context.t.strings.legacy.msg_edit,
            icon: Icon(Icons.edit, size: 18, color: textMuted),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: context.t.strings.legacy.msg_delete,
            icon: Icon(Icons.delete_outline, size: 18, color: textMuted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
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

class _WebhookDraft {
  const _WebhookDraft({
    required this.displayName,
    required this.url,
  });

  final String displayName;
  final String url;
}
