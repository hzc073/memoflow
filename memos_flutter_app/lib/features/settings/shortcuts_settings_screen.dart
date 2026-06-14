import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/top_toast.dart';
import '../../data/models/shortcut.dart';
import '../../i18n/strings.g.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/settings/user_settings_provider.dart';
import '../../state/system/session_provider.dart';
import 'shortcut_editor_screen.dart';
import 'settings_ui.dart';

class ShortcutsSettingsScreen extends ConsumerStatefulWidget {
  const ShortcutsSettingsScreen({super.key});

  @override
  ConsumerState<ShortcutsSettingsScreen> createState() =>
      _ShortcutsSettingsScreenState();
}

class _ShortcutsSettingsScreenState
    extends ConsumerState<ShortcutsSettingsScreen> {
  var _saving = false;

  Future<void> _openEditor({Shortcut? shortcut}) async {
    final result = await openShortcutEditor(context, shortcut: shortcut);
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
      await api.ensureServerHintsLoaded();
      final useLocalShortcuts =
          api.usesLegacySearchFilterDialect ||
          api.shortcutsSupportedHint == false;
      final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
      if (account == null) {
        throw StateError('Not authenticated');
      }
      if (useLocalShortcuts) {
        if (shortcut == null) {
          await ref
              .read(localShortcutsRepositoryProvider)
              .create(title: title, filter: filter);
        } else {
          await ref
              .read(localShortcutsRepositoryProvider)
              .update(shortcut: shortcut, title: title, filter: filter);
        }
      } else {
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
      }
      ref.invalidate(shortcutsProvider);
      if (!mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_saved_2);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_save_failed_3(e: e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteShortcut(Shortcut shortcut) async {
    if (_saving) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t.strings.legacy.msg_delete_shortcut),
            content: Text(
              context.t.strings.legacy.msg_sure_want_delete_shortcut,
            ),
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
      final api = ref.read(memosApiProvider);
      await api.ensureServerHintsLoaded();
      final useLocalShortcuts =
          api.usesLegacySearchFilterDialect ||
          api.shortcutsSupportedHint == false;
      final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
      if (account == null) {
        throw StateError('Not authenticated');
      }
      if (useLocalShortcuts) {
        await ref.read(localShortcutsRepositoryProvider).delete(shortcut);
      } else {
        await api.deleteShortcut(
          userName: account.user.name,
          shortcut: shortcut,
        );
      }
      ref.invalidate(shortcutsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_delete_failed(e: e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _formatLoadError(BuildContext context, Object error) {
    if (error is UnsupportedError) {
      return context.t.strings.legacy.msg_shortcuts_not_supported_server;
    }
    if (error is DioException) {
      final status = error.response?.statusCode ?? 0;
      if (status == 404 || status == 405) {
        return context.t.strings.legacy.msg_shortcuts_not_supported_server;
      }
    }
    return context.t.strings.legacy.msg_failed_load_try;
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.t.strings.legacy;
    final hapticsEnabled = ref.watch(
      devicePreferencesProvider.select((p) => p.hapticsEnabled),
    );

    void maybeHaptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    final shortcutsAsync = ref.watch(shortcutsProvider);

    return SettingsPage(
      title: Text(tr.msg_shortcuts),
      actions: [
        IconButton(
          tooltip: tr.msg_add,
          icon: const Icon(Icons.add),
          onPressed: _saving
              ? null
              : () {
                  maybeHaptic();
                  _openEditor();
                },
        ),
      ],
      children: [
        shortcutsAsync.when(
          data: (shortcuts) {
            if (shortcuts.isEmpty) {
              return SettingsSection(
                children: [
                  SettingsInfoRow(description: tr.msg_no_shortcuts_configured),
                ],
              );
            }

            return SettingsSection(
              children: [
                for (final shortcut in shortcuts)
                  _ShortcutRow(
                    shortcut: shortcut,
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
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => SettingsSection(
            children: [
              SettingsWarningRow(message: tr.msg_failed_load_2),
              SettingsInfoRow(description: _formatLoadError(context, error)),
            ],
          ),
        ),
        if (shortcutsAsync.hasError) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SettingsAction(
              onPressed: () => ref.invalidate(shortcutsProvider),
              icon: const Icon(Icons.refresh),
              label: Text(tr.msg_retry),
            ),
          ),
        ],
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.shortcut,
    required this.onEdit,
    required this.onDelete,
  });

  final Shortcut shortcut;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = shortcut.title.trim().isEmpty ? '--' : shortcut.title.trim();
    final filter = shortcut.filter.trim();
    final tokens = settingsPageTokens(context);
    return SettingsCustomRow(
      title: SettingsRowTitle(title),
      description: filter.isEmpty ? null : SettingsRowDescription(filter),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.t.strings.legacy.msg_edit,
            icon: Icon(Icons.edit, size: 18, color: tokens.textMuted),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: context.t.strings.legacy.msg_delete,
            icon: Icon(Icons.delete_outline, size: 18, color: tokens.textMuted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
