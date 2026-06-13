// ignore_for_file: use_build_context_synchronously, unused_element

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/sync/sync_coordinator_provider.dart';
import '../../application/sync/sync_error.dart';
import '../../application/sync/sync_request.dart';
import '../../application/sync/sync_types.dart';
import '../../application/sync/webdav_backup_service.dart';
import '../../application/sync/webdav_sync_service.dart';
import '../../core/app_localization.dart';
import '../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../core/log_sanitizer.dart';
import '../../core/sync_error_presenter.dart';
import '../../core/top_toast.dart';
import '../../core/uid.dart';
import '../../data/logs/debug_log_store.dart';
import '../../data/logs/webdav_backup_progress_tracker.dart';
import '../../data/local_library/local_library_paths.dart';
import '../../data/models/local_library.dart';
import '../../core/webdav_url.dart';
import '../../data/models/webdav_backup.dart';
import '../../data/models/webdav_export_status.dart';
import '../../data/models/webdav_settings.dart';
import '../../data/models/webdav_sync_meta.dart';
import '../../data/repositories/webdav_vault_state_repository.dart';
import '../../state/system/local_library_provider.dart';
import '../../state/system/session_provider.dart';
import '../../state/webdav/webdav_backup_provider.dart';
import '../../state/webdav/webdav_log_provider.dart';
import '../../state/webdav/webdav_settings_provider.dart';
import '../../state/webdav/webdav_vault_provider.dart';
import '../../platform/platform_icons.dart';
import '../../platform/platform_route.dart';
import '../../platform/widgets/platform_controls.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../platform/widgets/platform_list_section.dart';
import '../../platform/widgets/platform_list_tile.dart';
import '../../platform/widgets/platform_page.dart';
import '../../platform/widgets/platform_primary_action.dart';
import '../../i18n/strings.g.dart';
import 'settings_ui.dart';
part 'vault_security_status_screen.dart';

class WebDavSyncScreen extends ConsumerStatefulWidget {
  const WebDavSyncScreen({super.key});

  @override
  ConsumerState<WebDavSyncScreen> createState() => _WebDavSyncScreenState();
}

class _WebDavSyncScreenState extends ConsumerState<WebDavSyncScreen> {
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rootPathController = TextEditingController();
  final _backupRetentionController = TextEditingController();
  ProviderSubscription<WebDavSettings>? _settingsSubscription;

  var _authMode = WebDavAuthMode.basic;
  var _ignoreTlsErrors = false;
  var _enabled = false;
  var _backupSchedule = WebDavBackupSchedule.daily;
  var _backupConfigScope = WebDavBackupConfigScope.safe;
  var _backupContentMemos = true;
  var _backupEncryptionMode = WebDavBackupEncryptionMode.encrypted;
  var _rememberBackupPassword = true;
  var _backupPasswordSet = false;
  var _vaultEnabled = false;
  var _rememberVaultPassword = true;
  var _dirty = false;
  var _backupRestoring = false;
  @override
  void initState() {
    super.initState();
    final settings = ref.read(webDavSettingsProvider);
    _applySettings(settings);
    _refreshBackupPasswordStatus();
    _settingsSubscription = ref.listenManual<WebDavSettings>(
      webDavSettingsProvider,
      (prev, next) {
        if (_dirty || !mounted) return;
        _applySettings(next);
      },
    );
  }

  @override
  void dispose() {
    _settingsSubscription?.close();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootPathController.dispose();
    _backupRetentionController.dispose();
    super.dispose();
  }

  void _applySettings(WebDavSettings settings) {
    _enabled = settings.enabled;
    _authMode = settings.authMode;
    _ignoreTlsErrors = settings.ignoreTlsErrors;
    _serverUrlController.text = settings.serverUrl;
    _usernameController.text = settings.username;
    _passwordController.text = settings.password;
    _rootPathController.text = settings.rootPath;
    _backupConfigScope = settings.backupConfigScope;
    _backupContentMemos = settings.backupContentMemos;
    _backupEncryptionMode = settings.backupEncryptionMode;
    _backupSchedule = settings.backupSchedule;
    _backupRetentionController.text = settings.backupRetentionCount.toString();
    _rememberBackupPassword = settings.rememberBackupPassword;
    _vaultEnabled = settings.vaultEnabled;
    _rememberVaultPassword = settings.rememberVaultPassword;
    setState(() {});
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  Future<void> _selectAuthMode(BuildContext sheetContext) async {
    final selected = await showSettingsSingleChoicePicker<WebDavAuthMode>(
      context: sheetContext,
      title: sheetContext.t.strings.legacy.msg_auth_mode,
      value: _authMode,
      options: _authModeOptions(sheetContext),
    );
    if (!mounted || selected == null) return;
    setState(() => _authMode = selected);
    _markDirty();
    ref.read(webDavSettingsProvider.notifier).setAuthMode(selected);
  }

  Future<void> _selectBackupSchedule(BuildContext sheetContext) async {
    final selected = await showSettingsSingleChoicePicker<WebDavBackupSchedule>(
      context: sheetContext,
      title: sheetContext.t.strings.legacy.msg_backup_schedule,
      value: _backupSchedule,
      options: _backupScheduleOptions(sheetContext),
    );
    if (!mounted || selected == null) return;
    setState(() => _backupSchedule = selected);
    _markDirty();
    ref.read(webDavSettingsProvider.notifier).setBackupSchedule(selected);
  }

  List<SettingsChoiceOption<WebDavAuthMode>> _authModeOptions(
    BuildContext context,
  ) {
    return const [
      SettingsChoiceOption<WebDavAuthMode>(
        value: WebDavAuthMode.basic,
        label: 'Basic',
      ),
      SettingsChoiceOption<WebDavAuthMode>(
        value: WebDavAuthMode.digest,
        label: 'Digest',
      ),
    ];
  }

  List<SettingsChoiceOption<WebDavBackupSchedule>> _backupScheduleOptions(
    BuildContext context,
  ) {
    return [
      SettingsChoiceOption<WebDavBackupSchedule>(
        value: WebDavBackupSchedule.manual,
        label: context.t.strings.legacy.msg_manual,
      ),
      SettingsChoiceOption<WebDavBackupSchedule>(
        value: WebDavBackupSchedule.daily,
        label: context.t.strings.legacy.msg_daily,
      ),
      SettingsChoiceOption<WebDavBackupSchedule>(
        value: WebDavBackupSchedule.weekly,
        label: context.t.strings.legacy.msg_weekly,
      ),
      SettingsChoiceOption<WebDavBackupSchedule>(
        value: WebDavBackupSchedule.monthly,
        label: context.tr(zh: '每月', en: 'Monthly'),
      ),
      SettingsChoiceOption<WebDavBackupSchedule>(
        value: WebDavBackupSchedule.onOpen,
        label: context.tr(zh: '每次打开', en: 'On app open'),
      ),
    ];
  }

  void _setEnabled(bool value) {
    setState(() => _enabled = value);
    final notifier = ref.read(webDavSettingsProvider.notifier);
    notifier.setEnabled(value);
    notifier.setBackupEnabled(value);
  }

  void _setAuthMode(WebDavAuthMode mode) {
    setState(() => _authMode = mode);
    _markDirty();
    ref.read(webDavSettingsProvider.notifier).setAuthMode(mode);
  }

  void _setIgnoreTlsErrors(bool value) {
    setState(() => _ignoreTlsErrors = value);
    _markDirty();
    ref.read(webDavSettingsProvider.notifier).setIgnoreTlsErrors(value);
  }

  void _setBackupSchedule(WebDavBackupSchedule schedule) {
    setState(() => _backupSchedule = schedule);
    _markDirty();
    ref.read(webDavSettingsProvider.notifier).setBackupSchedule(schedule);
  }

  void _setBackupConfigScope(WebDavBackupConfigScope scope) {
    setState(() => _backupConfigScope = scope);
    ref.read(webDavSettingsProvider.notifier).setBackupConfigScope(scope);
  }

  void _setBackupContentMemos(bool value) {
    setState(() => _backupContentMemos = value);
    ref.read(webDavSettingsProvider.notifier).setBackupContentMemos(value);
  }

  void _setBackupEncryptionMode(WebDavBackupEncryptionMode mode) {
    setState(() => _backupEncryptionMode = mode);
    ref.read(webDavSettingsProvider.notifier).setBackupEncryptionMode(mode);
  }

  void _setBackupRetention(String value) {
    _markDirty();
    final parsed = int.tryParse(value.trim());
    if (parsed != null) {
      ref.read(webDavSettingsProvider.notifier).setBackupRetentionCount(parsed);
    }
  }

  Future<void> _refreshBackupPasswordStatus() async {
    if (_vaultEnabled) {
      if (!mounted) return;
      setState(() => _backupPasswordSet = true);
      return;
    }
    final stored = await ref
        .read(webDavBackupPasswordRepositoryProvider)
        .read();
    if (!mounted) return;
    setState(() {
      _backupPasswordSet = stored != null && stored.trim().isNotEmpty;
    });
  }

  Future<void> _openConnectionSettings() async {
    await Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => _WebDavConnectionScreen(
          serverUrlController: _serverUrlController,
          usernameController: _usernameController,
          passwordController: _passwordController,
          rootPathController: _rootPathController,
          authMode: _authMode,
          ignoreTlsErrors: _ignoreTlsErrors,
          onAuthModeChanged: _setAuthMode,
          onIgnoreTlsChanged: _setIgnoreTlsErrors,
          onServerUrlChanged: (v) {
            _markDirty();
            ref.read(webDavSettingsProvider.notifier).setServerUrl(v);
          },
          onUsernameChanged: (v) {
            _markDirty();
            ref.read(webDavSettingsProvider.notifier).setUsername(v);
          },
          onPasswordChanged: (v) {
            _markDirty();
            ref.read(webDavSettingsProvider.notifier).setPassword(v);
          },
          onRootPathChanged: (v) {
            _markDirty();
            ref.read(webDavSettingsProvider.notifier).setRootPath(v);
          },
          onServerUrlEditingComplete: _normalizeServerUrl,
          onRootPathEditingComplete: _normalizeRootPath,
        ),
      ),
    );
  }

  Future<void> _openBackupSettings() async {
    final session = ref.read(appSessionProvider).valueOrNull;
    final localLibrary = ref.read(currentLocalLibraryProvider);
    final usesServerMode = session?.currentAccount != null;
    final backupAvailable = usesServerMode ? true : localLibrary != null;
    final backupUnavailableHint =
        context.t.strings.legacy.msg_local_library_only;
    await Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => _WebDavBackupSettingsScreen(
          backupAvailable: backupAvailable,
          backupUnavailableHint: backupUnavailableHint,
          usesServerMode: usesServerMode,
          backupRestoring: _backupRestoring,
          backupConfigScope: _backupConfigScope,
          backupContentMemos: _backupContentMemos,
          backupEncryptionMode: _backupEncryptionMode,
          backupPasswordSet: _backupPasswordSet,
          vaultEnabled: _vaultEnabled,
          backupSchedule: _backupSchedule,
          backupRetentionController: _backupRetentionController,
          onBackupConfigScopeChanged: _setBackupConfigScope,
          onBackupContentMemosChanged: _setBackupContentMemos,
          onBackupEncryptionModeChanged: _setBackupEncryptionMode,
          onBackupScheduleChanged: _setBackupSchedule,
          onBackupRetentionChanged: _setBackupRetention,
          onSetupBackupPassword: _setupBackupPassword,
        ),
      ),
    );
  }

  Future<String?> _promptBackupPassword({
    required bool confirm,
    String? title,
    String? hint,
  }) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final resolvedTitle =
        title ??
        (_vaultEnabled
            ? context.tr(zh: 'Vault 密码', en: 'Vault password')
            : context.t.strings.legacy.msg_backup_password);
    final resolvedHint =
        hint ??
        (_vaultEnabled
            ? context.tr(zh: '请输入 Vault 密码', en: 'Enter Vault password')
            : context.t.strings.legacy.msg_enter_backup_password);
    try {
      final confirmed =
          await showPlatformDialog<bool>(
            context: context,
            builder: (dialogContext) => SettingsFormDialog(
              title: Text(resolvedTitle),
              actions: [
                SettingsDialogAction(
                  onPressed: () {
                    FocusScope.of(dialogContext).unfocus();
                    dialogContext.safePop(false);
                  },
                  label: Text(context.t.strings.legacy.msg_cancel_2),
                ),
                SettingsDialogAction(
                  onPressed: () {
                    FocusScope.of(dialogContext).unfocus();
                    dialogContext.safePop(true);
                  },
                  label: Text(context.t.strings.legacy.msg_confirm),
                  variant: PlatformPrimaryActionVariant.filled,
                ),
              ],
              children: [
                SettingsDialogTextField(
                  label: _vaultEnabled
                      ? context.tr(zh: 'Vault 密码', en: 'Vault password')
                      : context.t.strings.legacy.msg_backup_password,
                  controller: passwordController,
                  hint: resolvedHint,
                  obscureText: true,
                  textInputAction: confirm
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onSubmitted: (_) {
                    if (!confirm) {
                      FocusScope.of(dialogContext).unfocus();
                      dialogContext.safePop(true);
                    } else {
                      FocusScope.of(dialogContext).nextFocus();
                    }
                  },
                ),
                if (confirm) ...[
                  const SizedBox(height: 12),
                  SettingsDialogTextField(
                    label: context.t.strings.legacy.msg_confirm_password_2,
                    controller: confirmController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      FocusScope.of(dialogContext).unfocus();
                      dialogContext.safePop(true);
                    },
                  ),
                ],
              ],
            ),
          ) ??
          false;

      final password = passwordController.text.trim();
      final confirmPassword = confirmController.text.trim();

      if (!confirmed) return null;
      if (password.isEmpty) return null;
      if (confirm && password != confirmPassword) {
        if (!mounted) return null;
        showTopToast(context, context.t.strings.legacy.msg_passwords_not_match);
        return null;
      }
      return password;
    } finally {
      passwordController.dispose();
      confirmController.dispose();
    }
  }

  Future<bool> _setupBackupPassword() async {
    if (!_vaultEnabled) {
      final enabled = await _setupVaultPasswordFlow();
      if (!mounted || !enabled) return false;
      setState(() => _vaultEnabled = true);
      ref.read(webDavSettingsProvider.notifier).setVaultEnabled(true);
      _refreshBackupPasswordStatus();
      return true;
    }
    final enabled = await _setupVaultPasswordFlow();
    if (!mounted || !enabled) return false;
    _refreshBackupPasswordStatus();
    return true;
  }

  Future<bool> _setupVaultPasswordFlow() async {
    final settings = ref.read(webDavSettingsProvider);
    final accountKey = ref.read(appSessionProvider).valueOrNull?.currentKey;
    if (accountKey == null || accountKey.trim().isEmpty) {
      if (mounted) {
        showTopToast(context, context.t.strings.legacy.msg_not_signed);
      }
      return false;
    }
    final vaultService = ref.read(webDavVaultServiceProvider);
    final vaultPasswordRepo = ref.read(webDavVaultPasswordRepositoryProvider);
    final vaultRecoveryRepo = ref.read(webDavVaultRecoveryRepositoryProvider);
    final vaultStateRepo = ref.read(webDavVaultStateRepositoryProvider);

    try {
      final existingConfig = await vaultService.loadConfig(
        settings: settings,
        accountKey: accountKey,
      );
      if (existingConfig != null) {
        final action = await _promptExistingVaultAction();
        if (!mounted || action == null) return false;
        if (action == _VaultExistingAction.recover) {
          return await _recoverVaultPassword();
        }
        final vaultPassword = await _promptBackupPassword(
          confirm: false,
          title: context.tr(zh: 'Vault 密码', en: 'Vault password'),
          hint: context.tr(zh: '请输入 Vault 密码', en: 'Enter Vault password'),
        );
        if (!mounted || vaultPassword == null || vaultPassword.trim().isEmpty) {
          return false;
        }
        await vaultService.resolveMasterKey(vaultPassword, existingConfig);
        if (_rememberVaultPassword) {
          await vaultPasswordRepo.write(vaultPassword);
        } else {
          await vaultPasswordRepo.clear();
        }
        if (!_rememberVaultPassword) {
          setState(() => _rememberVaultPassword = true);
          ref
              .read(webDavSettingsProvider.notifier)
              .setRememberVaultPassword(true);
        }
        setState(() => _backupPasswordSet = true);
        return true;
      }
    } catch (e) {
      if (!mounted) return false;
      final message = _formatBackupError(e);
      showTopToast(context, message);
      return false;
    }

    List<int>? masterKeyOverride;
    String? vaultPassword;
    try {
      final legacyConfig = await vaultService.loadLegacyBackupConfig(
        settings: settings,
        accountKey: accountKey,
      );
      if (legacyConfig != null) {
        final legacyPassword = await _promptBackupPassword(
          confirm: false,
          title: context.tr(zh: '旧备份密码', en: 'Legacy backup password'),
          hint: context.tr(zh: '请输入旧备份密码', en: 'Enter legacy backup password'),
        );
        if (!mounted || legacyPassword == null) return false;
        final masterKey = await vaultService.resolveLegacyMasterKey(
          password: legacyPassword,
          config: legacyConfig,
        );
        masterKeyOverride = await masterKey.extractBytes();
        vaultPassword = legacyPassword;
      } else {
        vaultPassword = await _promptBackupPassword(
          confirm: true,
          title: context.tr(zh: 'Vault 密码', en: 'Vault password'),
          hint: context.tr(zh: '请输入 Vault 密码', en: 'Enter Vault password'),
        );
      }
    } catch (e) {
      if (!mounted) return false;
      final message = _formatBackupError(e);
      showTopToast(context, message);
      return false;
    }

    if (!mounted || vaultPassword == null || vaultPassword.trim().isEmpty) {
      return false;
    }

    String recoveryCode;
    try {
      recoveryCode = await vaultService.setupVault(
        settings: settings,
        accountKey: accountKey,
        password: vaultPassword,
        masterKeyOverride: masterKeyOverride,
      );
    } catch (e) {
      if (!mounted) return false;
      final message = _formatBackupError(e);
      showTopToast(context, message);
      return false;
    }

    final confirmed = await _confirmVaultRecoveryCode(recoveryCode);
    if (!mounted || !confirmed) return false;
    await vaultRecoveryRepo.write(recoveryCode);
    await vaultStateRepo.write(const WebDavVaultState(recoveryVerified: true));
    if (_rememberVaultPassword) {
      await vaultPasswordRepo.write(vaultPassword);
    } else {
      await vaultPasswordRepo.clear();
    }
    if (!_rememberVaultPassword) {
      setState(() => _rememberVaultPassword = true);
      ref.read(webDavSettingsProvider.notifier).setRememberVaultPassword(true);
    }
    setState(() => _backupPasswordSet = true);
    return true;
  }

  Future<_VaultExistingAction?> _promptExistingVaultAction() async {
    return showSettingsSingleChoicePicker<_VaultExistingAction>(
      context: context,
      title: context.tr(zh: '检测到已有 Vault', en: 'Existing Vault detected'),
      value: null,
      options: [
        SettingsChoiceOption<_VaultExistingAction>(
          value: _VaultExistingAction.verify,
          label: context.tr(zh: '验证 Vault 密码', en: 'Verify Vault password'),
          description: context.tr(
            zh: '使用已有密码解锁',
            en: 'Use existing password to unlock',
          ),
        ),
        SettingsChoiceOption<_VaultExistingAction>(
          value: _VaultExistingAction.recover,
          label: context.tr(zh: '使用恢复码', en: 'Use recovery code'),
          description: context.tr(
            zh: '通过恢复码重置密码',
            en: 'Reset password using recovery code',
          ),
        ),
      ],
    );
  }

  Future<bool> _confirmVaultRecoveryCode(String code) async {
    var copied = false;
    var saved = false;
    final confirmed =
        await showPlatformDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (context, setState) {
                final canContinue = copied && saved;
                return SettingsFormDialog(
                  title: Text(
                    context.tr(zh: 'Vault 恢复码', en: 'Vault recovery code'),
                  ),
                  actions: [
                    SettingsDialogAction(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (!dialogContext.mounted) return;
                        setState(() => copied = true);
                        showTopToast(
                          dialogContext,
                          context.tr(zh: '恢复码已复制', en: 'Recovery code copied'),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: Text(context.t.strings.legacy.msg_copy),
                    ),
                    SettingsDialogAction(
                      onPressed: canContinue
                          ? () => dialogContext.safePop(true)
                          : null,
                      label: Text(context.t.strings.legacy.msg_continue),
                      variant: PlatformPrimaryActionVariant.filled,
                    ),
                  ],
                  children: [
                    Text(
                      context.tr(
                        zh: '请复制并保存恢复码。丢失密码时只能用恢复码找回。',
                        en: 'Copy and save the recovery code. It is required if you lose the password.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      code,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SettingsMultiChoiceRow<String>(
                      option: SettingsChoiceOption<String>(
                        value: 'saved',
                        label: context.tr(
                          zh: '我已保存恢复码',
                          en: 'I have saved the recovery code',
                        ),
                      ),
                      selected: saved,
                      onChanged: (value) {
                        setState(() => saved = value);
                      },
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
    return confirmed;
  }

  Future<String?> _resolveBackupPassword({required bool confirm}) async {
    if (_vaultEnabled) {
      final repo = ref.read(webDavVaultPasswordRepositoryProvider);
      final stored = await repo.read();
      if (stored != null && stored.trim().isNotEmpty) {
        if (mounted && !_backupPasswordSet) {
          setState(() => _backupPasswordSet = true);
        }
        return stored;
      }
      final entered = await _promptBackupPassword(confirm: confirm);
      if (entered == null || entered.trim().isEmpty) return null;
      if (_rememberVaultPassword) {
        await repo.write(entered);
      }
      if (!_rememberVaultPassword) {
        if (mounted) {
          setState(() => _rememberVaultPassword = true);
        }
        ref
            .read(webDavSettingsProvider.notifier)
            .setRememberVaultPassword(true);
        await repo.write(entered);
      }
      if (mounted) {
        setState(() => _backupPasswordSet = true);
      }
      return entered;
    }

    final repo = ref.read(webDavBackupPasswordRepositoryProvider);
    final stored = await repo.read();
    if (stored != null && stored.trim().isNotEmpty) {
      if (mounted && !_backupPasswordSet) {
        setState(() => _backupPasswordSet = true);
      }
      return stored;
    }
    final entered = await _promptBackupPassword(confirm: confirm);
    if (entered == null || entered.trim().isNotEmpty == false) return null;
    await repo.write(entered);
    if (!_rememberBackupPassword) {
      if (mounted) {
        setState(() => _rememberBackupPassword = true);
      }
      ref.read(webDavSettingsProvider.notifier).setRememberBackupPassword(true);
    }
    if (mounted) {
      setState(() => _backupPasswordSet = true);
    }
    return entered;
  }

  Future<bool> _verifyBackupPassword(String password) async {
    try {
      final settings = ref.read(webDavSettingsProvider);
      final accountKey = ref.read(appSessionProvider).valueOrNull?.currentKey;
      await ref
          .read(desktopSyncFacadeProvider)
          .listWebDavBackupSnapshots(
            settings: settings,
            accountKey: accountKey,
            password: password,
          );
      return true;
    } catch (e) {
      if (!mounted) return false;
      final message = _formatBackupError(e);
      showTopToast(context, message);
      return false;
    }
  }

  Future<({String recoveryCode, String password})?> _promptRecoveryReset({
    String? title,
  }) async {
    final recoveryController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    try {
      final confirmed =
          await showPlatformDialog<bool>(
            context: context,
            builder: (dialogContext) => SettingsFormDialog(
              title: Text(
                title ?? context.t.strings.legacy.webdav.recover_password_title,
              ),
              actions: [
                SettingsDialogAction(
                  onPressed: () => dialogContext.safePop(false),
                  label: Text(context.t.strings.legacy.msg_cancel_2),
                ),
                SettingsDialogAction(
                  onPressed: () => dialogContext.safePop(true),
                  label: Text(context.t.strings.legacy.msg_confirm),
                  variant: PlatformPrimaryActionVariant.filled,
                ),
              ],
              children: [
                SettingsDialogTextField(
                  label: context.t.strings.legacy.webdav.recovery_code_title,
                  controller: recoveryController,
                  hint: context.t.strings.legacy.webdav.recovery_code_enter,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(dialogContext).nextFocus(),
                ),
                const SizedBox(height: 12),
                SettingsDialogTextField(
                  label: context
                      .t
                      .strings
                      .legacy
                      .webdav
                      .recovery_code_enter_new_password,
                  controller: passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(dialogContext).nextFocus(),
                ),
                const SizedBox(height: 12),
                SettingsDialogTextField(
                  label: context.t.strings.legacy.msg_confirm_password_2,
                  controller: confirmController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    FocusScope.of(dialogContext).unfocus();
                    dialogContext.safePop(true);
                  },
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return null;
      final recoveryCode = recoveryController.text.trim();
      final password = passwordController.text.trim();
      final confirmPassword = confirmController.text.trim();
      if (recoveryCode.isEmpty || password.isEmpty) return null;
      if (password != confirmPassword) {
        if (!mounted) return null;
        showTopToast(context, context.t.strings.legacy.msg_passwords_not_match);
        return null;
      }
      return (recoveryCode: recoveryCode, password: password);
    } finally {
      recoveryController.dispose();
      passwordController.dispose();
      confirmController.dispose();
    }
  }

  Future<void> _showRecoveryCodeDialog(
    String code, {
    required bool reset,
    required String message,
  }) async {
    await showPlatformDialog<void>(
      context: context,
      builder: (dialogContext) => SettingsFormDialog(
        title: Text(context.t.strings.legacy.webdav.recovery_code_title),
        actions: [
          SettingsDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!dialogContext.mounted) return;
              showTopToast(
                dialogContext,
                context.t.strings.legacy.webdav.recovery_code_copied,
              );
            },
            icon: const Icon(Icons.copy),
            label: Text(context.t.strings.legacy.msg_copy),
            variant: PlatformPrimaryActionVariant.filled,
          ),
          SettingsDialogAction(
            onPressed: () => dialogContext.safePop(),
            label: Text(
              reset
                  ? context.t.strings.legacy.msg_saved_2
                  : context.t.strings.legacy.msg_ok,
            ),
          ),
        ],
        children: [
          Text(message),
          const SizedBox(height: 12),
          SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recoverBackupPassword() async {
    if (_vaultEnabled) {
      await _recoverVaultPassword();
      return;
    }
    final payload = await _promptRecoveryReset();
    if (!mounted || payload == null) return;
    final newPassword = payload.password;
    final recoveryCode = payload.recoveryCode;
    try {
      final settings = ref.read(webDavSettingsProvider);
      final accountKey = ref.read(appSessionProvider).valueOrNull?.currentKey;
      final newRecoveryCode = await ref
          .read(desktopSyncFacadeProvider)
          .recoverWebDavBackupPassword(
            settings: settings,
            accountKey: accountKey,
            recoveryCode: recoveryCode,
            newPassword: newPassword,
          );
      await ref.read(webDavBackupPasswordRepositoryProvider).write(newPassword);
      if (!_rememberBackupPassword) {
        setState(() => _rememberBackupPassword = true);
        ref
            .read(webDavSettingsProvider.notifier)
            .setRememberBackupPassword(true);
      }
      if (mounted) {
        setState(() => _backupPasswordSet = true);
      }
      if (!mounted) return;
      await _showRecoveryCodeDialog(
        newRecoveryCode,
        reset: true,
        message: context.t.strings.legacy.webdav.recovery_code_reset_message,
      );
      if (!mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.webdav.recovery_reset_success,
      );
    } catch (e) {
      if (!mounted) return;
      final message = _formatBackupError(e);
      showTopToast(context, message);
    }
  }

  Future<bool> _recoverVaultPassword() async {
    final payload = await _promptRecoveryReset(
      title: context.tr(zh: '找回 Vault 密码', en: 'Recover Vault password'),
    );
    if (!mounted || payload == null) return false;
    final newPassword = payload.password;
    final recoveryCode = payload.recoveryCode;
    try {
      final settings = ref.read(webDavSettingsProvider);
      final accountKey = ref.read(appSessionProvider).valueOrNull?.currentKey;
      final service = ref.read(webDavVaultServiceProvider);
      final newRecoveryCode = await service.recoverVaultPassword(
        settings: settings,
        accountKey: accountKey,
        recoveryCode: recoveryCode,
        newPassword: newPassword,
      );
      await ref.read(webDavVaultPasswordRepositoryProvider).write(newPassword);
      if (!_rememberVaultPassword) {
        setState(() => _rememberVaultPassword = true);
        ref
            .read(webDavSettingsProvider.notifier)
            .setRememberVaultPassword(true);
      }
      if (mounted) {
        setState(() => _backupPasswordSet = true);
      }
      if (!mounted) return false;
      final confirmed = await _confirmVaultRecoveryCode(newRecoveryCode);
      if (!mounted || !confirmed) return false;
      await ref
          .read(webDavVaultRecoveryRepositoryProvider)
          .write(newRecoveryCode);
      await ref
          .read(webDavVaultStateRepositoryProvider)
          .write(const WebDavVaultState(recoveryVerified: true));
      if (!mounted) return false;
      showTopToast(
        context,
        context.tr(zh: 'Vault 密码已重置', en: 'Vault password reset'),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      final message = _formatBackupError(e);
      showTopToast(context, message);
      return false;
    }
  }

  Future<void> _backupNow() async {
    final coordinator = ref.read(desktopSyncFacadeProvider);
    final settingsNotifier = ref.read(webDavSettingsProvider.notifier);
    if (_backupConfigScope != WebDavBackupConfigScope.none ||
        _backupContentMemos) {
      settingsNotifier.setBackupEnabled(true);
    }
    if (_backupEncryptionMode == WebDavBackupEncryptionMode.plain) {
      settingsNotifier.setAutoSyncAllowed(true);
      await coordinator.requestWebDavBackup(
        reason: SyncRequestReason.manual,
        password: null,
        onExportIssue: _promptBackupExportIssue,
      );
      return;
    }
    final password = await _resolveBackupPassword(confirm: false);
    if (!mounted || password == null) return;
    settingsNotifier.setAutoSyncAllowed(true);
    await coordinator.requestWebDavBackup(
      reason: SyncRequestReason.manual,
      password: password,
      onExportIssue: _promptBackupExportIssue,
    );
  }

  Future<WebDavBackupExportResolution> _promptBackupExportIssue(
    WebDavBackupExportIssue issue,
  ) async {
    var applyToRemaining = false;
    final kindLabel = issue.kind == WebDavBackupExportIssueKind.memo
        ? context.t.strings.legacy.msg_memo
        : context.t.strings.legacy.msg_attachments;
    final targetLabel = issue.kind == WebDavBackupExportIssueKind.memo
        ? issue.memoUid
        : '${issue.memoUid}/${issue.attachmentFilename ?? ''}';
    final errorText = _formatBackupError(issue.error);
    final choice =
        await showPlatformDialog<
          ({WebDavBackupExportAction action, bool applyToRemaining})
        >(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (context, setState) {
                return SettingsFormDialog(
                  title: Text(context.t.strings.legacy.msg_backup_failed),
                  actions: [
                    SettingsDialogAction(
                      onPressed: () => dialogContext.safePop((
                        action: WebDavBackupExportAction.abort,
                        applyToRemaining: applyToRemaining,
                      )),
                      label: Text(context.t.strings.legacy.msg_cancel_2),
                    ),
                    SettingsDialogAction(
                      onPressed: () => dialogContext.safePop((
                        action: WebDavBackupExportAction.skip,
                        applyToRemaining: applyToRemaining,
                      )),
                      label: Text(context.t.strings.legacy.msg_continue),
                      variant: PlatformPrimaryActionVariant.outlined,
                    ),
                    SettingsDialogAction(
                      onPressed: () => dialogContext.safePop((
                        action: WebDavBackupExportAction.retry,
                        applyToRemaining: false,
                      )),
                      label: Text(context.t.strings.legacy.msg_retry),
                      variant: PlatformPrimaryActionVariant.filled,
                    ),
                  ],
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$kindLabel: $targetLabel'),
                        const SizedBox(height: 8),
                        Text(errorText),
                        const SizedBox(height: 12),
                        SettingsMultiChoiceRow<String>(
                          option: SettingsChoiceOption<String>(
                            value: 'apply',
                            label: context.tr(
                              zh: '对后续类似失败应用此操作',
                              en: 'Apply to subsequent similar failures',
                            ),
                          ),
                          selected: applyToRemaining,
                          onChanged: (value) {
                            setState(() => applyToRemaining = value);
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
    final action = choice?.action ?? WebDavBackupExportAction.abort;
    final apply =
        (choice?.applyToRemaining ?? false) &&
        action != WebDavBackupExportAction.retry;
    return WebDavBackupExportResolution(
      action: action,
      applyToRemainingFailures: apply,
    );
  }

  Future<void> _restoreBackup() async {
    final session = ref.read(appSessionProvider).valueOrNull;
    final localLibrary = ref.read(currentLocalLibraryProvider);
    final usesServerMode = session?.currentAccount != null;
    if (!usesServerMode && localLibrary == null) {
      if (!mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_local_library_only);
      return;
    }
    LocalLibrary? exportLibrary;
    String? exportPrefix;
    var createdManagedRestoreWorkspace = false;

    final settings = ref.read(webDavSettingsProvider);
    final accountKey = ref.read(appSessionProvider).valueOrNull?.currentKey;
    final coordinator = ref.read(desktopSyncFacadeProvider);

    if (mounted) {
      setState(() {
        _backupRestoring = true;
      });
    }

    Future<bool> handleResult(
      WebDavRestoreResult result,
      Future<WebDavRestoreResult> Function(Map<String, bool>? decisions) retry,
    ) async {
      if (!mounted) return false;
      switch (result) {
        case WebDavRestoreSuccess(:final missingAttachments, :final exportPath):
          if (createdManagedRestoreWorkspace && exportLibrary != null) {
            ref.read(localLibrariesProvider.notifier).upsert(exportLibrary);
            await ref
                .read(appSessionProvider.notifier)
                .switchWorkspace(exportLibrary.key);
          }
          final completedMessage = createdManagedRestoreWorkspace
              ? context.tr(
                  zh: '\u5df2\u5bfc\u5165\u5230\u672c\u5730\u5de5\u4f5c\u533a\uff1a${exportLibrary?.name ?? ''}',
                  en: 'Imported to local workspace: ${exportLibrary?.name ?? ''}',
                )
              : exportPath == null || exportPath.trim().isEmpty
              ? context.t.strings.legacy.msg_restore_completed
              : context.t.strings.legacy.msg_restore_completed_to_path(
                  path: exportPath,
                );
          showTopToast(context, completedMessage);
          if (missingAttachments > 0) {
            showTopToast(
              context,
              context.t.strings.legacy.msg_restore_missing_attachments(
                count: missingAttachments,
              ),
            );
          }
          return true;
        case WebDavRestoreSkipped(:final reason):
          final message = reason == null
              ? context.t.strings.legacy.msg_restore_failed(e: '')
              : _formatBackupError(reason);
          showTopToast(context, message);
          return false;
        case WebDavRestoreFailure(:final error):
          final message = _formatBackupError(error);
          showTopToast(context, message);
          return false;
        case WebDavRestoreConflict(:final conflicts):
          final decisions = await _resolveLocalScanConflicts(conflicts);
          if (!mounted) return false;
          final retried = await retry(decisions);
          return handleResult(retried, retry);
      }
    }

    try {
      if (usesServerMode) {
        final confirmed = await showSettingsConfirmationDialog(
          context: context,
          title: context.t.strings.legacy.msg_restore_backup,
          message: context.t.strings.legacy.msg_restore_export_only_notice,
          confirmLabel: context.t.strings.legacy.msg_confirm,
          cancelLabel: context.t.strings.legacy.msg_cancel_2,
        );
        if (!mounted || !confirmed) return;
        final target = await _createManagedRestoreWorkspace();
        if (!mounted || target == null) return;
        exportLibrary = target.library;
        exportPrefix = target.prefix;
        createdManagedRestoreWorkspace = true;
      }

      if (_backupEncryptionMode == WebDavBackupEncryptionMode.plain) {
        if (!usesServerMode) {
          final confirmed = await showSettingsConfirmationDialog(
            context: context,
            title: context.t.strings.legacy.msg_restore_backup,
            message: context
                .t
                .strings
                .legacy
                .msg_restoring_overwrite_local_library_files_rebuild,
            confirmLabel: context.t.strings.legacy.msg_confirm,
            cancelLabel: context.t.strings.legacy.msg_cancel_2,
            destructive: true,
          );
          if (!mounted || !confirmed) return;
          final result = await coordinator.restoreWebDavPlainBackup(
            settings: settings,
            accountKey: accountKey,
            activeLocalLibrary: localLibrary,
            onConfigRestorePrompt: _promptConfigRestoreDecision,
          );
          final success = await handleResult(
            result,
            (decisions) => coordinator.restoreWebDavPlainBackup(
              settings: settings,
              accountKey: accountKey,
              activeLocalLibrary: localLibrary,
              conflictDecisions: decisions,
              onConfigRestorePrompt: _promptConfigRestoreDecision,
            ),
          );
          if (!success && createdManagedRestoreWorkspace) {
            await _cleanupManagedRestoreWorkspace(exportLibrary);
          }
          return;
        }

        final result = await coordinator.restoreWebDavPlainBackupToDirectory(
          settings: settings,
          accountKey: accountKey,
          exportLibrary: exportLibrary!,
          exportPrefix: exportPrefix!,
          onConfigRestorePrompt: _promptConfigRestoreDecision,
        );
        final success = await handleResult(
          result,
          (_) => coordinator.restoreWebDavPlainBackupToDirectory(
            settings: settings,
            accountKey: accountKey,
            exportLibrary: exportLibrary!,
            exportPrefix: exportPrefix!,
            onConfigRestorePrompt: _promptConfigRestoreDecision,
          ),
        );
        if (!success && createdManagedRestoreWorkspace) {
          await _cleanupManagedRestoreWorkspace(exportLibrary);
        }
        return;
      }

      final password = await _resolveBackupPassword(confirm: false);
      if (!mounted || password == null) return;

      List<WebDavBackupSnapshotInfo> snapshots;
      try {
        snapshots = await coordinator.listWebDavBackupSnapshots(
          settings: settings,
          accountKey: accountKey,
          password: password,
        );
      } catch (e) {
        if (!mounted) return;
        final message = _formatBackupError(e);
        showTopToast(context, message);
        return;
      }
      if (!mounted) return;
      if (snapshots.isEmpty) {
        showTopToast(context, context.t.strings.legacy.msg_no_backups_found);
        return;
      }

      final selected = await showSettingsSingleChoicePicker<WebDavBackupSnapshotInfo>(
        context: context,
        title: context.t.strings.legacy.msg_select_backup,
        value: null,
        maxHeightFactor: 0.6,
        options: [
          for (final item in snapshots)
            SettingsChoiceOption<WebDavBackupSnapshotInfo>(
              value: item,
              label: _formatTime(DateTime.tryParse(item.createdAt)),
              description:
                  '${item.memosCount} ${context.t.strings.legacy.msg_memo} · '
                  '${item.fileCount} ${context.t.strings.legacy.msg_attachments}',
            ),
        ],
      );
      if (!mounted || selected == null) return;

      if (usesServerMode) {
        final result = await coordinator.restoreWebDavSnapshotToDirectory(
          settings: settings,
          accountKey: accountKey,
          snapshot: selected,
          password: password,
          exportLibrary: exportLibrary!,
          exportPrefix: exportPrefix!,
          onConfigRestorePrompt: _promptConfigRestoreDecision,
        );
        final success = await handleResult(
          result,
          (_) => coordinator.restoreWebDavSnapshotToDirectory(
            settings: settings,
            accountKey: accountKey,
            snapshot: selected,
            password: password,
            exportLibrary: exportLibrary!,
            exportPrefix: exportPrefix!,
            onConfigRestorePrompt: _promptConfigRestoreDecision,
          ),
        );
        if (!success && createdManagedRestoreWorkspace) {
          await _cleanupManagedRestoreWorkspace(exportLibrary);
        }
      } else {
        final result = await coordinator.restoreWebDavSnapshot(
          settings: settings,
          accountKey: accountKey,
          activeLocalLibrary: localLibrary,
          snapshot: selected,
          password: password,
          onConfigRestorePrompt: _promptConfigRestoreDecision,
        );
        await handleResult(
          result,
          (decisions) => coordinator.restoreWebDavSnapshot(
            settings: settings,
            accountKey: accountKey,
            activeLocalLibrary: localLibrary,
            snapshot: selected,
            password: password,
            conflictDecisions: decisions,
            onConfigRestorePrompt: _promptConfigRestoreDecision,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _backupRestoring = false);
      }
    }
  }

  Future<Map<String, bool>> _resolveLocalScanConflicts(
    List<LocalScanConflict> conflicts,
  ) async {
    final decisions = <String, bool>{};
    for (final conflict in conflicts) {
      final useDisk = await showSettingsConfirmationDialog(
        context: context,
        title: context.t.strings.legacy.msg_resolve_conflict,
        message: conflict.isDeletion
            ? context.t.strings.legacy.msg_memo_missing_disk_but_has_local
            : context
                  .t
                  .strings
                  .legacy
                  .msg_disk_content_conflicts_local_pending_changes,
        confirmLabel: context.t.strings.legacy.msg_use_disk,
        cancelLabel: context.t.strings.legacy.msg_keep_local,
      );
      decisions[conflict.memoUid] = useDisk;
    }
    return decisions;
  }

  Future<Map<String, bool>?> _resolveWebDavConflicts(
    List<String> conflicts,
  ) async {
    if (conflicts.isEmpty) return null;
    return showPlatformDialog<Map<String, bool>>(
      context: context,
      builder: (context) => _WebDavConflictDialog(conflicts: conflicts),
    );
  }

  Future<Set<WebDavBackupConfigType>> _promptConfigRestoreDecision(
    Set<WebDavBackupConfigType> candidates,
  ) async {
    if (candidates.isEmpty) return const {};
    final options = candidates.toList(growable: false);
    var selected = options.toSet();
    final result =
        await showPlatformDialog<Set<WebDavBackupConfigType>>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setState) => SettingsFormDialog(
              title: Text(
                context.t.strings.legacy.msg_restore_config_confirm_title,
              ),
              actions: [
                SettingsDialogAction(
                  onPressed: () =>
                      dialogContext.safePop(const <WebDavBackupConfigType>{}),
                  label: Text(context.t.strings.legacy.msg_skip),
                ),
                SettingsDialogAction(
                  onPressed: () => dialogContext.safePop(selected),
                  label: Text(context.t.strings.legacy.msg_confirm),
                  variant: PlatformPrimaryActionVariant.filled,
                ),
              ],
              children: [
                Text(context.t.strings.legacy.msg_restore_config_confirm_hint),
                const SizedBox(height: 12),
                for (final item in options)
                  SettingsMultiChoiceRow<WebDavBackupConfigType>(
                    option: SettingsChoiceOption<WebDavBackupConfigType>(
                      value: item,
                      label: _backupConfigTypeLabel(item),
                    ),
                    selected: selected.contains(item),
                    onChanged: (value) {
                      setState(() {
                        if (value) {
                          selected.add(item);
                        } else {
                          selected.remove(item);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
        ) ??
        const <WebDavBackupConfigType>{};
    return result;
  }

  String _backupConfigTypeLabel(WebDavBackupConfigType type) {
    return switch (type) {
      WebDavBackupConfigType.webdavSettings =>
        context.t.strings.legacy.msg_restore_config_item_webdav,
      WebDavBackupConfigType.imageBedSettings =>
        context.t.strings.legacy.msg_restore_config_item_image_bed,
      WebDavBackupConfigType.appLock =>
        context.t.strings.legacy.msg_restore_config_item_app_lock,
      WebDavBackupConfigType.aiSettings =>
        context.t.strings.legacy.msg_restore_config_item_ai,
      WebDavBackupConfigType.imageCompressionSettings =>
        context.t.strings.legacy.msg_restore_config_item_image_compression,
      _ => type.name,
    };
  }

  Future<({LocalLibrary library, String prefix})?>
  _createManagedRestoreWorkspace() async {
    try {
      final key = 'local_${generateUid(length: 12)}';
      await ensureManagedWorkspaceStructure(key);
      final rootPath = await resolveManagedWorkspacePath(key);
      final stamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      final library = LocalLibrary(
        key: key,
        name: context.tr(
          zh: '\u4ece WebDAV \u6062\u590d $stamp',
          en: 'Restored from WebDAV $stamp',
        ),
        storageKind: LocalLibraryStorageKind.managedPrivate,
        rootPath: rootPath,
      );
      return (library: library, prefix: '');
    } catch (_) {
      return null;
    }
  }

  Future<void> _cleanupManagedRestoreWorkspace(LocalLibrary? library) async {
    if (library == null) return;
    if (!library.isManagedPrivate) return;
    final rootPath = library.rootPath?.trim() ?? '';
    if (rootPath.isEmpty) return;
    try {
      final dir = Directory(rootPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> _openVaultSecurityStatus() async {
    if (_backupEncryptionMode == WebDavBackupEncryptionMode.plain) {
      if (!mounted) return;
      showTopToast(
        context,
        context.tr(
          zh: '\u5b89\u5168\u72b6\u6001\u68c0\u67e5\u4ec5\u9002\u7528\u4e8e\u52a0\u5bc6\u5907\u4efd\u3002',
          en: 'Vault security status is available for encrypted backup only.',
        ),
      );
      return;
    }
    if (!_vaultEnabled) {
      if (!mounted) return;
      showTopToast(
        context,
        context.tr(
          zh: '\u8bf7\u5148\u5728\u5907\u4efd\u7b56\u7565\u8bbe\u7f6e\u4e2d\u542f\u7528\u5e76\u8bbe\u7f6e Vault \u5bc6\u7801\u3002',
          en: 'Enable and set a Vault password in Backup strategy settings first.',
        ),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => const VaultSecurityStatusScreen(),
      ),
    );
  }

  String _formatSyncError(SyncError error) {
    return presentSyncError(language: context.appLanguage, error: error);
  }

  String _formatBackupError(Object error) {
    if (error is SyncError) {
      return presentSyncError(language: context.appLanguage, error: error);
    }
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return context.t.strings.legacy.msg_backup_failed;
    }
    final mappedRaw = _mapBackupErrorCode(raw);
    if (mappedRaw != null) return mappedRaw;
    const prefix = 'Bad state:';
    if (raw.startsWith(prefix)) {
      final trimmed = raw.substring(prefix.length).trim();
      if (trimmed.isNotEmpty) {
        final mapped = _mapBackupErrorCode(trimmed);
        if (mapped != null) return mapped;
        return trimmed;
      }
    }
    return raw;
  }

  String? _mapBackupErrorCode(String code) {
    return switch (code) {
      'RECOVERY_CODE_INVALID' =>
        context.t.strings.legacy.webdav.recovery_code_invalid,
      'RECOVERY_CODE_NOT_CONFIGURED' =>
        context.t.strings.legacy.webdav.recovery_not_configured,
      _ => null,
    };
  }

  void _normalizeServerUrl() {
    final normalized = normalizeWebDavBaseUrl(_serverUrlController.text);
    if (normalized != _serverUrlController.text) {
      _serverUrlController.text = normalized;
    }
    ref.read(webDavSettingsProvider.notifier).setServerUrl(normalized);
  }

  void _normalizeRootPath() {
    final normalized = normalizeWebDavRootPath(_rootPathController.text);
    if (normalized != _rootPathController.text) {
      _rootPathController.text = normalized;
    }
    ref.read(webDavSettingsProvider.notifier).setRootPath(normalized);
  }

  Future<void> _syncNow() async {
    ref.read(webDavSettingsProvider.notifier).setAutoSyncAllowed(true);
    final result = await ref
        .read(desktopSyncFacadeProvider)
        .requestSync(
          const SyncRequest(
            kind: SyncRequestKind.webDavSync,
            reason: SyncRequestReason.manual,
          ),
        );
    if (!mounted) return;
    if (result is SyncRunConflict) {
      final choices = await _resolveWebDavConflicts(result.conflicts);
      if (!mounted || choices == null) return;
      await ref.read(desktopSyncFacadeProvider).resolveWebDavConflicts(choices);
    }
  }

  Future<void> _openWebDavLogs() async {
    await Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => const WebDavLogsScreen(),
      ),
    );
    if (mounted) setState(() {});
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(time);
  }

  String _backupScheduleLabel(WebDavBackupSchedule schedule) {
    return switch (schedule) {
      WebDavBackupSchedule.manual => context.t.strings.legacy.msg_manual,
      WebDavBackupSchedule.daily => context.t.strings.legacy.msg_daily,
      WebDavBackupSchedule.weekly => context.t.strings.legacy.msg_weekly,
      WebDavBackupSchedule.monthly => context.tr(zh: '每月', en: 'Monthly'),
      WebDavBackupSchedule.onOpen => context.tr(zh: '每次打开', en: 'On app open'),
    };
  }

  String _progressStageLabel(WebDavBackupProgressStage? stage) {
    return switch (stage) {
      WebDavBackupProgressStage.preparing => context.tr(
        zh: '准备',
        en: 'Preparing',
      ),
      WebDavBackupProgressStage.exporting => context.tr(
        zh: '导出本地',
        en: 'Exporting local',
      ),
      WebDavBackupProgressStage.uploading => context.tr(
        zh: '上传',
        en: 'Uploading',
      ),
      WebDavBackupProgressStage.writingManifest => context.tr(
        zh: '写入清单',
        en: 'Writing manifest',
      ),
      WebDavBackupProgressStage.downloading => context.tr(
        zh: '下载',
        en: 'Downloading',
      ),
      WebDavBackupProgressStage.writing => context.tr(zh: '写入', en: 'Writing'),
      WebDavBackupProgressStage.scanning => context.tr(
        zh: '重建/扫描',
        en: 'Rebuild/Scan',
      ),
      WebDavBackupProgressStage.completed => context.tr(
        zh: '完成',
        en: 'Completed',
      ),
      _ => context.tr(zh: '准备', en: 'Preparing'),
    };
  }

  String _progressActionLabel(WebDavBackupProgressStage? stage) {
    return switch (stage) {
      WebDavBackupProgressStage.preparing => context.tr(
        zh: '正在准备',
        en: 'Preparing',
      ),
      WebDavBackupProgressStage.exporting => context.tr(
        zh: '正在导出本地',
        en: 'Exporting local data',
      ),
      WebDavBackupProgressStage.uploading => context.tr(
        zh: '正在上传',
        en: 'Uploading',
      ),
      WebDavBackupProgressStage.writingManifest => context.tr(
        zh: '正在写入清单',
        en: 'Writing manifest',
      ),
      WebDavBackupProgressStage.downloading => context.tr(
        zh: '正在下载',
        en: 'Downloading',
      ),
      WebDavBackupProgressStage.writing => context.tr(
        zh: '正在写入',
        en: 'Writing',
      ),
      WebDavBackupProgressStage.scanning => context.tr(
        zh: '正在重建/扫描本地库',
        en: 'Rebuilding/Scanning local library',
      ),
      WebDavBackupProgressStage.completed => context.tr(
        zh: '已完成',
        en: 'Completed',
      ),
      _ => context.tr(zh: '正在准备', en: 'Preparing'),
    };
  }

  String _progressItemGroupLabel(WebDavBackupProgressItemGroup group) {
    return switch (group) {
      WebDavBackupProgressItemGroup.memo => context.t.strings.legacy.msg_memo,
      WebDavBackupProgressItemGroup.attachment =>
        context.t.strings.legacy.msg_attachments,
      WebDavBackupProgressItemGroup.config => context.tr(
        zh: '配置',
        en: 'Config',
      ),
      WebDavBackupProgressItemGroup.manifest => context.tr(
        zh: '清单',
        en: 'Manifest',
      ),
      WebDavBackupProgressItemGroup.other => context.tr(zh: '文件', en: 'Files'),
    };
  }

  String _progressDetail(WebDavBackupProgressSnapshot snapshot) {
    if (snapshot.stage == WebDavBackupProgressStage.scanning) {
      return _progressActionLabel(snapshot.stage);
    }
    final action = _progressActionLabel(snapshot.stage);
    final path = snapshot.currentPath?.trim() ?? '';
    if (path.isNotEmpty) {
      return '$action $path';
    }
    final group = snapshot.itemGroup;
    if (group != null &&
        group != WebDavBackupProgressItemGroup.other &&
        snapshot.total > 0) {
      return '${_progressItemGroupLabel(group)} ${snapshot.completed}/${snapshot.total}';
    }
    return action;
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.watch(syncCoordinatorProvider);
    final syncStatus = coordinator.webDavSync;
    final backupStatus = coordinator.webDavBackup;
    final progressSnapshot = ref
        .watch(webDavBackupProgressTrackerProvider)
        .snapshot;
    final syncErrorText = syncStatus.lastError == null
        ? null
        : _formatSyncError(syncStatus.lastError!);
    final session = ref.watch(appSessionProvider).valueOrNull;
    final localLibrary = ref.watch(currentLocalLibraryProvider);
    final usesServerMode = session?.currentAccount != null;
    final backupAvailable = usesServerMode ? true : localLibrary != null;
    final backupUnavailableHint =
        context.t.strings.legacy.msg_local_library_only;
    final tokens = settingsPageTokens(context);
    final serverUrl = _serverUrlController.text.trim();
    final connectionSubtitle = serverUrl.isEmpty
        ? context.t.strings.legacy.msg_not_set
        : serverUrl;
    final retentionText = _backupRetentionController.text.trim();
    final retentionValue = retentionText.isEmpty ? '5' : retentionText;
    final backupSubtitle = !backupAvailable
        ? backupUnavailableHint
        : !_enabled
        ? context.t.strings.legacy.msg_disabled
        : '${_backupScheduleLabel(_backupSchedule)} \u00b7 $retentionValue';
    final backupBusy = backupStatus.running || _backupRestoring;
    final vaultSecurityDisabled =
        _backupEncryptionMode == WebDavBackupEncryptionMode.plain;
    final vaultSecuritySubtitle = vaultSecurityDisabled
        ? context.tr(
            zh: '\u4ec5\u9002\u7528\u4e8e\u52a0\u5bc6\u5907\u4efd',
            en: 'Available for encrypted backup only',
          )
        : _vaultEnabled
        ? context.tr(zh: '\u5df2\u542f\u7528', en: 'Enabled')
        : context.tr(zh: '\u672a\u542f\u7528', en: 'Not enabled');

    return SettingsPage(
      title: Text(context.t.strings.legacy.msg_webdav_sync),
      actions: [
        IconButton(
          tooltip: context.t.strings.legacy.msg_sync,
          onPressed: (!_enabled || syncStatus.running) ? null : _syncNow,
          icon: syncStatus.running
              ? const SizedBox.square(dimension: 18, child: PlatformProgress())
              : const Icon(Icons.sync),
        ),
      ],
      children: [
        SettingsSection(
          children: [
            SettingsToggleRow(
              label: context.t.strings.legacy.msg_enable_webdav_sync,
              description: context.tr(
                zh: '\u8bbe\u7f6e\u66f4\u6539\u4f1a\u540c\u6b65 WebDAV \u914d\u7f6e\uff1b\u7b14\u8bb0\u4e0e\u9644\u4ef6\u9700\u8981\u5355\u72ec\u5907\u4efd\u3002',
                en: 'Setting changes sync WebDAV configuration. Memos and attachments are backed up separately.',
              ),
              value: _enabled,
              onChanged: _setEnabled,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          children: [
            SettingsNavigationRow(
              leading: Icon(
                Icons.link_rounded,
                size: 20,
                color: tokens.textMuted,
              ),
              label: context.t.strings.legacy.msg_server_connection,
              description: connectionSubtitle,
              onTap: _openConnectionSettings,
            ),
            SettingsNavigationRow(
              leading: Icon(
                Icons.cloud_upload_outlined,
                size: 20,
                color: tokens.textMuted,
              ),
              label: context.tr(zh: '备份策略设置', en: 'Backup strategy settings'),
              description: backupSubtitle,
              onTap: _openBackupSettings,
            ),
            SettingsNavigationRow(
              leading: Icon(
                Icons.lock_outline,
                size: 20,
                color: tokens.textMuted,
              ),
              label: context.tr(zh: '安全状态检查', en: 'Vault security status'),
              description: vaultSecuritySubtitle,
              enabled: !vaultSecurityDisabled,
              onTap: vaultSecurityDisabled ? null : _openVaultSecurityStatus,
            ),
            SettingsNavigationRow(
              leading: Icon(
                Icons.receipt_long_outlined,
                size: 20,
                color: tokens.textMuted,
              ),
              label: 'WebDAV ${context.t.strings.legacy.msg_logs}',
              description: context.t.strings.legacy.msg_view_debug_logs,
              onTap: _openWebDavLogs,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _WebDavActionButton(
              label: backupStatus.running
                  ? context.t.strings.legacy.msg_backing
                  : context.t.strings.legacy.msg_start_backup,
              icon: backupStatus.running
                  ? const SizedBox.square(
                      dimension: 16,
                      child: PlatformProgress(),
                    )
                  : const Icon(Icons.backup_outlined, size: 18),
              onPressed: (!_enabled || backupBusy) ? null : _backupNow,
              variant: PlatformPrimaryActionVariant.filled,
            ),
            _WebDavActionButton(
              label: _backupRestoring
                  ? context.t.strings.legacy.msg_restoring
                  : usesServerMode
                  ? context.t.strings.legacy.msg_restore_to_directory
                  : context.t.strings.legacy.msg_restore_cloud,
              icon: _backupRestoring
                  ? const SizedBox.square(
                      dimension: 16,
                      child: PlatformProgress(),
                    )
                  : const Icon(Icons.cloud_download_outlined, size: 18),
              onPressed: (!_enabled || backupBusy) ? null : _restoreBackup,
            ),
          ],
        ),
        if (progressSnapshot.running) ...[
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final snapshot = progressSnapshot;
              final progressText = snapshot.total > 0
                  ? '${snapshot.completed}/${snapshot.total}'
                  : '-';
              final detail = _progressDetail(snapshot);
              final stageLabel = _progressStageLabel(snapshot.stage);
              return Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: tokens.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.tr(zh: '阶段', en: 'Stage')}: $stageLabel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tokens.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${context.tr(zh: '进度', en: 'Progress')}:',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox.square(
                          dimension: 18,
                          child: PlatformProgress(value: snapshot.progress),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          progressText,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textMuted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${context.tr(zh: '说明', en: 'Detail')}: $detail',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        zh: '备份/恢复需要保持前台，进入后台将自动暂停。',
                        en: 'Keep the app in foreground during backup/restore; it will pause in background.',
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.isDark
                            ? const Color(0xFFFF8A80)
                            : const Color(0xFFD32F2F),
                      ),
                    ),
                    if (snapshot.paused) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: tokens.isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.pause_circle_outline,
                              size: 18,
                              color: tokens.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr(
                                  zh: '已暂停：回到前台可继续',
                                  en: 'Paused: return to foreground to continue',
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.textMain,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PlatformPrimaryAction(
                              onPressed: () => ref
                                  .read(webDavBackupProgressTrackerProvider)
                                  .resume(),
                              child: Text(context.tr(zh: '继续', en: 'Resume')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
        if (syncErrorText != null && syncErrorText.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            syncErrorText,
            style: TextStyle(fontSize: 12, color: tokens.textMuted),
          ),
        ],
      ],
    );
  }
}

class _WebDavConflictDialog extends StatefulWidget {
  const _WebDavConflictDialog({required this.conflicts});

  final List<String> conflicts;

  @override
  State<_WebDavConflictDialog> createState() => _WebDavConflictDialogState();
}

class _WebDavConflictDialogState extends State<_WebDavConflictDialog> {
  final Map<String, bool> _choices = {};
  bool _applyToAll = false;
  bool _useLocalForAll = true;

  @override
  void initState() {
    super.initState();
    for (final name in widget.conflicts) {
      _choices[name] = true;
    }
  }

  void _toggleApplyAll(bool? value) {
    setState(() {
      _applyToAll = value ?? false;
      if (_applyToAll) {
        for (final name in widget.conflicts) {
          _choices[name] = _useLocalForAll;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final language = context.appLanguage;
    final useLocalLabel = trByLanguageKey(
      language: language,
      key: 'legacy.msg_use_local',
    );
    final useRemoteLabel = trByLanguageKey(
      language: language,
      key: 'legacy.msg_use_remote',
    );
    final sourceOptions = [
      SettingsChoiceOption<bool>(value: true, label: useLocalLabel),
      SettingsChoiceOption<bool>(value: false, label: useRemoteLabel),
    ];

    return SettingsFormDialog(
      title: Text(context.tr(zh: '设置备份冲突', en: 'Settings backup conflicts')),
      maxWidth: 300,
      actions: [
        SettingsDialogAction(
          onPressed: () => context.safePop(),
          label: Text(
            trByLanguageKey(language: language, key: 'legacy.msg_cancel_2'),
          ),
        ),
        SettingsDialogAction(
          onPressed: () => context.safePop(_choices),
          label: Text(
            trByLanguageKey(language: language, key: 'legacy.msg_apply'),
          ),
          variant: PlatformPrimaryActionVariant.filled,
        ),
      ],
      children: [
        Text(
          trByLanguageKey(
            language: language,
            key: 'legacy.msg_these_settings_changed_locally_remotely_choose',
          ),
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        SettingsMultiChoiceRow<String>(
          option: SettingsChoiceOption<String>(
            value: 'apply_all',
            label: trByLanguageKey(
              language: language,
              key: 'legacy.msg_apply_all',
            ),
          ),
          selected: _applyToAll,
          onChanged: _toggleApplyAll,
        ),
        if (_applyToAll) ...[
          const SizedBox(height: 12),
          SettingsSingleChoiceList<bool>(
            value: _useLocalForAll,
            options: sourceOptions,
            onChanged: (value) {
              setState(() {
                _useLocalForAll = value;
                for (final name in widget.conflicts) {
                  _choices[name] = value;
                }
              });
            },
          ),
        ],
        if (!_applyToAll)
          for (final name in widget.conflicts) ...[
            const Divider(height: 20),
            SettingsRowTitle(name),
            const SizedBox(height: 8),
            SettingsSingleChoiceList<bool>(
              value: _choices[name],
              options: sourceOptions,
              onChanged: (value) => setState(() => _choices[name] = value),
            ),
          ],
      ],
    );
  }
}

class _WebDavActionButton extends StatelessWidget {
  const _WebDavActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.variant = PlatformPrimaryActionVariant.outlined,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final PlatformPrimaryActionVariant variant;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 184, maxWidth: 280),
      child: SettingsAction(
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        icon: icon,
        onPressed: onPressed,
        variant: variant,
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.card,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final Color card;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onTap != null;
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: enabled ? null : Theme.of(context).disabledColor,
    );
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(
        context,
      ).textTheme.bodySmall?.color?.withValues(alpha: enabled ? 0.65 : 0.45),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: enabled
                ? card
                : card.withValues(alpha: isDark ? 0.75 : 0.92),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withValues(
                    alpha: enabled ? 0.12 : 0.06,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: enabled ? null : Theme.of(context).disabledColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: titleStyle),
                    const SizedBox(height: 4),
                    Text(subtitle, style: subtitleStyle),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: enabled
                    ? Theme.of(context).textTheme.bodySmall?.color
                    : Theme.of(context).disabledColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncStatusLine extends StatelessWidget {
  const _SyncStatusLine({
    required this.label,
    required this.value,
    required this.syncing,
    required this.textMuted,
  });

  final String label;
  final String value;
  final bool syncing;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: textMuted)),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 12, color: textMuted)),
          ],
        ),
        const SizedBox(height: 6),
        if (syncing)
          const SizedBox(width: 18, height: 18, child: PlatformProgress())
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: ColoredBox(
              color: textMuted.withValues(alpha: 0.2),
              child: const SizedBox(height: 4, width: double.infinity),
            ),
          ),
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.text, required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF2E1F1F) : const Color(0xFFFFF4F0);
    final border = isDark ? const Color(0xFF4A2A2A) : const Color(0xFFFFD1C2);
    final textColor = isDark
        ? const Color(0xFFF5C8C8)
        : const Color(0xFFB23A2C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, height: 1.4, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.card,
    required this.children,
    this.divider,
    this.showDividers = true,
  });

  final Color card;
  final List<Widget> children;
  final Color? divider;
  final bool showDividers;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(children: children);
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.label,
    required this.value,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color textMain;
  final Color textMuted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PlatformListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: textMuted)),
          const SizedBox(width: 6),
          Icon(PlatformIcons.chevronForward, size: 18, color: textMuted),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.label,
    required this.hint,
    required this.controller,
    required this.textMain,
    required this.textMuted,
    required this.onChanged,
    this.keyboardType,
    this.onEditingComplete,
    this.suffixIcon,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final VoidCallback? onEditingComplete;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return PlatformListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
      ),
      subtitle: PlatformTextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        onEditingComplete: onEditingComplete,
        style: TextStyle(color: textMain, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: textMuted.withValues(alpha: 0.6),
            fontSize: 12,
          ),
          border: InputBorder.none,
          suffixIcon: suffixIcon,
          suffixIconConstraints: suffixIcon == null
              ? null
              : const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ),
    );
  }
}

class _InlineInputRow extends StatelessWidget {
  const _InlineInputRow({
    required this.label,
    required this.hint,
    required this.controller,
    required this.textMain,
    required this.textMuted,
    required this.onChanged,
    this.keyboardType,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return PlatformListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
      ),
      trailing: SizedBox(
        width: 72,
        child: PlatformTextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          textAlign: TextAlign.end,
          style: TextStyle(color: textMain, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: textMuted.withValues(alpha: 0.6),
              fontSize: 12,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.textMain,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color textMain;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return PlatformListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
      ),
      trailing: PlatformSwitch(value: value, onChanged: onChanged),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.textMain,
    required this.textMuted,
  });

  final String label;
  final String value;
  final Color textMain;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return PlatformListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          value,
          style: TextStyle(fontSize: 12, color: textMuted, height: 1.3),
        ),
      ),
    );
  }
}

class _WebDavConnectionScreen extends ConsumerStatefulWidget {
  const _WebDavConnectionScreen({
    required this.serverUrlController,
    required this.usernameController,
    required this.passwordController,
    required this.rootPathController,
    required this.authMode,
    required this.ignoreTlsErrors,
    required this.onAuthModeChanged,
    required this.onIgnoreTlsChanged,
    required this.onServerUrlChanged,
    required this.onUsernameChanged,
    required this.onPasswordChanged,
    required this.onRootPathChanged,
    required this.onServerUrlEditingComplete,
    required this.onRootPathEditingComplete,
  });

  final TextEditingController serverUrlController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController rootPathController;
  final WebDavAuthMode authMode;
  final bool ignoreTlsErrors;
  final ValueChanged<WebDavAuthMode> onAuthModeChanged;
  final ValueChanged<bool> onIgnoreTlsChanged;
  final ValueChanged<String> onServerUrlChanged;
  final ValueChanged<String> onUsernameChanged;
  final ValueChanged<String> onPasswordChanged;
  final ValueChanged<String> onRootPathChanged;
  final VoidCallback onServerUrlEditingComplete;
  final VoidCallback onRootPathEditingComplete;

  @override
  ConsumerState<_WebDavConnectionScreen> createState() =>
      _WebDavConnectionScreenState();
}

class _WebDavConnectionScreenState
    extends ConsumerState<_WebDavConnectionScreen> {
  late WebDavAuthMode _authMode;
  late bool _ignoreTlsErrors;
  bool _obscurePassword = true;
  bool _testingConnection = false;

  @override
  void initState() {
    super.initState();
    _authMode = widget.authMode;
    _ignoreTlsErrors = widget.ignoreTlsErrors;
  }

  @override
  void didUpdateWidget(covariant _WebDavConnectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authMode != widget.authMode) {
      _authMode = widget.authMode;
    }
    if (oldWidget.ignoreTlsErrors != widget.ignoreTlsErrors) {
      _ignoreTlsErrors = widget.ignoreTlsErrors;
    }
  }

  Future<void> _pickAuthMode() async {
    final selected = await showSettingsSingleChoicePicker<WebDavAuthMode>(
      context: context,
      title: context.t.strings.legacy.msg_auth_mode,
      value: _authMode,
      options: const [
        SettingsChoiceOption<WebDavAuthMode>(
          value: WebDavAuthMode.basic,
          label: 'Basic',
        ),
        SettingsChoiceOption<WebDavAuthMode>(
          value: WebDavAuthMode.digest,
          label: 'Digest',
        ),
      ],
    );
    if (selected == null) return;
    setState(() {
      _authMode = selected;
    });
    widget.onAuthModeChanged(selected);
  }

  WebDavSettings _draftSettings() {
    final current = ref.read(webDavSettingsProvider);
    return current.copyWith(
      serverUrl: normalizeWebDavBaseUrl(widget.serverUrlController.text),
      username: widget.usernameController.text.trim(),
      password: widget.passwordController.text,
      rootPath: normalizeWebDavRootPath(widget.rootPathController.text),
      authMode: _authMode,
      ignoreTlsErrors: _ignoreTlsErrors,
    );
  }

  String? _connectionTestMessage(
    BuildContext context,
    WebDavConnectionTestResult result,
  ) {
    if (result.success) {
      return result.cleanupFailed
          ? context.tr(
              zh: '\u8fde\u63a5\u53ef\u7528\uff0c\u4f46\u6d4b\u8bd5\u6587\u4ef6\u6e05\u7406\u5931\u8d25\u3002',
              en: 'Connection works, but cleanup of the probe file failed.',
            )
          : context.tr(
              zh: '\u8fde\u63a5\u6d4b\u8bd5\u901a\u8fc7\uff0cWebDAV \u53ef\u7528\u3002',
              en: 'Connection test passed. WebDAV is reachable and writable.',
            );
    }
    final error = result.error;
    if (error == null) return null;
    return presentSyncError(language: context.appLanguage, error: error);
  }

  Future<void> _testConnection() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _testingConnection = true;
    });
    final result = await ref
        .read(desktopSyncFacadeProvider)
        .testWebDavConnection(settings: _draftSettings());
    if (!mounted) return;
    setState(() {
      _testingConnection = false;
    });
    final message = _connectionTestMessage(context, result);
    if (message == null || message.trim().isEmpty) return;
    showTopToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final serverUrl = widget.serverUrlController.text.trim();
    final isHttp = serverUrl.startsWith('http://');
    final hasCredentialMismatch =
        widget.usernameController.text.trim().isEmpty !=
        widget.passwordController.text.trim().isEmpty;
    final canTestConnection = serverUrl.isNotEmpty && !hasCredentialMismatch;

    return SettingsPage(
      title: Text(context.t.strings.legacy.msg_server_connection),
      children: [
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_basic_settings),
          children: [
            _InputRow(
              label: context.t.strings.legacy.msg_server_url,
              hint: 'https://example.com/dav',
              controller: widget.serverUrlController,
              textMain: tokens.textMain,
              textMuted: tokens.textMuted,
              keyboardType: TextInputType.url,
              onChanged: widget.onServerUrlChanged,
              onEditingComplete: widget.onServerUrlEditingComplete,
              suffixIcon: IconButton(
                tooltip: context.tr(
                  zh: '\u6d4b\u8bd5\u8fde\u63a5',
                  en: 'Test connection',
                ),
                onPressed: (!canTestConnection || _testingConnection)
                    ? null
                    : _testConnection,
                icon: _testingConnection
                    ? const SizedBox.square(
                        dimension: 16,
                        child: PlatformProgress(),
                      )
                    : const Icon(Icons.network_check_rounded, size: 20),
              ),
            ),
            if (hasCredentialMismatch) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  context.tr(
                    zh: '\u8bf7\u540c\u65f6\u586b\u5199\u7528\u6237\u540d\u548c\u5bc6\u7801\uff0c\u6216\u5747\u7559\u7a7a\u3002',
                    en: 'Enter both username and password, or leave both empty.',
                  ),
                  style: TextStyle(fontSize: 12, color: tokens.textMuted),
                ),
              ),
            ],
            _InputRow(
              label: context.t.strings.legacy.msg_username,
              hint: context.t.strings.legacy.msg_enter_username,
              controller: widget.usernameController,
              textMain: tokens.textMain,
              textMuted: tokens.textMuted,
              onChanged: widget.onUsernameChanged,
            ),
            PlatformListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              title: Text(
                context.t.strings.legacy.msg_password,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: tokens.textMain,
                ),
              ),
              subtitle: PlatformTextField(
                controller: widget.passwordController,
                obscureText: _obscurePassword,
                onChanged: widget.onPasswordChanged,
                style: TextStyle(
                  color: tokens.textMain,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: context.t.strings.legacy.msg_enter_password_2,
                  hintStyle: TextStyle(
                    color: tokens.textMuted.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isHttp || _ignoreTlsErrors) ...[
          _WarningCard(
            text: context
                .t
                .strings
                .legacy
                .msg_use_https_avoid_ignoring_tls_errors,
            isDark: tokens.isDark,
          ),
          const SizedBox(height: 16),
        ],
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_auth_settings),
          children: [
            _SelectRow(
              label: context.t.strings.legacy.msg_auth_mode,
              value: _authMode.name.toUpperCase(),
              textMain: tokens.textMain,
              textMuted: tokens.textMuted,
              onTap: _pickAuthMode,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_advanced_security),
          children: [
            _ToggleRow(
              label: context.t.strings.legacy.msg_ignore_tls_errors,
              value: _ignoreTlsErrors,
              textMain: tokens.textMain,
              onChanged: (v) {
                setState(() => _ignoreTlsErrors = v);
                widget.onIgnoreTlsChanged(v);
              },
            ),
            _InputRow(
              label: context.t.strings.legacy.msg_root_path,
              hint: '/notes',
              controller: widget.rootPathController,
              textMain: tokens.textMain,
              textMuted: tokens.textMuted,
              onChanged: widget.onRootPathChanged,
              onEditingComplete: widget.onRootPathEditingComplete,
            ),
          ],
        ),
      ],
    );
  }
}

class _WebDavBackupSettingsScreen extends ConsumerStatefulWidget {
  const _WebDavBackupSettingsScreen({
    required this.backupAvailable,
    required this.backupUnavailableHint,
    required this.usesServerMode,
    required this.backupRestoring,
    required this.backupConfigScope,
    required this.backupContentMemos,
    required this.backupEncryptionMode,
    required this.backupPasswordSet,
    required this.vaultEnabled,
    required this.backupSchedule,
    required this.backupRetentionController,
    required this.onBackupConfigScopeChanged,
    required this.onBackupContentMemosChanged,
    required this.onBackupEncryptionModeChanged,
    required this.onBackupScheduleChanged,
    required this.onBackupRetentionChanged,
    required this.onSetupBackupPassword,
  });

  final bool backupAvailable;
  final String backupUnavailableHint;
  final bool usesServerMode;
  final bool backupRestoring;
  final WebDavBackupConfigScope backupConfigScope;
  final bool backupContentMemos;
  final WebDavBackupEncryptionMode backupEncryptionMode;
  final bool backupPasswordSet;
  final bool vaultEnabled;
  final WebDavBackupSchedule backupSchedule;
  final TextEditingController backupRetentionController;
  final ValueChanged<WebDavBackupConfigScope> onBackupConfigScopeChanged;
  final ValueChanged<bool> onBackupContentMemosChanged;
  final ValueChanged<WebDavBackupEncryptionMode> onBackupEncryptionModeChanged;
  final ValueChanged<WebDavBackupSchedule> onBackupScheduleChanged;
  final ValueChanged<String> onBackupRetentionChanged;
  final Future<bool> Function() onSetupBackupPassword;

  @override
  ConsumerState<_WebDavBackupSettingsScreen> createState() =>
      _WebDavBackupSettingsScreenState();
}

class _WebDavBackupSettingsScreenState
    extends ConsumerState<_WebDavBackupSettingsScreen> {
  late WebDavBackupConfigScope _configScope;
  late bool _backupContentMemos;
  late WebDavBackupEncryptionMode _encryptionMode;
  late bool _backupPasswordSet;
  late WebDavBackupSchedule _schedule;

  @override
  void initState() {
    super.initState();
    _configScope = widget.backupConfigScope;
    _backupContentMemos = widget.backupContentMemos;
    _encryptionMode = widget.backupEncryptionMode;
    _backupPasswordSet = widget.backupPasswordSet;
    _schedule = widget.backupSchedule;
  }

  @override
  void didUpdateWidget(covariant _WebDavBackupSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backupConfigScope != widget.backupConfigScope) {
      _configScope = widget.backupConfigScope;
    }
    if (oldWidget.backupContentMemos != widget.backupContentMemos) {
      _backupContentMemos = widget.backupContentMemos;
    }
    if (oldWidget.backupEncryptionMode != widget.backupEncryptionMode) {
      _encryptionMode = widget.backupEncryptionMode;
    }
    if (oldWidget.backupPasswordSet != widget.backupPasswordSet) {
      _backupPasswordSet = widget.backupPasswordSet;
    }
    if (oldWidget.backupSchedule != widget.backupSchedule) {
      _schedule = widget.backupSchedule;
    }
  }

  void _handleBackupConfigScope(WebDavBackupConfigScope scope) {
    setState(() => _configScope = scope);
    widget.onBackupConfigScopeChanged(scope);
  }

  void _handleBackupConfigToggle(bool enabled) {
    if (!enabled) {
      _handleBackupConfigScope(WebDavBackupConfigScope.none);
      return;
    }
    var nextScope = _configScope;
    if (nextScope == WebDavBackupConfigScope.none) {
      nextScope = WebDavBackupConfigScope.safe;
    }
    if (_encryptionMode != WebDavBackupEncryptionMode.encrypted &&
        nextScope == WebDavBackupConfigScope.full) {
      nextScope = WebDavBackupConfigScope.safe;
    }
    _handleBackupConfigScope(nextScope);
  }

  void _handleBackupContentMemos(bool value) {
    setState(() => _backupContentMemos = value);
    widget.onBackupContentMemosChanged(value);
  }

  Future<void> _pickBackupConfigScope() async {
    final selected =
        await showSettingsSingleChoicePicker<WebDavBackupConfigScope>(
          context: context,
          title: context.tr(zh: '配置内容', en: 'Config scope'),
          value: _configScope,
          options: [
            SettingsChoiceOption<WebDavBackupConfigScope>(
              value: WebDavBackupConfigScope.safe,
              label: context.t.strings.legacy.msg_backup_config_safe,
            ),
            SettingsChoiceOption<WebDavBackupConfigScope>(
              value: WebDavBackupConfigScope.full,
              label: context.t.strings.legacy.msg_backup_config_full,
              description:
                  _encryptionMode == WebDavBackupEncryptionMode.encrypted
                  ? context.t.strings.legacy.msg_backup_config_full_desc
                  : context
                        .t
                        .strings
                        .legacy
                        .msg_backup_config_full_requires_encryption,
            ),
          ],
        );
    if (selected == null) return;
    if (selected == WebDavBackupConfigScope.full &&
        _encryptionMode != WebDavBackupEncryptionMode.encrypted) {
      await _showFullConfigRequiresEncryptionDialog();
      return;
    }
    _handleBackupConfigScope(selected);
  }

  String _configScopeLabel(WebDavBackupConfigScope scope) {
    return switch (scope) {
      WebDavBackupConfigScope.safe =>
        context.t.strings.legacy.msg_backup_config_safe,
      WebDavBackupConfigScope.full =>
        context.t.strings.legacy.msg_backup_config_full,
      WebDavBackupConfigScope.none =>
        context.t.strings.legacy.msg_backup_config_none_desc,
    };
  }

  Future<void> _showFullConfigRequiresEncryptionDialog() async {
    await showPlatformAlertDialog<bool>(
      context: context,
      title: context.tr(zh: '需要加密', en: 'Encryption required'),
      message: context.tr(
        zh: '“全部配置（敏感）”仅支持加密备份，请先切换为加密模式并设置密码。',
        en: '"Full config (sensitive)" requires encrypted backup. Switch to encrypted mode and set a password first.',
      ),
      actions: [
        PlatformDialogAction<bool>(
          value: true,
          label: context.t.strings.legacy.msg_ok,
          isDefault: true,
        ),
      ],
    );
  }

  Future<void> _pickBackupEncryptionMode() async {
    final selected =
        await showSettingsSingleChoicePicker<WebDavBackupEncryptionMode>(
          context: context,
          title: context.tr(zh: '备份方式', en: 'Backup mode'),
          value: _encryptionMode,
          options: [
            SettingsChoiceOption<WebDavBackupEncryptionMode>(
              value: WebDavBackupEncryptionMode.encrypted,
              label: _encryptionModeLabel(
                WebDavBackupEncryptionMode.encrypted,
                context,
              ),
            ),
            SettingsChoiceOption<WebDavBackupEncryptionMode>(
              value: WebDavBackupEncryptionMode.plain,
              label: _encryptionModeLabel(
                WebDavBackupEncryptionMode.plain,
                context,
              ),
            ),
          ],
        );
    if (!mounted || selected == null) return;
    if (selected == WebDavBackupEncryptionMode.plain) {
      final confirmed = await _confirmPlainBackupRisk();
      if (!confirmed) return;
    }
    setState(() => _encryptionMode = selected);
    if (selected == WebDavBackupEncryptionMode.plain &&
        _configScope == WebDavBackupConfigScope.full) {
      _handleBackupConfigScope(WebDavBackupConfigScope.safe);
    }
    widget.onBackupEncryptionModeChanged(selected);
  }

  Future<void> _handleSetupBackupPassword() async {
    final success = await widget.onSetupBackupPassword();
    if (!mounted || !success) return;
    setState(() => _backupPasswordSet = true);
  }

  Future<bool> _handleExitGuard() async {
    if (_encryptionMode != WebDavBackupEncryptionMode.encrypted ||
        _backupPasswordSet) {
      return true;
    }
    final action = await showPlatformAlertDialog<_BackupPasswordExitAction>(
      context: context,
      title: widget.vaultEnabled
          ? context.tr(zh: 'Vault 密码未设置', en: 'Vault password missing')
          : context.tr(zh: '备份密码未设置', en: 'Backup password missing'),
      message: widget.vaultEnabled
          ? context.tr(
              zh: '加密备份需要设置 Vault 密码，是否现在设置？',
              en: 'Encrypted backup requires a Vault password. Set it now?',
            )
          : context.tr(
              zh: '加密备份需要设置密码，是否现在设置？',
              en: 'Encrypted backup requires a password. Set it now?',
            ),
      actions: [
        PlatformDialogAction<_BackupPasswordExitAction>(
          value: _BackupPasswordExitAction.abandon,
          label: context.tr(zh: '放弃设置', en: 'Abandon'),
        ),
        PlatformDialogAction<_BackupPasswordExitAction>(
          value: _BackupPasswordExitAction.setup,
          label: context.tr(zh: '去设置', en: 'Set now'),
          isDefault: true,
        ),
      ],
    );
    if (!mounted || action == null) return false;
    if (action == _BackupPasswordExitAction.setup) {
      await _handleSetupBackupPassword();
      return _backupPasswordSet;
    }
    final confirmed = await _confirmPlainBackupRisk();
    if (!confirmed) return false;
    setState(() => _encryptionMode = WebDavBackupEncryptionMode.plain);
    widget.onBackupEncryptionModeChanged(WebDavBackupEncryptionMode.plain);
    return true;
  }

  bool get _shouldInterceptPop =>
      _encryptionMode == WebDavBackupEncryptionMode.encrypted &&
      !_backupPasswordSet;

  Future<void> _requestClose() async {
    if (!_shouldInterceptPop) {
      if (!mounted) return;
      context.safePop();
      return;
    }
    final allow = await _handleExitGuard();
    if (!mounted || !allow) return;
    context.safePop();
  }

  Future<bool> _confirmPlainBackupRisk() async {
    return showSettingsConfirmationDialog(
      context: context,
      title: context.t.strings.legacy.msg_backup_plain_risk_title,
      message: context.t.strings.legacy.msg_backup_plain_risk_body,
      confirmLabel: context.t.strings.legacy.msg_confirm,
      cancelLabel: context.t.strings.legacy.msg_cancel_2,
      destructive: true,
    );
  }

  Future<void> _pickSchedule() async {
    final selected = await showSettingsSingleChoicePicker<WebDavBackupSchedule>(
      context: context,
      title: context.t.strings.legacy.msg_backup_schedule,
      value: _schedule,
      options: [
        for (final schedule in WebDavBackupSchedule.values)
          SettingsChoiceOption<WebDavBackupSchedule>(
            value: schedule,
            label: _scheduleLabel(schedule, context),
          ),
      ],
    );
    if (selected == null) return;
    setState(() => _schedule = selected);
    widget.onBackupScheduleChanged(selected);
  }

  String _scheduleLabel(WebDavBackupSchedule schedule, BuildContext context) {
    return switch (schedule) {
      WebDavBackupSchedule.manual => context.t.strings.legacy.msg_manual,
      WebDavBackupSchedule.daily => context.t.strings.legacy.msg_daily,
      WebDavBackupSchedule.weekly => context.t.strings.legacy.msg_weekly,
      WebDavBackupSchedule.monthly => context.tr(zh: '每月', en: 'Monthly'),
      WebDavBackupSchedule.onOpen => context.tr(zh: '每次打开', en: 'On app open'),
    };
  }

  String _encryptionModeLabel(
    WebDavBackupEncryptionMode mode,
    BuildContext context,
  ) {
    return switch (mode) {
      WebDavBackupEncryptionMode.encrypted => context.tr(
        zh: '加密',
        en: 'Encrypted',
      ),
      WebDavBackupEncryptionMode.plain => context.tr(
        zh: '非加密（明文）',
        en: 'Plaintext',
      ),
    };
  }

  bool _shouldHideBackupError(SyncError? error) {
    if (error == null) return true;
    final settings = ref.read(webDavSettingsProvider);
    if (error.presentationKey == 'legacy.webdav.backup_disabled' &&
        settings.isBackupEnabled) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final backupStatus = ref.watch(syncCoordinatorProvider).webDavBackup;
    final backupErrorText = _shouldHideBackupError(backupStatus.lastError)
        ? null
        : backupStatus.lastError == null
        ? null
        : presentSyncError(
            language: context.appLanguage,
            error: backupStatus.lastError!,
          );
    final tokens = settingsPageTokens(context);
    final divider = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.55);
    final backupPathUnavailable =
        _backupContentMemos && !widget.backupAvailable;
    final busy = backupStatus.running || widget.backupRestoring;

    return PopScope(
      canPop: !_shouldInterceptPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !_shouldInterceptPop) return;
        await _requestClose();
      },
      child: PlatformPage(
        backgroundColor: tokens.background,
        title: Text(context.t.strings.legacy.msg_backup_settings),
        leading: resolveDesktopRouteDismissalLeading(
          context: context,
          leading: IconButton(
            tooltip: context.t.strings.legacy.msg_back,
            icon: Icon(PlatformIcons.back),
            onPressed: _requestClose,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              context.tr(zh: '备份内容', en: 'Backup content'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tokens.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            _Group(
              card: tokens.card,
              divider: divider,
              showDividers: false,
              children: [
                _ToggleRow(
                  label: context.tr(zh: '备份配置', en: 'Backup config'),
                  value: _configScope != WebDavBackupConfigScope.none,
                  textMain: tokens.textMain,
                  onChanged: busy ? null : _handleBackupConfigToggle,
                ),
                if (_configScope != WebDavBackupConfigScope.none) ...[
                  const Divider(height: 1),
                  _SelectRow(
                    label: context.tr(zh: '配置内容', en: 'Config scope'),
                    value: _configScopeLabel(_configScope),
                    textMain: tokens.textMain,
                    textMuted: tokens.textMuted,
                    onTap: busy ? null : _pickBackupConfigScope,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      _configScope == WebDavBackupConfigScope.full
                          ? (_encryptionMode ==
                                    WebDavBackupEncryptionMode.encrypted
                                ? context
                                      .t
                                      .strings
                                      .legacy
                                      .msg_backup_config_full_desc
                                : context
                                      .t
                                      .strings
                                      .legacy
                                      .msg_backup_config_full_requires_encryption)
                          : context
                                .t
                                .strings
                                .legacy
                                .msg_backup_config_safe_desc,
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      context.t.strings.legacy.msg_backup_config_none_desc,
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                    ),
                  ),
                const Divider(height: 1),
                _ToggleRow(
                  label: context.tr(zh: '备份笔记', en: 'Backup memos'),
                  value: _backupContentMemos,
                  textMain: tokens.textMain,
                  onChanged: busy ? null : _handleBackupContentMemos,
                ),
              ],
            ),
            if (backupPathUnavailable) ...[
              const SizedBox(height: 6),
              Text(
                widget.backupUnavailableHint,
                style: TextStyle(fontSize: 12, color: tokens.textMuted),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              context.t.strings.legacy.msg_local_library_backup,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tokens.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            _Group(
              card: tokens.card,
              divider: divider,
              showDividers: false,
              children: [
                _SelectRow(
                  label: context.tr(zh: '备份方式', en: 'Backup mode'),
                  value: _encryptionModeLabel(_encryptionMode, context),
                  textMain: tokens.textMain,
                  textMuted: tokens.textMuted,
                  onTap: busy ? null : _pickBackupEncryptionMode,
                ),
                if (_encryptionMode == WebDavBackupEncryptionMode.encrypted)
                  _SelectRow(
                    label: widget.vaultEnabled
                        ? context.tr(
                            zh: '设置 Vault 密码',
                            en: 'Set Vault password',
                          )
                        : context.tr(zh: '设置密码', en: 'Set password'),
                    value: _backupPasswordSet
                        ? context.tr(zh: '已设置', en: 'Set')
                        : context.t.strings.legacy.msg_not_set,
                    textMain: tokens.textMain,
                    textMuted: tokens.textMuted,
                    onTap: busy ? null : _handleSetupBackupPassword,
                  ),
                _SelectRow(
                  label: context.t.strings.legacy.msg_backup_schedule,
                  value: _scheduleLabel(_schedule, context),
                  textMain: tokens.textMain,
                  textMuted: tokens.textMuted,
                  onTap: busy ? null : _pickSchedule,
                ),
                _InlineInputRow(
                  label: context.t.strings.legacy.msg_retention,
                  hint: '5',
                  controller: widget.backupRetentionController,
                  textMain: tokens.textMain,
                  textMuted: tokens.textMuted,
                  keyboardType: TextInputType.number,
                  onChanged: widget.onBackupRetentionChanged,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              context
                  .t
                  .strings
                  .legacy
                  .msg_keeping_more_versions_uses_more_storage,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: tokens.textMuted,
              ),
            ),
            if (backupErrorText != null &&
                backupErrorText.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                backupErrorText,
                style: TextStyle(fontSize: 12, color: tokens.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WebDavLogsScreen extends ConsumerStatefulWidget {
  const WebDavLogsScreen({super.key});

  @override
  ConsumerState<WebDavLogsScreen> createState() => _WebDavLogsScreenState();
}

class _WebDavLogsScreenState extends ConsumerState<WebDavLogsScreen> {
  final _timeFormat = DateFormat('MM-dd HH:mm:ss');
  var _loading = false;
  List<DebugLogEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final store = ref.read(webDavLogStoreProvider);
    final entries = await store.list(limit: 500);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  String _entrySubtitle(DebugLogEntry entry) {
    final lines = <String>[_timeFormat.format(entry.timestamp.toLocal())];
    final methodUrl = [
      entry.method?.trim(),
      entry.url?.trim(),
    ].whereType<String>().where((v) => v.isNotEmpty).join(' ');
    if (methodUrl.isNotEmpty) {
      lines.add(methodUrl);
    }
    final statusDuration = [
      if (entry.status != null) 'HTTP ${entry.status}',
      if (entry.durationMs != null) '${entry.durationMs}ms',
    ].join(' · ');
    if (statusDuration.trim().isNotEmpty) {
      lines.add(statusDuration);
    }
    final detail = entry.detail?.trim() ?? '';
    if (detail.isNotEmpty) {
      lines.add(detail);
    }
    final error = entry.error?.trim() ?? '';
    if (error.isNotEmpty) {
      lines.add('Error: $error');
    }
    return lines.join('\n');
  }

  void _showEntry(DebugLogEntry entry) {
    final lines = <String>[
      'Time: ${_timeFormat.format(entry.timestamp.toLocal())}',
      if (entry.method != null) 'Method: ${entry.method}',
      if (entry.url != null) 'URL: ${entry.url}',
      if (entry.status != null) 'Status: ${entry.status}',
      if (entry.durationMs != null) 'Duration: ${entry.durationMs}ms',
      if (entry.detail != null && entry.detail!.trim().isNotEmpty)
        'Detail: ${entry.detail}',
      if (entry.error != null && entry.error!.trim().isNotEmpty)
        'Error: ${entry.error}',
    ];
    showPlatformDialog<void>(
      context: context,
      builder: (dialogContext) => SettingsFormDialog(
        title: Text(entry.label),
        actions: [
          SettingsDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            label: Text(context.t.strings.legacy.msg_close),
          ),
        ],
        children: [SelectableText(lines.join('\n'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final items = _entries.reversed.toList(growable: false);

    Widget body;
    if (_loading && items.isEmpty) {
      body = const Center(child: PlatformProgress());
    } else if (items.isEmpty) {
      body = Center(
        child: Text(
          context.t.strings.legacy.msg_no_logs_yet,
          style: TextStyle(color: tokens.textMuted),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final entry = items[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showEntry(entry),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: tokens.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: tokens.textMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _entrySubtitle(entry),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: tokens.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return PlatformPage(
      backgroundColor: tokens.background,
      title: Text('WebDAV ${context.t.strings.legacy.msg_logs}'),
      leading: resolveDesktopRouteDismissalLeading(
        context: context,
        leading: IconButton(
          tooltip: context.t.strings.legacy.msg_back,
          icon: Icon(PlatformIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      actions: [
        IconButton(
          tooltip: context.t.strings.legacy.msg_refresh,
          icon: const Icon(Icons.refresh),
          onPressed: _refresh,
        ),
      ],
      body: body,
    );
  }
}

enum _BackupPasswordExitAction { setup, abandon }

enum _VaultExistingAction { verify, recover }
