import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/desktop_settings_window.dart';
import '../../core/hash.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../data/db/app_database.dart';
import '../../data/models/local_library.dart';
import '../../data/settings/image_bed_settings_repository.dart';
import '../../state/database_provider.dart';
import '../../state/local_library_provider.dart';
import '../../state/local_library_scanner.dart';
import '../../state/personal_access_token_repository_provider.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import '../auth/login_screen.dart';
import 'local_mode_setup_screen.dart';
import 'user_general_settings_screen.dart';
import '../../i18n/strings.g.dart';

class AccountSecurityScreen extends ConsumerWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final hapticsEnabled = ref.watch(
      appPreferencesProvider.select((p) => p.hapticsEnabled),
    );

    void haptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    final session = ref.watch(appSessionProvider).valueOrNull;
    final accounts = session?.accounts ?? const [];
    final currentKey = session?.currentKey;
    final currentAccount = session?.currentAccount;
    final localLibraries = ref.watch(localLibrariesProvider);
    final currentLocalLibrary = ref.watch(currentLocalLibraryProvider);
    final currentName = currentLocalLibrary != null
        ? (currentLocalLibrary.name.isNotEmpty
              ? currentLocalLibrary.name
              : context.t.strings.legacy.msg_local_library)
        : currentAccount == null
        ? context.t.strings.legacy.msg_not_signed
        : (currentAccount.user.displayName.isNotEmpty
              ? currentAccount.user.displayName
              : (currentAccount.user.name.isNotEmpty
                    ? currentAccount.user.name
                    : context.t.strings.legacy.msg_account));
    final currentSubtitle = currentLocalLibrary != null
        ? currentLocalLibrary.locationLabel
        : currentAccount?.baseUrl.toString() ?? "";

    Future<void> _maybeScanLocalLibrary() async {
      if (!context.mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.t.strings.legacy.msg_scan_local_library),
              content: Text(
                context
                    .t
                    .strings
                    .legacy
                    .msg_scan_disk_directory_merge_local_database,
              ),
              actions: [
                TextButton(
                  onPressed: () => context.safePop(false),
                  child: Text(context.t.strings.legacy.msg_cancel_2),
                ),
                FilledButton(
                  onPressed: () => context.safePop(true),
                  child: Text(context.t.strings.legacy.msg_scan),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      final scanner = ref.read(localLibraryScannerProvider);
      if (scanner == null) return;
      try {
        await scanner.scanAndMerge(context);
        if (!context.mounted) return;
        showTopToast(context, context.t.strings.legacy.msg_scan_completed);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_scan_failed(e: e)),
          ),
        );
      }
    }

    Future<void> _addLocalLibrary() async {
      final result = await LocalModeSetupScreen.show(
        context,
        title: context.t.strings.legacy.msg_add_local_library,
        confirmLabel: context.t.strings.legacy.msg_confirm,
        cancelLabel: context.t.strings.legacy.msg_cancel_2,
        initialName: context.t.strings.legacy.msg_local_library,
      );
      if (result == null) return;
      final keySeed = (result.treeUri ?? result.rootPath ?? '').trim();
      if (keySeed.isEmpty) return;
      final key = 'local_${fnv1a64Hex(keySeed)}';
      final existed = localLibraries.any((l) => l.key == key);
      if (!existed) {
        try {
          await AppDatabase.deleteDatabaseFile(
            dbName: databaseNameForAccountKey(key),
          );
        } catch (_) {}
      }
      final now = DateTime.now();
      final library = LocalLibrary(
        key: key,
        name: result.name.trim(),
        treeUri: result.treeUri,
        rootPath: result.rootPath,
        createdAt: now,
        updatedAt: now,
      );
      ref.read(localLibrariesProvider.notifier).upsert(library);
      await ref.read(appSessionProvider.notifier).switchWorkspace(key);
      if (result.encryptionEnabled && context.mounted) {
        showTopToast(context, '加密功能当前仅占位，暂未真正生效。');
      }
      if (!context.mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      await _maybeScanLocalLibrary();
      if (!context.mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_local_library_added);
    }

    Future<void> _removeLocalLibrary(LocalLibrary library) async {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.t.strings.legacy.msg_remove_local_library),
              content: Text(
                context
                    .t
                    .strings
                    .legacy
                    .msg_only_local_index_removed_disk_files,
              ),
              actions: [
                TextButton(
                  onPressed: () => context.safePop(false),
                  child: Text(context.t.strings.legacy.msg_cancel_2),
                ),
                FilledButton(
                  onPressed: () => context.safePop(true),
                  child: Text(context.t.strings.legacy.msg_confirm),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;

      final wasCurrent = library.key == currentKey;
      final remainingLocalLibraries = localLibraries
          .where((l) => l.key != library.key)
          .toList(growable: false);
      final shouldReopenOnboarding =
          accounts.isEmpty && remainingLocalLibraries.isEmpty;
      String? nextKey;
      if (wasCurrent) {
        for (final a in accounts) {
          if (a.key != library.key) {
            nextKey = a.key;
            break;
          }
        }
        if (nextKey == null) {
          for (final l in remainingLocalLibraries) {
            nextKey = l.key;
            break;
          }
        }
      }

      if (wasCurrent) {
        await ref.read(appSessionProvider.notifier).setCurrentKey(nextKey);
      }
      await ref.read(localLibrariesProvider.notifier).remove(library.key);
      await AppDatabase.deleteDatabaseFile(
        dbName: databaseNameForAccountKey(library.key),
      );

      if (shouldReopenOnboarding) {
        final currentPreferences = ref.read(appPreferencesProvider);
        await ref
            .read(appPreferencesProvider.notifier)
            .setAll(
              currentPreferences.copyWith(hasSelectedLanguage: false),
              triggerSync: false,
            );
        await requestMainWindowReopenOnboardingIfSupported();
      }

      if (!context.mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_local_library_removed);
    }

    Future<void> removeAccountAndClearCache(String accountKey) async {
      final wasCurrent = accountKey == currentKey;
      final isLastAccount =
          accounts.length == 1 && accounts.first.key == accountKey;
      final shouldReopenOnboarding = isLastAccount && localLibraries.isEmpty;
      final sessionNotifier = ref.read(appSessionProvider.notifier);
      final preferencesNotifier = ref.read(appPreferencesProvider.notifier);
      final tokenRepo = ref.read(personalAccessTokenRepositoryProvider);
      final imageBedRepo = ImageBedSettingsRepository(
        ref.read(secureStorageProvider),
        accountKey: accountKey,
      );
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                wasCurrent
                    ? context.t.strings.legacy.msg_sign
                    : context.t.strings.legacy.msg_remove_account,
              ),
              content: Text(
                context
                    .t
                    .strings
                    .legacy
                    .msg_also_clear_local_cache_account_offline,
              ),
              actions: [
                TextButton(
                  onPressed: () => context.safePop(false),
                  child: Text(context.t.strings.legacy.msg_cancel_2),
                ),
                FilledButton(
                  onPressed: () => context.safePop(true),
                  child: Text(context.t.strings.legacy.msg_confirm),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      if (!context.mounted) return;

      final dbName = databaseNameForAccountKey(accountKey);
      if (shouldReopenOnboarding) {
        final currentPreferences = ref.read(appPreferencesProvider);
        await preferencesNotifier.setAll(
          currentPreferences.copyWith(hasSelectedLanguage: false),
          triggerSync: false,
        );
        await requestMainWindowReopenOnboardingIfSupported();
      }
      try {
        await sessionNotifier.removeAccount(accountKey);
        await AppDatabase.deleteDatabaseFile(dbName: dbName);
        await tokenRepo.deleteForAccount(accountKey: accountKey);
        await imageBedRepo.clear();
        if (!context.mounted) return;
        if (shouldReopenOnboarding) {
          Navigator.of(
            context,
            rootNavigator: true,
          ).pushNamedAndRemoveUntil('/', (route) => false);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_local_cache_cleared),
          ),
        );
        if (wasCurrent) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_action_failed(e: e)),
          ),
        );
      }
    }

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
        title: Text(context.t.strings.legacy.msg_account_security),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _ProfileCard(
                card: card,
                textMain: textMain,
                textMuted: textMuted,
                title: currentName,
                subtitle: currentSubtitle,
              ),
              const SizedBox(height: 12),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _SettingRow(
                    icon: Icons.person_add,
                    label: context.t.strings.legacy.msg_add_account,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                  ),
                  _SettingRow(
                    icon: Icons.folder_open,
                    label: context.t.strings.legacy.msg_add_local_library,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () async {
                      haptic();
                      await _addLocalLibrary();
                    },
                  ),
                  _SettingRow(
                    icon: Icons.settings_outlined,
                    label: context.t.strings.legacy.msg_user_general_settings,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const UserGeneralSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  if (currentKey != null)
                    _SettingRow(
                      icon: Icons.logout,
                      label: context.t.strings.legacy.msg_sign_2,
                      textMain: textMain,
                      textMuted: textMuted,
                      onTap: () async {
                        haptic();
                        await removeAccountAndClearCache(currentKey);
                      },
                    ),
                ],
              ),
              if (accounts.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  context.t.strings.legacy.msg_accounts,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                _CardGroup(
                  card: card,
                  divider: divider,
                  children: [
                    for (final a in accounts)
                      _AccountRow(
                        isCurrent: a.key == currentKey,
                        title: a.user.displayName.isNotEmpty
                            ? a.user.displayName
                            : (a.user.name.isNotEmpty ? a.user.name : a.key),
                        subtitle: a.baseUrl.toString(),
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () {
                          haptic();
                          ref
                              .read(appSessionProvider.notifier)
                              .switchAccount(a.key);
                        },
                        onDelete: () async {
                          haptic();
                          await removeAccountAndClearCache(a.key);
                        },
                      ),
                  ],
                ),
              ],
              if (localLibraries.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  context.t.strings.legacy.msg_local_libraries,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                _CardGroup(
                  card: card,
                  divider: divider,
                  children: [
                    for (final l in localLibraries)
                      _AccountRow(
                        isCurrent: l.key == currentKey,
                        title: l.name.isNotEmpty
                            ? l.name
                            : context.t.strings.legacy.msg_local_library,
                        subtitle: l.locationLabel,
                        textMain: textMain,
                        textMuted: textMuted,
                        onTap: () async {
                          haptic();
                          await ref
                              .read(appSessionProvider.notifier)
                              .switchWorkspace(l.key);
                          if (!context.mounted) return;
                          await WidgetsBinding.instance.endOfFrame;
                          if (!context.mounted) return;
                          await _maybeScanLocalLibrary();
                        },
                        onDelete: () async {
                          haptic();
                          await _removeLocalLibrary(l);
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(
                context
                    .t
                    .strings
                    .legacy
                    .msg_removing_signing_clear_local_cache_account,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: textMuted.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.title,
    required this.subtitle,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            child: Icon(Icons.person, color: textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: textMain,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.textMain,
    required this.textMuted,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color textMain;
  final Color textMuted;
  final VoidCallback? onTap;

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

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.isCurrent,
    required this.title,
    required this.subtitle,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
    required this.onDelete,
  });

  final bool isCurrent;
  final String title;
  final String subtitle;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                isCurrent ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.t.strings.legacy.msg_remove,
                icon: Icon(Icons.delete_outline, color: textMuted),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
