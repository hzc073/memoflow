import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../data/models/user_setting.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/user_settings_provider.dart';

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
          isEditing ? context.tr(zh: '编辑 Webhook', en: 'Edit Webhook') : context.tr(zh: '新增 Webhook', en: 'Add Webhook'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: context.tr(zh: '显示名称', en: 'Display name')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                labelText: context.tr(zh: 'URL', en: 'URL'),
                hintText: 'https://example.com/webhook',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.safePop(),
            child: Text(context.tr(zh: '取消', en: 'Cancel')),
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
            child: Text(context.tr(zh: '保存', en: 'Save')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '已保存', en: 'Saved'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '保存失败：$e', en: 'Save failed: $e'))),
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
            title: Text(context.tr(zh: '删除 Webhook', en: 'Delete Webhook')),
            content: Text(context.tr(zh: '确定要删除该 Webhook 吗？', en: 'Are you sure you want to delete this webhook?')),
            actions: [
              TextButton(
                onPressed: () => context.safePop(false),
                child: Text(context.tr(zh: '取消', en: 'Cancel')),
              ),
              FilledButton(
                onPressed: () => context.safePop(true),
                child: Text(context.tr(zh: '删除', en: 'Delete')),
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
        SnackBar(content: Text(context.tr(zh: '删除失败：$e', en: 'Delete failed: $e'))),
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
        return context.tr(zh: '当前服务器不支持 Webhooks', en: 'Webhooks are not supported on this server.');
      }
    }
    return context.tr(zh: '加载失败，请稍后重试', en: 'Failed to load. Please try again.');
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
          tooltip: context.tr(zh: '返回', en: 'Back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.tr(zh: 'Webhooks', en: 'Webhooks')),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: context.tr(zh: '新增', en: 'Add'),
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
                  child: Text(context.tr(zh: '暂无 Webhooks', en: 'No webhooks configured'), style: TextStyle(color: textMuted)),
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
                      context.tr(zh: '加载失败', en: 'Failed to load'),
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
                      child: Text(context.tr(zh: '重试', en: 'Retry')),
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
            tooltip: context.tr(zh: '编辑', en: 'Edit'),
            icon: Icon(Icons.edit, size: 18, color: textMuted),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: context.tr(zh: '删除', en: 'Delete'),
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
