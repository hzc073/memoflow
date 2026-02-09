import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/models/shortcut.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import '../../state/user_settings_provider.dart';
import 'shortcut_editor_screen.dart';

class ShortcutsSettingsScreen extends ConsumerStatefulWidget {
  const ShortcutsSettingsScreen({super.key});

  @override
  ConsumerState<ShortcutsSettingsScreen> createState() => _ShortcutsSettingsScreenState();
}

class _ShortcutsSettingsScreenState extends ConsumerState<ShortcutsSettingsScreen> {
  var _saving = false;

  Future<void> _openEditor({Shortcut? shortcut}) async {
    final result = await Navigator.of(context).push<ShortcutEditorResult>(
      MaterialPageRoute<ShortcutEditorResult>(
        builder: (_) => ShortcutEditorScreen(shortcut: shortcut),
      ),
    );
    if (result == null) return;
    await _saveShortcut(
      shortcut: shortcut,
      title: result.title,
      filter: result.filter,
    );
  }

  Future<void> _saveShortcut({
    required Shortcut? shortcut,
    required String title,
    required String filter,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(memosApiProvider);
      final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
      if (account == null) {
        throw StateError('Not authenticated');
      }
      if (shortcut == null) {
        await api.createShortcut(
          userName: account.user.name,
          title: title,
          filter: filter,
        );
      } else {
        await api.updateShortcut(
          userName: account.user.name,
          shortcut: shortcut,
          title: title,
          filter: filter,
        );
      }
      ref.invalidate(shortcutsProvider);
      if (!mounted) return;
      showTopToast(
        context,
        context.tr(zh: '已保存', en: 'Saved'),
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

  Future<void> _deleteShortcut(Shortcut shortcut) async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr(zh: '删除快捷筛选', en: 'Delete Shortcut')),
            content: Text(context.tr(zh: '确定要删除该快捷筛选吗？', en: 'Are you sure you want to delete this shortcut?')),
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
      final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
      if (account == null) {
        throw StateError('Not authenticated');
      }
      await ref.read(memosApiProvider).deleteShortcut(
            userName: account.user.name,
            shortcut: shortcut,
          );
      ref.invalidate(shortcutsProvider);
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

  String _formatLoadError(BuildContext context, Object error) {
    if (error is UnsupportedError) {
      return context.tr(zh: '当前服务器不支持快捷筛选', en: 'Shortcuts are not supported on this server.');
    }
    if (error is DioException) {
      final status = error.response?.statusCode ?? 0;
      if (status == 404 || status == 405) {
        return context.tr(zh: '当前服务器不支持快捷筛选', en: 'Shortcuts are not supported on this server.');
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

    final shortcutsAsync = ref.watch(shortcutsProvider);

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
        title: Text(context.tr(zh: '快捷筛选', en: 'Shortcuts')),
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
          shortcutsAsync.when(
            data: (shortcuts) {
              if (shortcuts.isEmpty) {
                return Center(
                  child: Text(context.tr(zh: '暂无快捷筛选', en: 'No shortcuts configured'), style: TextStyle(color: textMuted)),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  _Group(
                    card: card,
                    divider: divider,
                    children: [
                      for (final shortcut in shortcuts)
                        _ShortcutRow(
                          shortcut: shortcut,
                          textMain: textMain,
                          textMuted: textMuted,
                          onEdit: () {
                            maybeHaptic();
                            _openEditor(shortcut: shortcut);
                          },
                          onDelete: () {
                            maybeHaptic();
                            _deleteShortcut(shortcut);
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
                      onPressed: () => ref.invalidate(shortcutsProvider),
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

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.shortcut,
    required this.textMain,
    required this.textMuted,
    required this.onEdit,
    required this.onDelete,
  });

  final Shortcut shortcut;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = shortcut.title.trim().isEmpty ? '--' : shortcut.title.trim();
    final filter = shortcut.filter.trim();
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
                if (filter.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(filter, style: TextStyle(fontSize: 12, color: textMuted)),
                ],
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

