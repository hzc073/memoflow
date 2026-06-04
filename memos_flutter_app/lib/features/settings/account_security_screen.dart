import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/sync_error.dart';
import '../../application/sync/sync_types.dart';
import '../../core/app_localization.dart';
import '../../application/desktop/desktop_settings_window.dart';
import '../../core/sync_error_presenter.dart';
import '../../core/top_toast.dart';
import '../../core/uid.dart';
import '../../data/local_library/local_library_paths.dart';
import '../../data/models/local_library.dart';
import '../../data/repositories/image_bed_settings_repository.dart';
import '../../state/system/local_library_provider.dart';
import '../../state/system/local_library_scanner.dart';
import '../../state/memos/account_security_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/settings/personal_access_token_repository_provider.dart';
import '../../state/system/session_provider.dart';
import '../../platform/platform_route.dart';
import '../../i18n/strings.g.dart';
import '../auth/login_screen.dart';
import 'local_mode_setup_screen.dart';
import 'server_settings_screen.dart';
import 'settings_ui.dart';
import 'user_general_settings_screen.dart';

class AccountSecurityScreen extends ConsumerWidget {
  const AccountSecurityScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticsEnabled = ref.watch(
      devicePreferencesProvider.select((p) => p.hapticsEnabled),
    );
    final tokens = settingsPageTokens(context);

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

    Future<Map<String, bool>> resolveLocalScanConflicts(
      BuildContext context,
      List<LocalScanConflict> conflicts,
    ) async {
      final decisions = <String, bool>{};
      for (final conflict in conflicts) {
        final useDisk =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(context.t.strings.legacy.msg_resolve_conflict),
                content: Text(
                  conflict.isDeletion
                      ? context
                            .t
                            .strings
                            .legacy
                            .msg_memo_missing_disk_but_has_local
                      : context
                            .t
                            .strings
                            .legacy
                            .msg_disk_content_conflicts_local_pending_changes,
                ),
                actions: [
                  TextButton(
                    onPressed: () => context.safePop(false),
                    child: Text(context.t.strings.legacy.msg_keep_local),
                  ),
                  FilledButton(
                    onPressed: () => context.safePop(true),
                    child: Text(context.t.strings.legacy.msg_use_disk),
                  ),
                ],
              ),
            ) ??
            false;
        decisions[conflict.memoUid] = useDisk;
      }
      return decisions;
    }

    String formatLocalScanError(BuildContext context, SyncError error) {
      return presentSyncError(language: context.appLanguage, error: error);
    }

    Future<void> maybeScanLocalLibrary() async {
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
        var result = await scanner.scanAndMerge(forceDisk: false);
        while (result is LocalScanConflictResult) {
          if (!context.mounted) return;
          final decisions = await resolveLocalScanConflicts(
            context,
            result.conflicts,
          );
          result = await scanner.scanAndMerge(
            forceDisk: false,
            conflictDecisions: decisions,
          );
        }
        if (!context.mounted) return;
        switch (result) {
          case LocalScanSuccess():
            showTopToast(context, context.t.strings.legacy.msg_scan_completed);
            return;
          case LocalScanFailure(:final error):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.t.strings.legacy.msg_scan_failed(
                    e: formatLocalScanError(context, error),
                  ),
                ),
              ),
            );
            return;
          default:
            return;
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_scan_failed(e: e)),
          ),
        );
      }
    }

    Future<void> addLocalLibrary() async {
      final result = await LocalModeSetupScreen.show(
        context,
        title: context.t.strings.legacy.msg_add_local_library,
        confirmLabel: context.t.strings.legacy.msg_confirm,
        cancelLabel: context.t.strings.legacy.msg_cancel_2,
        initialName: context.t.strings.legacy.msg_local_library,
      );
      if (result == null) return;
      var key = 'local_${generateUid(length: 12)}';
      while (localLibraries.any((library) => library.key == key)) {
        key = 'local_${generateUid(length: 12)}';
      }
      await ensureManagedWorkspaceStructure(key);
      final rootPath = await resolveManagedWorkspacePath(key);
      final existed = localLibraries.any((l) => l.key == key);
      if (!existed) {
        try {
          await ref
              .read(accountSecurityControllerProvider)
              .deleteDatabaseForWorkspaceKey(key);
        } catch (_) {}
      }
      final now = DateTime.now();
      final library = LocalLibrary(
        key: key,
        name: result.name.trim(),
        storageKind: LocalLibraryStorageKind.managedPrivate,
        rootPath: rootPath,
        createdAt: now,
        updatedAt: now,
      );
      ref.read(localLibrariesProvider.notifier).upsert(library);
      await ref.read(appSessionProvider.notifier).switchWorkspace(key);
      if (!context.mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_local_library_added);
    }

    Future<void> renameLocalLibrary(LocalLibrary library) async {
      final result = await LocalModeSetupScreen.show(
        context,
        title: context.t.strings.legacy.msg_local_library_name,
        confirmLabel: context.t.strings.legacy.msg_confirm,
        cancelLabel: context.t.strings.legacy.msg_cancel_2,
        initialName: library.name.isNotEmpty
            ? library.name
            : context.t.strings.legacy.msg_local_library,
        subtitle: library.locationLabel,
        showStorageInfoCard: false,
      );
      if (result == null) return;
      final nextName = result.name.trim();
      final currentName = library.name.trim();
      if (nextName.isEmpty || nextName == currentName) return;
      ref
          .read(localLibrariesProvider.notifier)
          .upsert(library.copyWith(name: nextName));
      if (!context.mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_saved_2);
    }

    Future<void> removeLocalLibrary(LocalLibrary library) async {
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
      await ref
          .read(accountSecurityControllerProvider)
          .deleteDatabaseForWorkspaceKey(library.key);

      if (shouldReopenOnboarding) {
        ref
            .read(devicePreferencesProvider.notifier)
            .setHasSelectedLanguage(false);
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

      if (shouldReopenOnboarding) {
        ref
            .read(devicePreferencesProvider.notifier)
            .setHasSelectedLanguage(false);
        await requestMainWindowReopenOnboardingIfSupported();
      }
      try {
        await sessionNotifier.removeAccount(accountKey);
        await ref
            .read(accountSecurityControllerProvider)
            .deleteDatabaseForWorkspaceKey(accountKey);
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

    return SettingsPage(
      showBackButton: showBackButton,
      title: Text(context.t.strings.legacy.msg_account_security),
      children: [
        SettingsSection(
          children: [
            SettingsProfileSummary(
              icon: currentLocalLibrary == null
                  ? Icons.person
                  : Icons.folder_open,
              title: currentName,
              subtitle: currentSubtitle,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          children: [
            SettingsNavigationRow(
              leading: Icon(
                Icons.person_add,
                size: 20,
                color: tokens.textMuted,
              ),
              label: context.t.strings.legacy.msg_add_account,
              onTap: () {
                haptic();
                Navigator.of(context).push(
                  buildPlatformPageRoute<void>(
                    context: context,
                    builder: (_) => const LoginScreen(),
                  ),
                );
              },
            ),
            SettingsNavigationRow(
              leading: Icon(
                Icons.folder_open,
                size: 20,
                color: tokens.textMuted,
              ),
              label: context.t.strings.legacy.msg_add_local_library,
              onTap: () async {
                haptic();
                await addLocalLibrary();
              },
            ),
            SettingsNavigationRow(
              leading: Icon(
                Icons.settings_outlined,
                size: 20,
                color: tokens.textMuted,
              ),
              label: context.t.strings.legacy.msg_user_general_settings,
              onTap: () {
                haptic();
                Navigator.of(context).push(
                  buildPlatformPageRoute<void>(
                    context: context,
                    builder: (_) => const UserGeneralSettingsScreen(),
                  ),
                );
              },
            ),
            if (currentAccount != null && currentLocalLibrary == null)
              SettingsNavigationRow(
                leading: Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 20,
                  color: tokens.textMuted,
                ),
                label: context.tr(
                  zh: '\u670D\u52A1\u5668\u8BBE\u7F6E',
                  en: 'Server Settings',
                ),
                onTap: () {
                  haptic();
                  Navigator.of(context).push(
                    buildPlatformPageRoute<void>(
                      context: context,
                      builder: (_) => const ServerSettingsScreen(),
                    ),
                  );
                },
              ),
            if (currentKey != null)
              SettingsNavigationRow(
                leading: Icon(Icons.logout, size: 20, color: tokens.textMuted),
                label: context.t.strings.legacy.msg_sign_2,
                trailingIcon: Icons.logout,
                onTap: () async {
                  haptic();
                  await removeAccountAndClearCache(currentKey);
                },
              ),
          ],
        ),
        if (accounts.isNotEmpty) ...[
          const SizedBox(height: 12),
          SettingsSection(
            header: Text(context.t.strings.legacy.msg_accounts),
            children: [
              for (final account in accounts)
                SettingsSelectableItemRow(
                  selected: account.key == currentKey,
                  title: account.user.displayName.isNotEmpty
                      ? account.user.displayName
                      : (account.user.name.isNotEmpty
                            ? account.user.name
                            : account.key),
                  subtitle: account.baseUrl.toString(),
                  deleteTooltip: context.t.strings.legacy.msg_remove,
                  onTap: () {
                    haptic();
                    ref
                        .read(appSessionProvider.notifier)
                        .switchAccount(account.key);
                  },
                  onDelete: () async {
                    haptic();
                    await removeAccountAndClearCache(account.key);
                  },
                ),
            ],
          ),
        ],
        if (localLibraries.isNotEmpty) ...[
          const SizedBox(height: 12),
          SettingsSection(
            header: Text(context.t.strings.legacy.msg_local_libraries),
            children: [
              for (final library in localLibraries)
                SettingsSelectableItemRow(
                  selected: library.key == currentKey,
                  title: library.name.isNotEmpty
                      ? library.name
                      : context.t.strings.legacy.msg_local_library,
                  subtitle: library.locationLabel,
                  editTooltip: context.t.strings.legacy.msg_edit,
                  deleteTooltip: context.t.strings.legacy.msg_remove,
                  onTap: () async {
                    haptic();
                    await ref
                        .read(appSessionProvider.notifier)
                        .switchWorkspace(library.key);
                    if (!context.mounted) return;
                    await WidgetsBinding.instance.endOfFrame;
                    if (!context.mounted) return;
                    await maybeScanLocalLibrary();
                  },
                  onEdit: () async {
                    haptic();
                    await renameLocalLibrary(library);
                  },
                  onDelete: () async {
                    haptic();
                    await removeLocalLibrary(library);
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        SettingsSection(
          children: [
            SettingsInfoRow(
              description: context
                  .t
                  .strings
                  .legacy
                  .msg_removing_signing_clear_local_cache_account,
            ),
          ],
        ),
      ],
    );
  }
}
