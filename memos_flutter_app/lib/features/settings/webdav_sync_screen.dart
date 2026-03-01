import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saf_util/saf_util.dart';

import '../../application/sync/sync_coordinator.dart';
import '../../application/sync/sync_error.dart';
import '../../application/sync/sync_request.dart';
import '../../application/sync/sync_types.dart';
import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/sync_error_presenter.dart';
import '../../core/top_toast.dart';
import '../../data/logs/debug_log_store.dart';
import '../../data/models/local_library.dart';
import '../../core/webdav_url.dart';
import '../../data/models/webdav_backup.dart';
import '../../data/models/webdav_settings.dart';
import '../../state/local_library_provider.dart';
import '../../state/session_provider.dart';
import '../../state/webdav_backup_provider.dart';
import '../../state/webdav_log_provider.dart';
import '../../state/webdav_settings_provider.dart';
import '../../i18n/strings.g.dart';

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
  var _backupContentConfig = true;
  var _backupContentMemos = true;
  var _backupEncryptionMode = WebDavBackupEncryptionMode.encrypted;
  var _rememberBackupPassword = true;
  var _backupPasswordSet = false;
  var _backupMirrorTreeUri = '';
  var _backupMirrorRootPath = '';
  var _dirty = false;
  var _backupRestoring = false;
  SyncError? _backupRestoreError;

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
    _backupContentConfig = settings.backupContentConfig;
    _backupContentMemos = settings.backupContentMemos;
    _backupEncryptionMode = settings.backupEncryptionMode;
    _backupSchedule = settings.backupSchedule;
    _backupRetentionController.text = settings.backupRetentionCount.toString();
    _rememberBackupPassword = settings.rememberBackupPassword;
    _backupMirrorTreeUri = settings.backupMirrorTreeUri;
    _backupMirrorRootPath = settings.backupMirrorRootPath;
    setState(() {});
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  Future<void> _selectAuthMode(BuildContext sheetContext) async {
    final selected = await showDialog<WebDavAuthMode>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.t.strings.legacy.msg_auth_mode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Basic'),
              trailing: _authMode == WebDavAuthMode.basic
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavAuthMode.basic,
              ),
            ),
            ListTile(
              title: const Text('Digest'),
              trailing: _authMode == WebDavAuthMode.digest
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavAuthMode.digest,
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _authMode = selected);
    _markDirty();
    ref.read(webDavSettingsProvider.notifier).setAuthMode(selected);
  }

  Future<void> _selectBackupSchedule(BuildContext sheetContext) async {
    final selected = await showDialog<WebDavBackupSchedule>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.t.strings.legacy.msg_backup_schedule),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(dialogContext.t.strings.legacy.msg_manual),
              trailing: _backupSchedule == WebDavBackupSchedule.manual
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavBackupSchedule.manual,
              ),
            ),
            ListTile(
              title: Text(dialogContext.t.strings.legacy.msg_daily),
              trailing: _backupSchedule == WebDavBackupSchedule.daily
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavBackupSchedule.daily,
              ),
            ),
            ListTile(
              title: Text(dialogContext.t.strings.legacy.msg_weekly),
              trailing: _backupSchedule == WebDavBackupSchedule.weekly
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavBackupSchedule.weekly,
              ),
            ),
            ListTile(
              title: Text(dialogContext.tr(zh: '每月', en: 'Monthly')),
              trailing: _backupSchedule == WebDavBackupSchedule.monthly
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavBackupSchedule.monthly,
              ),
            ),
            ListTile(
              title: Text(dialogContext.tr(zh: '每次打开', en: 'On app open')),
              trailing: _backupSchedule == WebDavBackupSchedule.onOpen
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavBackupSchedule.onOpen,
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _backupSchedule = selected);
    _markDirty();
    ref.read(webDavSettingsProvider.notifier).setBackupSchedule(selected);
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

  void _setBackupContentConfig(bool value) {
    setState(() => _backupContentConfig = value);
    ref.read(webDavSettingsProvider.notifier).setBackupContentConfig(value);
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
    final stored = await ref.read(webDavBackupPasswordRepositoryProvider).read();
    if (!mounted) return;
    setState(() {
      _backupPasswordSet = stored != null && stored.trim().isNotEmpty;
    });
  }

  LocalLibrary? _resolveBackupMirrorLibrary() {
    final treeUri = _backupMirrorTreeUri.trim();
    final rootPath = _backupMirrorRootPath.trim();
    if (treeUri.isEmpty && rootPath.isEmpty) return null;
    return LocalLibrary(
      key: 'webdav_backup_mirror',
      name: context.tr(zh: 'WebDAV 备份镜像', en: 'WebDAV Backup Mirror'),
      treeUri: treeUri.isEmpty ? null : treeUri,
      rootPath: treeUri.isNotEmpty ? null : rootPath,
    );
  }

  Future<void> _pickBackupMirrorLocation() async {
    try {
      String? treeUri;
      String? rootPath;
      if (Platform.isAndroid) {
        final doc = await SafUtil().pickDirectory(
          writePermission: true,
          persistablePermission: true,
        );
        if (doc == null) return;
        treeUri = doc.uri;
      } else {
        final path = await FilePicker.platform.getDirectoryPath();
        if (path == null || path.trim().isEmpty) return;
        rootPath = path.trim();
      }
      if (!mounted) return;
      setState(() {
        _backupMirrorTreeUri = (treeUri ?? '').trim();
        _backupMirrorRootPath = (rootPath ?? '').trim();
      });
      ref
          .read(webDavSettingsProvider.notifier)
          .setBackupMirrorLocation(treeUri: treeUri, rootPath: rootPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_action_failed(e: e)),
        ),
      );
    }
  }

  Future<void> _openConnectionSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
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
    final localLibrary = ref.read(currentLocalLibraryProvider);
    final mirrorLibrary = _resolveBackupMirrorLibrary();
    final usesServerMode = localLibrary == null;
    final backupAvailable = localLibrary != null || mirrorLibrary != null;
    final backupUnavailableHint = usesServerMode
        ? '${context.t.strings.legacy.msg_export} ${context.t.strings.legacy.msg_path}: ${context.t.strings.legacy.msg_not_set}'
        : context.t.strings.legacy.msg_local_library_only;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _WebDavBackupSettingsScreen(
          backupAvailable: backupAvailable,
          backupUnavailableHint: backupUnavailableHint,
          usesServerMode: usesServerMode,
          backupRestoring: _backupRestoring,
          backupMirrorPathLabel:
              mirrorLibrary?.locationLabel ??
              context.t.strings.legacy.msg_not_set,
          onPickBackupMirrorPath: _pickBackupMirrorLocation,
          backupContentConfig: _backupContentConfig,
          backupContentMemos: _backupContentMemos,
          backupEncryptionMode: _backupEncryptionMode,
          backupPasswordSet: _backupPasswordSet,
          backupSchedule: _backupSchedule,
          backupRetentionController: _backupRetentionController,
          onBackupContentConfigChanged: _setBackupContentConfig,
          onBackupContentMemosChanged: _setBackupContentMemos,
          onBackupEncryptionModeChanged: _setBackupEncryptionMode,
          onBackupScheduleChanged: _setBackupSchedule,
          onBackupRetentionChanged: _setBackupRetention,
          onSetupBackupPassword: _setupBackupPassword,
        ),
      ),
    );
  }

  Future<String?> _promptBackupPassword({required bool confirm}) async {
    var password = '';
    var confirmPassword = '';
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t.strings.legacy.msg_backup_password),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  autofocus: true,
                  obscureText: true,
                  textInputAction: confirm
                      ? TextInputAction.next
                      : TextInputAction.done,
                  decoration: InputDecoration(
                    hintText:
                        context.t.strings.legacy.msg_enter_backup_password,
                  ),
                  onChanged: (value) => password = value,
                  onFieldSubmitted: (_) {
                    if (!confirm) {
                      FocusScope.of(context).unfocus();
                      context.safePop(true);
                    }
                  },
                ),
                if (confirm) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: context.t.strings.legacy.msg_confirm_password_2,
                    ),
                    onChanged: (value) => confirmPassword = value,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).unfocus();
                      context.safePop(true);
                    },
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  context.safePop(false);
                },
                child: Text(context.t.strings.legacy.msg_cancel_2),
              ),
              FilledButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  context.safePop(true);
                },
                child: Text(context.t.strings.legacy.msg_confirm),
              ),
            ],
          ),
        ) ??
        false;

    password = password.trim();
    confirmPassword = confirmPassword.trim();

    if (!confirmed) return null;
    if (password.isEmpty) return null;
    if (confirm && password != confirmPassword) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_passwords_not_match),
        ),
      );
      return null;
    }
    return password;
  }

  Future<bool> _setupBackupPassword() async {
    final password = await _promptBackupPassword(confirm: true);
    if (!mounted || password == null) return false;
    try {
      final settings = ref.read(webDavSettingsProvider);
      final accountKey = ref.read(appSessionProvider).valueOrNull?.currentKey;
      final service = ref.read(webDavBackupServiceProvider);
      final recoveryCode = await service.setupBackupPassword(
        settings: settings,
        accountKey: accountKey,
        password: password,
      );
      if (!mounted) return false;
      if (recoveryCode != null && recoveryCode.trim().isNotEmpty) {
        await _showRecoveryCodeDialog(
          recoveryCode,
          reset: false,
          message: context.t.strings.legacy.webdav.recovery_code_setup_message,
        );
      }
    } catch (e) {
      if (!mounted) return false;
      final message = _formatBackupError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    }

    await ref.read(webDavBackupPasswordRepositoryProvider).write(password);
    if (!_rememberBackupPassword) {
      setState(() => _rememberBackupPassword = true);
      ref.read(webDavSettingsProvider.notifier).setRememberBackupPassword(true);
    }
    if (!mounted) return false;
    setState(() => _backupPasswordSet = true);
    return true;
  }

  Future<String?> _resolveBackupPassword({required bool confirm}) async {
    final repo = ref.read(webDavBackupPasswordRepositoryProvider);
    final stored = await repo.read();
    if (stored != null && stored.trim().isNotEmpty) {
      if (mounted && !_backupPasswordSet) {
        setState(() => _backupPasswordSet = true);
      }
      return stored;
    }
    final entered = await _promptBackupPassword(confirm: confirm);
    if (entered == null || entered.trim().isEmpty) return null;
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
      await ref.read(webDavBackupServiceProvider).listSnapshots(
        settings: settings,
        accountKey: accountKey,
        password: password,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      final message = _formatBackupError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    }
  }

  Future<({String recoveryCode, String password})?>
  _promptRecoveryReset() async {
    var recoveryCode = '';
    var password = '';
    var confirmPassword = '';
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.t.strings.legacy.webdav.recover_password_title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText:
                        context.t.strings.legacy.webdav.recovery_code_enter,
                  ),
                  onChanged: (value) => recoveryCode = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: context
                        .t
                        .strings
                        .legacy
                        .webdav
                        .recovery_code_enter_new_password,
                  ),
                  onChanged: (value) => password = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: context.t.strings.legacy.msg_confirm_password_2,
                  ),
                  onChanged: (value) => confirmPassword = value,
                  onFieldSubmitted: (_) {
                    FocusScope.of(dialogContext).unfocus();
                    dialogContext.safePop(true);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => dialogContext.safePop(false),
                child: Text(context.t.strings.legacy.msg_cancel_2),
              ),
              FilledButton(
                onPressed: () => dialogContext.safePop(true),
                child: Text(context.t.strings.legacy.msg_confirm),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return null;
    recoveryCode = recoveryCode.trim();
    password = password.trim();
    confirmPassword = confirmPassword.trim();
    if (recoveryCode.isEmpty || password.isEmpty) return null;
    if (password != confirmPassword) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_passwords_not_match),
        ),
      );
      return null;
    }
    return (recoveryCode: recoveryCode, password: password);
  }

  Future<void> _showRecoveryCodeDialog(
    String code, {
    required bool reset,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.strings.legacy.webdav.recovery_code_title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  content: Text(
                    context.t.strings.legacy.webdav.recovery_code_copied,
                  ),
                ),
              );
            },
            child: Text(context.t.strings.legacy.msg_copy),
          ),
          FilledButton(
            onPressed: () => dialogContext.safePop(),
            child: Text(
              reset
                  ? context.t.strings.legacy.msg_saved_2
                  : context.t.strings.legacy.msg_ok,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recoverBackupPassword() async {
    final payload = await _promptRecoveryReset();
    if (!mounted || payload == null) return;
    final newPassword = payload.password;
    final recoveryCode = payload.recoveryCode;
    try {
      final settings = ref.read(webDavSettingsProvider);
      final accountKey = ref.read(appSessionProvider).valueOrNull?.currentKey;
      final service = ref.read(webDavBackupServiceProvider);
      final newRecoveryCode = await service.recoverBackupPassword(
        settings: settings,
        accountKey: accountKey,
        recoveryCode: recoveryCode,
        newPassword: newPassword,
      );
      await ref
          .read(webDavBackupPasswordRepositoryProvider)
          .write(newPassword);
      if (!_rememberBackupPassword) {
        setState(() => _rememberBackupPassword = true);
        ref.read(webDavSettingsProvider.notifier).setRememberBackupPassword(true);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _backupNow() async {
    final coordinator = ref.read(syncCoordinatorProvider.notifier);
    if (_backupEncryptionMode == WebDavBackupEncryptionMode.plain) {
      await coordinator.requestWebDavBackup(
        reason: SyncRequestReason.manual,
        password: null,
        onExportIssue: _promptBackupExportIssue,
      );
      return;
    }
    final password = await _resolveBackupPassword(confirm: false);
    if (!mounted || password == null) return;
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
        await showDialog<
          ({WebDavBackupExportAction action, bool applyToRemaining})
        >(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: Text(context.t.strings.legacy.msg_backup_failed),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$kindLabel: $targetLabel'),
                      const SizedBox(height: 8),
                      Text(errorText),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: applyToRemaining,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          context.tr(
                            zh: '对后续类似失败应用此操作',
                            en: 'Apply to subsequent similar failures',
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => applyToRemaining = value ?? false);
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => dialogContext.safePop((
                        action: WebDavBackupExportAction.abort,
                        applyToRemaining: applyToRemaining,
                      )),
                      child: Text(context.t.strings.legacy.msg_cancel_2),
                    ),
                    OutlinedButton(
                      onPressed: () => dialogContext.safePop((
                        action: WebDavBackupExportAction.skip,
                        applyToRemaining: applyToRemaining,
                      )),
                      child: Text(context.t.strings.legacy.msg_continue),
                    ),
                    FilledButton(
                      onPressed: () => dialogContext.safePop((
                        action: WebDavBackupExportAction.retry,
                        applyToRemaining: false,
                      )),
                      child: Text(context.t.strings.legacy.msg_retry),
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
    final localLibrary = ref.read(currentLocalLibraryProvider);
    if (localLibrary == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t.strings.legacy.msg_restore_only_available_local_libraries,
          ),
        ),
      );
      return;
    }

    final settings = ref.read(webDavSettingsProvider);
    final accountKey = ref.read(appSessionProvider).valueOrNull?.currentKey;
    final service = ref.read(webDavBackupServiceProvider);

    if (mounted) {
      setState(() {
        _backupRestoring = true;
        _backupRestoreError = null;
      });
    }

    Future<void> handleResult(
      WebDavRestoreResult result,
      Future<WebDavRestoreResult> Function(Map<String, bool>? decisions) retry,
    ) async {
      if (!mounted) return;
      switch (result) {
        case WebDavRestoreSuccess():
          setState(() => _backupRestoreError = null);
          showTopToast(
            context,
            context.t.strings.legacy.msg_restore_completed,
          );
          return;
        case WebDavRestoreSkipped(:final reason):
          if (mounted) {
            setState(() => _backupRestoreError = reason);
          }
          final message = reason == null
              ? context.t.strings.legacy.msg_restore_failed(e: '')
              : _formatBackupError(reason);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          return;
        case WebDavRestoreFailure(:final error):
          if (mounted) {
            setState(() => _backupRestoreError = error);
          }
          final message = _formatBackupError(error);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          return;
        case WebDavRestoreConflict(:final conflicts):
          final decisions = await _resolveLocalScanConflicts(conflicts);
          if (!mounted) return;
          final retried = await retry(decisions);
          await handleResult(retried, retry);
      }
    }

    try {
      if (_backupEncryptionMode == WebDavBackupEncryptionMode.plain) {
        final confirmed =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(context.t.strings.legacy.msg_restore_backup),
                content: Text(
                  context
                      .t
                      .strings
                      .legacy
                      .msg_restoring_overwrite_local_library_files_rebuild,
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
        if (!mounted || !confirmed) return;
        final result = await service.restorePlainBackup(
          settings: settings,
          accountKey: accountKey,
          activeLocalLibrary: localLibrary,
        );
        await handleResult(
          result,
          (decisions) => service.restorePlainBackup(
            settings: settings,
            accountKey: accountKey,
            activeLocalLibrary: localLibrary,
            conflictDecisions: decisions,
          ),
        );
        return;
      }

      final password = await _resolveBackupPassword(confirm: false);
      if (!mounted || password == null) return;

      List<WebDavBackupSnapshotInfo> snapshots;
      try {
        snapshots = await service.listSnapshots(
          settings: settings,
          accountKey: accountKey,
          password: password,
        );
      } catch (e) {
        if (!mounted) return;
        final message = _formatBackupError(e);
        setState(() => _backupRestoreError = e is SyncError ? e : null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      }
      if (!mounted) return;
      if (snapshots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.strings.legacy.msg_no_backups_found)),
        );
        return;
      }

      final selected = await showDialog<WebDavBackupSnapshotInfo>(
        context: context,
        builder: (dialogContext) {
          final media = MediaQuery.of(dialogContext);
          final dialogWidth = math.min(media.size.width - 48, 360.0);
          final dialogHeight = math.min(
            media.size.height * 0.6,
            media.size.height - 48,
          );
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      context.t.strings.legacy.msg_select_backup,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: snapshots.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = snapshots[index];
                        return ListTile(
                          title: Text(
                            _formatTime(DateTime.tryParse(item.createdAt)),
                          ),
                          subtitle: Text(
                            '${item.memosCount} ${context.t.strings.legacy.msg_memo} · ${item.fileCount} ${context.t.strings.legacy.msg_attachments}',
                          ),
                          onTap: () => dialogContext.safePop(item),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => dialogContext.safePop(),
                          child: Text(context.t.strings.legacy.msg_cancel_2),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () =>
                              dialogContext.safePop(snapshots.first),
                          child:
                              Text(context.t.strings.legacy.msg_restore),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (!mounted || selected == null) return;

      final result = await service.restoreSnapshot(
        settings: settings,
        accountKey: accountKey,
        activeLocalLibrary: localLibrary,
        snapshot: selected,
        password: password,
      );
      await handleResult(
        result,
        (decisions) => service.restoreSnapshot(
          settings: settings,
          accountKey: accountKey,
          activeLocalLibrary: localLibrary,
          snapshot: selected,
          password: password,
          conflictDecisions: decisions,
        ),
      );
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

  Future<Map<String, bool>?> _resolveWebDavConflicts(
    List<String> conflicts,
  ) async {
    if (conflicts.isEmpty) return null;
    return showDialog<Map<String, bool>>(
      context: context,
      builder: (context) =>
          _WebDavConflictDialog(conflicts: conflicts),
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
    final result = await ref.read(syncCoordinatorProvider.notifier).requestSync(
          const SyncRequest(
            kind: SyncRequestKind.webDavSync,
            reason: SyncRequestReason.manual,
          ),
        );
    if (!mounted) return;
    if (result is SyncRunConflict) {
      final choices = await _resolveWebDavConflicts(result.conflicts);
      if (!mounted || choices == null) return;
      await ref
          .read(syncCoordinatorProvider.notifier)
          .resolveWebDavConflicts(choices);
    }
  }

  Future<void> _openWebDavLogs() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WebDavLogsScreen()));
    if (mounted) setState(() {});
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(time);
  }

  String _formatLogSubtitle(DebugLogEntry entry) {
    final parts = <String>[];
    final methodUrl = [
      entry.method?.trim(),
      entry.url?.trim(),
    ].whereType<String>().where((v) => v.isNotEmpty).join(' ');
    if (methodUrl.isNotEmpty) {
      parts.add(methodUrl);
    }
    final statusDuration = [
      if (entry.status != null) 'HTTP ${entry.status}',
      if (entry.durationMs != null) '${entry.durationMs}ms',
    ].join(' · ');
    if (statusDuration.trim().isNotEmpty) {
      parts.add(statusDuration);
    }
    final detail = entry.detail?.trim() ?? '';
    if (detail.isNotEmpty) {
      parts.add(detail);
    }
    final error = entry.error?.trim() ?? '';
    if (error.isNotEmpty) {
      parts.add('Error: $error');
    }
    return parts.join(' · ');
  }

  String _backupScheduleLabel(WebDavBackupSchedule schedule) {
    return switch (schedule) {
      WebDavBackupSchedule.manual => context.t.strings.legacy.msg_manual,
      WebDavBackupSchedule.daily => context.t.strings.legacy.msg_daily,
      WebDavBackupSchedule.weekly => context.t.strings.legacy.msg_weekly,
      WebDavBackupSchedule.monthly =>
        context.tr(zh: '每月', en: 'Monthly'),
      WebDavBackupSchedule.onOpen =>
        context.tr(zh: '每次打开', en: 'On app open'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.watch(syncCoordinatorProvider);
    final syncStatus = coordinator.webDavSync;
    final backupStatus = coordinator.webDavBackup;
    final syncErrorText = syncStatus.lastError == null
        ? null
        : _formatSyncError(syncStatus.lastError!);
    final localLibrary = ref.watch(currentLocalLibraryProvider);
    final mirrorLibrary = _resolveBackupMirrorLibrary();
    final usesServerMode = localLibrary == null;
    final backupAvailable = localLibrary != null || mirrorLibrary != null;
    final backupUnavailableHint = usesServerMode
        ? '${context.t.strings.legacy.msg_export} ${context.t.strings.legacy.msg_path}: ${context.t.strings.legacy.msg_not_set}'
        : context.t.strings.legacy.msg_local_library_only;
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
    final serverUrl = _serverUrlController.text.trim();
    final isHttp = serverUrl.startsWith('http://');
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
        title: Text(context.t.strings.legacy.msg_webdav_sync),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: context.t.strings.legacy.msg_sync,
            onPressed: (!_enabled || syncStatus.running) ? null : _syncNow,
            icon: syncStatus.running
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          const SizedBox(width: 4),
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
                    colors: [const Color(0xFF0B0B0B), bg, bg],
                  ),
                ),
              ),
            ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _ToggleCard(
                card: card,
                textMain: textMain,
                textMuted: textMuted,
                label: context.t.strings.legacy.msg_enable_webdav_sync,
                description: context
                    .t
                    .strings
                    .legacy
                    .msg_keep_data_consistent_across_devices,
                value: _enabled,
                onChanged: _setEnabled,
              ),
              const SizedBox(height: 14),
              _NavCard(
                card: card,
                title: context.t.strings.legacy.msg_server_connection,
                subtitle: connectionSubtitle,
                icon: Icons.link_rounded,
                onTap: _openConnectionSettings,
              ),
              const SizedBox(height: 12),
              _NavCard(
                card: card,
                title: context.tr(zh: '备份策略设置', en: 'Backup strategy settings'),
                subtitle: backupSubtitle,
                icon: Icons.cloud_upload_outlined,
                onTap: _openBackupSettings,
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(zh: '备份操作', en: 'Backup actions'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed:
                            (!_enabled || backupBusy) ? null : _backupNow,
                        icon: backupStatus.running
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.backup_outlined),
                        label: Text(
                          backupStatus.running
                              ? context.t.strings.legacy.msg_backing
                              : context.t.strings.legacy.msg_start_backup,
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                          ),
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed:
                            (!_enabled || backupBusy || localLibrary == null)
                                ? null
                                : _restoreBackup,
                        icon: _backupRestoring
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_download_outlined),
                        label: Text(
                          _backupRestoring
                              ? context.t.strings.legacy.msg_restoring
                              : context.t.strings.legacy.msg_restore_cloud,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                          ),
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    if (_backupEncryptionMode ==
                        WebDavBackupEncryptionMode.encrypted)
                      SizedBox(
                        height: 42,
                        child: TextButton(
                          onPressed:
                              (!_enabled || backupBusy)
                                  ? null
                                  : _recoverBackupPassword,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                            ),
                            minimumSize: const Size(0, 42),
                            foregroundColor: isDark
                                ? const Color(0xFFFF8A80)
                                : const Color(0xFFD32F2F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            context
                                .t
                                .strings
                                .legacy
                                .webdav
                                .recover_password_button,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (localLibrary == null) ...[
                const SizedBox(height: 6),
                Text(
                  context
                      .t
                      .strings
                      .legacy
                      .msg_restore_only_available_local_libraries,
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
              if (isHttp || _ignoreTlsErrors) ...[
                const SizedBox(height: 12),
                _WarningCard(
                  text: context
                      .t
                      .strings
                      .legacy
                      .msg_use_https_avoid_ignoring_tls_errors,
                  isDark: isDark,
                ),
              ],
              const SizedBox(height: 16),
              _SyncStatusLine(
                label: context.t.strings.legacy.msg_last_sync,
                value: _formatTime(syncStatus.lastSuccessAt),
                syncing: syncStatus.running,
                textMuted: textMuted,
              ),
              if (syncErrorText != null &&
                  syncErrorText.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  syncErrorText,
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'WebDAV ${context.t.strings.legacy.msg_logs}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<DebugLogEntry>>(
                future: ref.read(webDavLogStoreProvider).list(limit: 1),
                builder: (context, snapshot) {
                  final entries = snapshot.data ?? const <DebugLogEntry>[];
                  final latest =
                      entries.isNotEmpty ? entries.last : null;
                  final subtitle =
                      latest == null ? '' : _formatLogSubtitle(latest);
                  final timeText = latest == null
                      ? null
                      : _formatTime(latest.timestamp.toLocal());
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _openWebDavLogs,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                    color:
                                        Colors.black.withValues(alpha: 0.06),
                                  ),
                                ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                              color: textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    latest?.label ??
                                        context
                                            .t
                                            .strings
                                            .legacy
                                            .msg_no_logs_yet,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: textMain,
                                    ),
                                  ),
                                  if (subtitle.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                  if (timeText != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      timeText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
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
    return AlertDialog(
      title: Text(
        trByLanguageKey(language: language, key: 'legacy.msg_sync_conflicts'),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                trByLanguageKey(
                  language: language,
                  key:
                      'legacy.msg_these_settings_changed_locally_remotely_choose',
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _applyToAll,
                onChanged: _toggleApplyAll,
                title: Text(
                  trByLanguageKey(language: language, key: 'legacy.msg_apply_all'),
                ),
              ),
              if (_applyToAll)
                RadioGroup<bool>(
                  groupValue: _useLocalForAll,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _useLocalForAll = value;
                      for (final name in widget.conflicts) {
                        _choices[name] = value;
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          value: true,
                          title: Text(
                            trByLanguageKey(
                              language: language,
                              key: 'legacy.msg_use_local',
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          value: false,
                          title: Text(
                            trByLanguageKey(
                              language: language,
                              key: 'legacy.msg_use_remote',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_applyToAll)
                ...widget.conflicts.map(
                  (name) => RadioGroup<bool>(
                    groupValue: _choices[name],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _choices[name] = value);
                    },
                    child: Column(
                      children: [
                        const Divider(height: 12),
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          value: true,
                          title: Text(
                            trByLanguageKey(
                              language: language,
                              key: 'legacy.msg_use_local',
                            ),
                          ),
                        ),
                        RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          value: false,
                          title: Text(
                            trByLanguageKey(
                              language: language,
                              key: 'legacy.msg_use_remote',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            trByLanguageKey(language: language, key: 'legacy.msg_cancel_2'),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_choices),
          child: Text(
            trByLanguageKey(language: language, key: 'legacy.msg_apply'),
          ),
        ),
      ],
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
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(
        context,
      ).textTheme.bodySmall?.color?.withValues(alpha: 0.65),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: card,
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
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(icon, size: 18),
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
                color: Theme.of(context).textTheme.bodySmall?.color,
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
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 4,
            value: syncing ? null : 1,
            backgroundColor: textMuted.withValues(alpha: 0.2),
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

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.card,
    required this.label,
    required this.description,
    required this.value,
    required this.textMain,
    required this.textMuted,
    required this.onChanged,
  });

  final Color card;
  final String label;
  final String description;
  final bool value;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
            if (description.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 44),
                child: Text(
                  description,
                  style: TextStyle(fontSize: 12, color: textMuted, height: 1.3),
                ),
              ),
          ],
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedDivider = divider ?? Colors.transparent;
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
            if (showDividers && i > 0)
              Divider(height: 1, color: resolvedDivider),
            children[i],
          ],
        ],
      ),
    );
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
    return ListTile(
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
          Icon(Icons.chevron_right, size: 18, color: textMuted),
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
    this.obscureText = false,
    this.onEditingComplete,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
      ),
      subtitle: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
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
    this.onEditingComplete,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
      ),
      trailing: SizedBox(
        width: 72,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onEditingComplete: onEditingComplete,
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
      ),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.textMain,
    required this.textMuted,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color textMain;
  final Color textMuted;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final color = emphasize ? MemoFlowPalette.primary : textMuted;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          value,
          style: TextStyle(fontSize: 12, color: color, height: 1.3),
        ),
      ),
    );
  }
}

class _WebDavConnectionScreen extends StatefulWidget {
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
  State<_WebDavConnectionScreen> createState() =>
      _WebDavConnectionScreenState();
}

class _WebDavConnectionScreenState extends State<_WebDavConnectionScreen> {
  late WebDavAuthMode _authMode;
  late bool _ignoreTlsErrors;
  bool _obscurePassword = true;

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
    final selected = await showDialog<WebDavAuthMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.t.strings.legacy.msg_auth_mode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Basic'),
              trailing: _authMode == WebDavAuthMode.basic
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavAuthMode.basic,
              ),
            ),
            ListTile(
              title: const Text('Digest'),
              trailing: _authMode == WebDavAuthMode.digest
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavAuthMode.digest,
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _authMode = selected);
    widget.onAuthModeChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(context.t.strings.legacy.msg_server_connection),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            context.t.strings.legacy.msg_basic_settings,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 8),
          _Group(
            card: card,
            divider: divider,
            children: [
              _InputRow(
                label: context.t.strings.legacy.msg_server_url,
                hint: 'https://example.com/dav',
                controller: widget.serverUrlController,
                textMain: textMain,
                textMuted: textMuted,
                keyboardType: TextInputType.url,
                onChanged: widget.onServerUrlChanged,
                onEditingComplete: widget.onServerUrlEditingComplete,
              ),
              _InputRow(
                label: context.t.strings.legacy.msg_username,
                hint: context.t.strings.legacy.msg_enter_username,
                controller: widget.usernameController,
                textMain: textMain,
                textMuted: textMuted,
                onChanged: widget.onUsernameChanged,
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                title: Text(
                  context.t.strings.legacy.msg_password,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                ),
                subtitle: TextField(
                  controller: widget.passwordController,
                  obscureText: _obscurePassword,
                  onChanged: widget.onPasswordChanged,
                  style: TextStyle(
                    color: textMain,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: context.t.strings.legacy.msg_enter_password_2,
                    hintStyle: TextStyle(
                      color: textMuted.withValues(alpha: 0.6),
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
          Text(
            context.t.strings.legacy.msg_auth_settings,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 8),
          _Group(
            card: card,
            divider: divider,
            children: [
              _SelectRow(
                label: context.t.strings.legacy.msg_auth_mode,
                value: _authMode.name.toUpperCase(),
                textMain: textMain,
                textMuted: textMuted,
                onTap: _pickAuthMode,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.t.strings.legacy.msg_advanced_security,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 8),
          _Group(
            card: card,
            divider: divider,
            children: [
              _ToggleRow(
                label: context.t.strings.legacy.msg_ignore_tls_errors,
                value: _ignoreTlsErrors,
                textMain: textMain,
                onChanged: (v) {
                  setState(() => _ignoreTlsErrors = v);
                  widget.onIgnoreTlsChanged(v);
                },
              ),
              _InputRow(
                label: context.t.strings.legacy.msg_root_path,
                hint: '/notes',
                controller: widget.rootPathController,
                textMain: textMain,
                textMuted: textMuted,
                onChanged: widget.onRootPathChanged,
                onEditingComplete: widget.onRootPathEditingComplete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WebDavBackupSettingsScreen extends ConsumerStatefulWidget {
  const _WebDavBackupSettingsScreen({
    required this.backupAvailable,
    required this.backupUnavailableHint,
    required this.usesServerMode,
    required this.backupRestoring,
    required this.backupMirrorPathLabel,
    required this.onPickBackupMirrorPath,
    required this.backupContentConfig,
    required this.backupContentMemos,
    required this.backupEncryptionMode,
    required this.backupPasswordSet,
    required this.backupSchedule,
    required this.backupRetentionController,
    required this.onBackupContentConfigChanged,
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
  final String backupMirrorPathLabel;
  final Future<void> Function() onPickBackupMirrorPath;
  final bool backupContentConfig;
  final bool backupContentMemos;
  final WebDavBackupEncryptionMode backupEncryptionMode;
  final bool backupPasswordSet;
  final WebDavBackupSchedule backupSchedule;
  final TextEditingController backupRetentionController;
  final ValueChanged<bool> onBackupContentConfigChanged;
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
  late bool _backupContentConfig;
  late bool _backupContentMemos;
  late WebDavBackupEncryptionMode _encryptionMode;
  late bool _backupPasswordSet;
  late WebDavBackupSchedule _schedule;

  @override
  void initState() {
    super.initState();
    _backupContentConfig = widget.backupContentConfig;
    _backupContentMemos = widget.backupContentMemos;
    _encryptionMode = widget.backupEncryptionMode;
    _backupPasswordSet = widget.backupPasswordSet;
    _schedule = widget.backupSchedule;
  }

  @override
  void didUpdateWidget(covariant _WebDavBackupSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backupContentConfig != widget.backupContentConfig) {
      _backupContentConfig = widget.backupContentConfig;
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

  void _handleBackupContentConfig(bool value) {
    setState(() => _backupContentConfig = value);
    widget.onBackupContentConfigChanged(value);
  }

  void _handleBackupContentMemos(bool value) {
    setState(() => _backupContentMemos = value);
    widget.onBackupContentMemosChanged(value);
  }

  Future<void> _pickBackupEncryptionMode() async {
    final selected = await showDialog<WebDavBackupEncryptionMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(zh: '备份方式', en: 'Backup mode')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                _encryptionModeLabel(
                  WebDavBackupEncryptionMode.encrypted,
                  dialogContext,
                ),
              ),
              trailing: _encryptionMode == WebDavBackupEncryptionMode.encrypted
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavBackupEncryptionMode.encrypted,
              ),
            ),
            ListTile(
              title: Text(
                _encryptionModeLabel(
                  WebDavBackupEncryptionMode.plain,
                  dialogContext,
                ),
              ),
              trailing: _encryptionMode == WebDavBackupEncryptionMode.plain
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavBackupEncryptionMode.plain,
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _encryptionMode = selected);
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
    final action =
        await showDialog<_BackupPasswordExitAction>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              context.tr(zh: '备份密码未设置', en: 'Backup password missing'),
            ),
            content: Text(
              context.tr(
                zh: '加密备份需要设置密码，是否现在设置？',
                en: 'Encrypted backup requires a password. Set it now?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(
                  _BackupPasswordExitAction.abandon,
                ),
                child: Text(context.tr(zh: '放弃设置', en: 'Abandon')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _BackupPasswordExitAction.setup,
                ),
                child: Text(context.tr(zh: '去设置', en: 'Set now')),
              ),
            ],
          ),
        );
    if (!mounted || action == null) return false;
    if (action == _BackupPasswordExitAction.setup) {
      await _handleSetupBackupPassword();
      return _backupPasswordSet;
    }
    setState(() => _encryptionMode = WebDavBackupEncryptionMode.plain);
    widget.onBackupEncryptionModeChanged(WebDavBackupEncryptionMode.plain);
    return true;
  }

  Future<void> _pickSchedule() async {
    final selected = await showDialog<WebDavBackupSchedule>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.strings.legacy.msg_backup_schedule),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(context.t.strings.legacy.msg_manual),
              trailing: _schedule == WebDavBackupSchedule.manual
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavBackupSchedule.manual,
              ),
            ),
            ListTile(
              title: Text(context.t.strings.legacy.msg_daily),
              trailing: _schedule == WebDavBackupSchedule.daily
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavBackupSchedule.daily,
              ),
            ),
            ListTile(
              title: Text(context.t.strings.legacy.msg_weekly),
              trailing: _schedule == WebDavBackupSchedule.weekly
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavBackupSchedule.weekly,
              ),
            ),
            ListTile(
              title: Text(dialogContext.tr(zh: '每月', en: 'Monthly')),
              trailing: _schedule == WebDavBackupSchedule.monthly
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavBackupSchedule.monthly,
              ),
            ),
            ListTile(
              title: Text(dialogContext.tr(zh: '每次打开', en: 'On app open')),
              trailing: _schedule == WebDavBackupSchedule.onOpen
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(
                WebDavBackupSchedule.onOpen,
              ),
            ),
          ],
        ),
      ),
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
      WebDavBackupSchedule.monthly =>
        context.tr(zh: '每月', en: 'Monthly'),
      WebDavBackupSchedule.onOpen =>
        context.tr(zh: '每次打开', en: 'On app open'),
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

  @override
  Widget build(BuildContext context) {
    final backupStatus = ref.watch(syncCoordinatorProvider).webDavBackup;
    final backupErrorText = backupStatus.lastError == null
        ? null
        : presentSyncError(
            language: context.appLanguage,
            error: backupStatus.lastError!,
          );
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
    final backupPathUnavailable =
        _backupContentMemos && !widget.backupAvailable;
    final busy = backupStatus.running || widget.backupRestoring;

    return WillPopScope(
      onWillPop: _handleExitGuard,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: context.t.strings.legacy.msg_back,
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final allow = await _handleExitGuard();
              if (!mounted || !allow) return;
              Navigator.of(context).maybePop();
            },
          ),
          title: Text(context.t.strings.legacy.msg_backup_settings),
          centerTitle: false,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (widget.usesServerMode) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF4A2F00).withValues(alpha: 0.45)
                      : const Color(0xFFFFF3D9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFFFFC36A).withValues(alpha: 0.6)
                        : const Color(0xFFE8A23D),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: isDark
                          ? const Color(0xFFFFC36A)
                          : const Color(0xFF9A5A00),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr(
                          zh:
                              '服务器模式下，WebDAV 备份会先在本地目录生成 Markdown（.md）文件和附件镜像，再上传到 WebDAV。',
                          en:
                              'In server mode, WebDAV backup first generates local Markdown (.md) files and attachment mirrors, then uploads them.',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: isDark
                              ? const Color(0xFFFFE0B2)
                              : const Color(0xFF6A3D00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${context.t.strings.legacy.msg_export} ${context.t.strings.legacy.msg_path}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 8),
              _Group(
                card: card,
                divider: divider,
                showDividers: false,
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    dense: true,
                    title: Text(
                      context.t.strings.legacy.msg_path,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textMain,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        widget.backupMirrorPathLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: textMuted,
                          height: 1.3,
                        ),
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: widget.onPickBackupMirrorPath,
                      child: Text(context.t.strings.legacy.msg_select),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Text(
              context.tr(zh: '备份内容', en: 'Backup content'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 8),
            _Group(
              card: card,
              divider: divider,
              showDividers: false,
              children: [
                _ToggleRow(
                  label: context.tr(zh: '备份配置', en: 'Backup config'),
                  value: _backupContentConfig,
                  textMain: textMain,
                  onChanged: busy ? null : _handleBackupContentConfig,
                ),
                _ToggleRow(
                  label: context.tr(zh: '备份笔记', en: 'Backup memos'),
                  value: _backupContentMemos,
                  textMain: textMain,
                  onChanged: busy ? null : _handleBackupContentMemos,
                ),
              ],
            ),
            if (backupPathUnavailable) ...[
              const SizedBox(height: 6),
              Text(
                widget.backupUnavailableHint,
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              context.t.strings.legacy.msg_local_library_backup,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 8),
            _Group(
              card: card,
              divider: divider,
              showDividers: false,
              children: [
                _SelectRow(
                  label: context.tr(zh: '备份方式', en: 'Backup mode'),
                  value: _encryptionModeLabel(_encryptionMode, context),
                  textMain: textMain,
                  textMuted: textMuted,
                  onTap: busy ? null : _pickBackupEncryptionMode,
                ),
                if (_encryptionMode == WebDavBackupEncryptionMode.encrypted)
                  _SelectRow(
                    label: context.tr(zh: '设置密码', en: 'Set password'),
                    value: _backupPasswordSet
                        ? context.tr(zh: '已设置', en: 'Set')
                        : context.t.strings.legacy.msg_not_set,
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: busy ? null : _handleSetupBackupPassword,
                  ),
                _SelectRow(
                  label: context.t.strings.legacy.msg_backup_schedule,
                  value: _scheduleLabel(_schedule, context),
                  textMain: textMain,
                  textMuted: textMuted,
                  onTap: busy ? null : _pickSchedule,
                ),
                _InlineInputRow(
                  label: context.t.strings.legacy.msg_retention,
                  hint: '5',
                  controller: widget.backupRetentionController,
                  textMain: textMain,
                  textMuted: textMuted,
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
              style: TextStyle(fontSize: 12, height: 1.4, color: textMuted),
            ),
            if (backupErrorText != null &&
                backupErrorText.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                backupErrorText,
                style: TextStyle(fontSize: 12, color: textMuted),
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
    final lines = <String>[
      _timeFormat.format(entry.timestamp.toLocal()),
    ];
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
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(entry.label),
        content: SingleChildScrollView(
          child: SelectableText(lines.join('\n')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t.strings.legacy.msg_close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final items = _entries.reversed.toList(growable: false);

    Widget body;
    if (_loading && items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty) {
      body = Center(
        child: Text(
          context.t.strings.legacy.msg_no_logs_yet,
          style: TextStyle(color: textMuted),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                    color: isDark
                        ? MemoFlowPalette.cardDark
                        : MemoFlowPalette.cardLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _entrySubtitle(entry),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: textMuted),
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
        title: Text('WebDAV ${context.t.strings.legacy.msg_logs}'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: context.t.strings.legacy.msg_refresh,
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: body,
    );
  }
}

enum _BackupPasswordExitAction { setup, abandon }
