import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../core/webdav_url.dart';
import '../../data/models/webdav_backup.dart';
import '../../data/models/webdav_settings.dart';
import '../../state/local_library_provider.dart';
import '../../state/webdav_backup_provider.dart';
import '../../state/webdav_settings_provider.dart';
import '../../state/webdav_sync_provider.dart';

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
  var _backupEnabled = false;
  var _backupSchedule = WebDavBackupSchedule.daily;
  var _rememberBackupPassword = false;
  var _dirty = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(webDavSettingsProvider);
    _applySettings(settings);
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
    _backupEnabled = settings.backupEnabled;
    _backupSchedule = settings.backupSchedule;
    _backupRetentionController.text = settings.backupRetentionCount.toString();
    _rememberBackupPassword = settings.rememberBackupPassword;
    setState(() {});
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  Future<void> _selectAuthMode(BuildContext sheetContext) async {
    final selected = await showModalBottomSheet<WebDavAuthMode>(
      context: sheetContext,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Basic'),
              trailing: _authMode == WebDavAuthMode.basic
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => context.safePop(WebDavAuthMode.basic),
            ),
            ListTile(
              title: const Text('Digest'),
              trailing: _authMode == WebDavAuthMode.digest
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => context.safePop(WebDavAuthMode.digest),
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
    final selected = await showModalBottomSheet<WebDavBackupSchedule>(
      context: sheetContext,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(context.tr(zh: '手动', en: 'Manual')),
              trailing: _backupSchedule == WebDavBackupSchedule.manual
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => context.safePop(WebDavBackupSchedule.manual),
            ),
            ListTile(
              title: Text(context.tr(zh: '每天', en: 'Daily')),
              trailing: _backupSchedule == WebDavBackupSchedule.daily
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => context.safePop(WebDavBackupSchedule.daily),
            ),
            ListTile(
              title: Text(context.tr(zh: '每周', en: 'Weekly')),
              trailing: _backupSchedule == WebDavBackupSchedule.weekly
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => context.safePop(WebDavBackupSchedule.weekly),
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
    ref.read(webDavSettingsProvider.notifier).setEnabled(value);
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

  Future<bool> _toggleBackupEnabled(bool value) async {
    if (value) {
      final password = await _promptBackupPassword(confirm: true);
      if (!mounted || password == null) return false;
      if (_rememberBackupPassword) {
        await ref.read(webDavBackupPasswordRepositoryProvider).write(password);
      }
    }
    setState(() => _backupEnabled = value);
    ref.read(webDavSettingsProvider.notifier).setBackupEnabled(value);
    return value;
  }

  Future<bool> _setRememberBackupPassword(bool value) async {
    if (value) {
      final password = await _promptBackupPassword(confirm: false);
      if (!mounted || password == null) return false;
      final verified = await _verifyBackupPassword(password);
      if (!mounted || !verified) return false;
      setState(() => _rememberBackupPassword = true);
      ref.read(webDavSettingsProvider.notifier).setRememberBackupPassword(true);
      await ref.read(webDavBackupPasswordRepositoryProvider).write(password);
      return true;
    }

    setState(() => _rememberBackupPassword = false);
    ref.read(webDavSettingsProvider.notifier).setRememberBackupPassword(false);
    await ref.read(webDavBackupPasswordRepositoryProvider).clear();
    return false;
  }

  void _setBackupRetention(String value) {
    _markDirty();
    final parsed = int.tryParse(value.trim());
    if (parsed != null) {
      ref.read(webDavSettingsProvider.notifier).setBackupRetentionCount(parsed);
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _WebDavBackupSettingsScreen(
          backupEnabled: _backupEnabled,
          backupAvailable: ref.read(currentLocalLibraryProvider) != null,
          backupSchedule: _backupSchedule,
          rememberBackupPassword: _rememberBackupPassword,
          backupRetentionController: _backupRetentionController,
          onBackupEnabledChanged: _toggleBackupEnabled,
          onRememberPasswordChanged: _setRememberBackupPassword,
          onBackupScheduleChanged: _setBackupSchedule,
          onBackupRetentionChanged: _setBackupRetention,
          onBackupNow: _backupNow,
          onRestore: _restoreBackup,
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
            title: Text(context.tr(zh: '备份密码', en: 'Backup password')),
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
                    hintText: context.tr(
                      zh: '请输入备份密码',
                      en: 'Enter backup password',
                    ),
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
                      hintText: context.tr(
                        zh: '再次输入确认',
                        en: 'Confirm password',
                      ),
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
                child: Text(context.tr(zh: '取消', en: 'Cancel')),
              ),
              FilledButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  context.safePop(true);
                },
                child: Text(context.tr(zh: '确认', en: 'Confirm')),
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
          content: Text(
            context.tr(zh: '两次密码不一致', en: 'Passwords do not match'),
          ),
        ),
      );
      return null;
    }
    return password;
  }

  Future<String?> _resolveBackupPassword({required bool confirm}) async {
    final repo = ref.read(webDavBackupPasswordRepositoryProvider);
    final stored = await repo.read();
    if (stored != null && stored.trim().isNotEmpty) return stored;
    final entered = await _promptBackupPassword(confirm: confirm);
    if (entered == null || entered.trim().isEmpty) return null;
    if (_rememberBackupPassword) {
      await repo.write(entered);
    }
    return entered;
  }

  Future<bool> _verifyBackupPassword(String password) async {
    try {
      await ref
          .read(webDavBackupControllerProvider.notifier)
          .listSnapshots(password: password);
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

  Future<void> _backupNow() async {
    final password = await _resolveBackupPassword(confirm: false);
    if (!mounted || password == null) return;
    await ref
        .read(webDavBackupControllerProvider.notifier)
        .backupNow(password: password, manual: true);
  }

  Future<void> _restoreBackup() async {
    final localLibrary = ref.read(currentLocalLibraryProvider);
    if (localLibrary == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              zh: '仅本地库可恢复备份',
              en: 'Restore is only available for local libraries.',
            ),
          ),
        ),
      );
      return;
    }
    final password = await _resolveBackupPassword(confirm: false);
    if (!mounted || password == null) return;

    List<WebDavBackupSnapshotInfo> snapshots;
    try {
      snapshots = await ref
          .read(webDavBackupControllerProvider.notifier)
          .listSnapshots(password: password);
    } catch (e) {
      if (!mounted) return;
      final message = _formatBackupError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!mounted) return;
    if (snapshots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(zh: '暂无备份记录', en: 'No backups found')),
        ),
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
                    context.tr(zh: '选择备份', en: 'Select backup'),
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
                          '${item.memosCount} memos | ${item.fileCount} files | ${item.totalBytes} bytes',
                        ),
                        onTap: () => Navigator.of(dialogContext).pop(item),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(context.tr(zh: '取消', en: 'Cancel')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr(zh: '恢复备份？', en: 'Restore backup?')),
            content: Text(
              context.tr(
                zh: '恢复会覆盖本地库文件，并重新导入数据库。此操作无法撤销。',
                en: 'Restoring will overwrite local library files and rebuild the database. This cannot be undone.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => context.safePop(false),
                child: Text(context.tr(zh: '取消', en: 'Cancel')),
              ),
              FilledButton(
                onPressed: () => context.safePop(true),
                child: Text(context.tr(zh: '确认', en: 'Confirm')),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !confirmed) return;
    try {
      await ref
          .read(webDavBackupControllerProvider.notifier)
          .restoreSnapshot(
            context: context,
            snapshot: selected,
            password: password,
          );
    } catch (e) {
      if (!mounted) return;
      final message = _formatBackupError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!mounted) return;
    final status = ref.read(webDavBackupControllerProvider);
    final lastError = status.lastError?.trim() ?? '';
    if (lastError.isNotEmpty) {
      final message = _formatBackupError(lastError);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    showTopToast(
      context,
      context.tr(zh: '恢复完成', en: 'Restore completed'),
    );
  }

  String _formatBackupError(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return context.tr(zh: '备份失败', en: 'Backup failed');
    }
    const prefix = 'Bad state:';
    if (raw.startsWith(prefix)) {
      final trimmed = raw.substring(prefix.length).trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return raw;
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
    await ref
        .read(webDavSyncControllerProvider.notifier)
        .syncNow(context: context);
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(time);
  }

  String _backupScheduleLabel(WebDavBackupSchedule schedule) {
    return switch (schedule) {
      WebDavBackupSchedule.manual => context.tr(zh: '手动', en: 'Manual'),
      WebDavBackupSchedule.daily => context.tr(zh: '每天', en: 'Daily'),
      WebDavBackupSchedule.weekly => context.tr(zh: '每周', en: 'Weekly'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(webDavSyncControllerProvider);
    final localLibrary = ref.watch(currentLocalLibraryProvider);
    final backupAvailable = localLibrary != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final serverUrl = _serverUrlController.text.trim();
    final isHttp = serverUrl.startsWith('http://');
    final connectionSubtitle = serverUrl.isEmpty
        ? context.tr(zh: '未设置', en: 'Not set')
        : serverUrl;
    final retentionText = _backupRetentionController.text.trim();
    final retentionValue = retentionText.isEmpty ? '5' : retentionText;
    final backupSubtitle = !backupAvailable
        ? context.tr(zh: '仅本地库可用', en: 'Local library only')
        : _backupEnabled
        ? '${_backupScheduleLabel(_backupSchedule)} \u00b7 $retentionValue'
        : context.tr(zh: '未启用', en: 'Disabled');

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
        title: Text(context.tr(zh: 'WebDAV 同步', en: 'WebDAV Sync')),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: context.tr(zh: '同步', en: 'Sync'),
            onPressed: (!_enabled || syncStatus.syncing) ? null : _syncNow,
            icon: syncStatus.syncing
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
                label: context.tr(zh: '启用 WebDAV 同步', en: 'Enable WebDAV sync'),
                description: context.tr(
                  zh: '保持设备间数据一致。',
                  en: 'Keep data consistent across devices.',
                ),
                value: _enabled,
                onChanged: _setEnabled,
              ),
              const SizedBox(height: 14),
              _NavCard(
                card: card,
                title: context.tr(zh: '服务器连接', en: 'Server connection'),
                subtitle: connectionSubtitle,
                icon: Icons.link_rounded,
                onTap: _openConnectionSettings,
              ),
              const SizedBox(height: 12),
              _NavCard(
                card: card,
                title: context.tr(zh: '自动备份', en: 'Auto backup'),
                subtitle: backupSubtitle,
                icon: Icons.cloud_upload_outlined,
                onTap: _openBackupSettings,
              ),
              if (isHttp || _ignoreTlsErrors) ...[
                const SizedBox(height: 12),
                _WarningCard(
                  text: context.tr(
                    zh: '为了安全，建议使用 HTTPS，且避免忽略证书校验。',
                    en: 'Use HTTPS and avoid ignoring TLS errors to protect credentials.',
                  ),
                  isDark: isDark,
                ),
              ],
              const SizedBox(height: 16),
              _SyncStatusLine(
                label: context.tr(zh: '上次同步', en: 'Last sync'),
                value: _formatTime(syncStatus.lastSuccessAt),
                syncing: syncStatus.syncing,
                textMuted: textMuted,
              ),
              if (syncStatus.lastError != null &&
                  syncStatus.lastError!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  syncStatus.lastError!,
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ],
          ),
        ],
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
            if (i > 0) Divider(height: 1, color: divider),
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
  final VoidCallback onTap;

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
    final selected = await showModalBottomSheet<WebDavAuthMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Basic'),
              trailing: _authMode == WebDavAuthMode.basic
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => context.safePop(WebDavAuthMode.basic),
            ),
            ListTile(
              title: const Text('Digest'),
              trailing: _authMode == WebDavAuthMode.digest
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => context.safePop(WebDavAuthMode.digest),
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
          tooltip: context.tr(zh: '返回', en: 'Back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.tr(zh: '服务器连接', en: 'Server connection')),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            context.tr(zh: '基础设置', en: 'Basic settings'),
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
                label: context.tr(zh: '服务器地址', en: 'Server URL'),
                hint: 'https://example.com/dav',
                controller: widget.serverUrlController,
                textMain: textMain,
                textMuted: textMuted,
                keyboardType: TextInputType.url,
                onChanged: widget.onServerUrlChanged,
                onEditingComplete: widget.onServerUrlEditingComplete,
              ),
              _InputRow(
                label: context.tr(zh: '用户名', en: 'Username'),
                hint: context.tr(zh: '请输入用户名', en: 'Enter username'),
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
                  context.tr(zh: '密码', en: 'Password'),
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
                    hintText: context.tr(zh: '请输入密码', en: 'Enter password'),
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
            context.tr(zh: '认证设置', en: 'Auth settings'),
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
                label: context.tr(zh: '认证方式', en: 'Auth mode'),
                value: _authMode.name.toUpperCase(),
                textMain: textMain,
                textMuted: textMuted,
                onTap: _pickAuthMode,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(zh: '高级与安全', en: 'Advanced & security'),
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
                label: context.tr(zh: '忽略证书校验', en: 'Ignore TLS errors'),
                value: _ignoreTlsErrors,
                textMain: textMain,
                onChanged: (v) {
                  setState(() => _ignoreTlsErrors = v);
                  widget.onIgnoreTlsChanged(v);
                },
              ),
              _InputRow(
                label: context.tr(zh: '根路径', en: 'Root path'),
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
    required this.backupEnabled,
    required this.backupAvailable,
    required this.backupSchedule,
    required this.rememberBackupPassword,
    required this.backupRetentionController,
    required this.onBackupEnabledChanged,
    required this.onRememberPasswordChanged,
    required this.onBackupScheduleChanged,
    required this.onBackupRetentionChanged,
    required this.onBackupNow,
    required this.onRestore,
  });

  final bool backupEnabled;
  final bool backupAvailable;
  final WebDavBackupSchedule backupSchedule;
  final bool rememberBackupPassword;
  final TextEditingController backupRetentionController;
  final Future<bool> Function(bool value) onBackupEnabledChanged;
  final Future<bool> Function(bool value) onRememberPasswordChanged;
  final ValueChanged<WebDavBackupSchedule> onBackupScheduleChanged;
  final ValueChanged<String> onBackupRetentionChanged;
  final Future<void> Function() onBackupNow;
  final Future<void> Function() onRestore;

  @override
  ConsumerState<_WebDavBackupSettingsScreen> createState() =>
      _WebDavBackupSettingsScreenState();
}

class _WebDavBackupSettingsScreenState
    extends ConsumerState<_WebDavBackupSettingsScreen> {
  late bool _backupEnabled;
  late bool _rememberPassword;
  late WebDavBackupSchedule _schedule;
  bool _toggleBusy = false;

  @override
  void initState() {
    super.initState();
    _backupEnabled = widget.backupEnabled;
    _rememberPassword = widget.rememberBackupPassword;
    _schedule = widget.backupSchedule;
  }

  @override
  void didUpdateWidget(covariant _WebDavBackupSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backupEnabled != widget.backupEnabled) {
      _backupEnabled = widget.backupEnabled;
    }
    if (oldWidget.rememberBackupPassword != widget.rememberBackupPassword) {
      _rememberPassword = widget.rememberBackupPassword;
    }
    if (oldWidget.backupSchedule != widget.backupSchedule) {
      _schedule = widget.backupSchedule;
    }
  }

  Future<void> _handleBackupToggle(bool value) async {
    if (_toggleBusy) return;
    setState(() => _toggleBusy = true);
    final next = await widget.onBackupEnabledChanged(value);
    if (!mounted) return;
    setState(() {
      _backupEnabled = next;
      _toggleBusy = false;
    });
  }

  Future<void> _handleRememberPassword(bool value) async {
    final next = await widget.onRememberPasswordChanged(value);
    if (!mounted) return;
    setState(() => _rememberPassword = next);
  }

  Future<void> _pickSchedule() async {
    final selected = await showModalBottomSheet<WebDavBackupSchedule>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(context.tr(zh: '手动', en: 'Manual')),
              trailing: _schedule == WebDavBackupSchedule.manual
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => context.safePop(WebDavBackupSchedule.manual),
            ),
            ListTile(
              title: Text(context.tr(zh: '每天', en: 'Daily')),
              trailing: _schedule == WebDavBackupSchedule.daily
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => context.safePop(WebDavBackupSchedule.daily),
            ),
            ListTile(
              title: Text(context.tr(zh: '每周', en: 'Weekly')),
              trailing: _schedule == WebDavBackupSchedule.weekly
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => context.safePop(WebDavBackupSchedule.weekly),
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
      WebDavBackupSchedule.manual => context.tr(zh: '手动', en: 'Manual'),
      WebDavBackupSchedule.daily => context.tr(zh: '每天', en: 'Daily'),
      WebDavBackupSchedule.weekly => context.tr(zh: '每周', en: 'Weekly'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final backupStatus = ref.watch(webDavBackupControllerProvider);
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
    final disabled = !widget.backupAvailable;
    final busy = backupStatus.running || backupStatus.restoring;

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
        title: Text(context.tr(zh: '备份设置', en: 'Backup settings')),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            context.tr(zh: '本地库备份', en: 'Local library backup'),
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
                label: context.tr(
                  zh: '启用本地库备份',
                  en: 'Enable local library backup',
                ),
                value: _backupEnabled,
                textMain: textMain,
                onChanged: disabled ? null : _handleBackupToggle,
              ),
              _ToggleRow(
                label: context.tr(zh: '记住密码', en: 'Remember password'),
                value: _rememberPassword,
                textMain: textMain,
                onChanged: disabled ? null : _handleRememberPassword,
              ),
            ],
          ),
          if (disabled) ...[
            const SizedBox(height: 6),
            Text(
              context.tr(zh: '仅本地库可用', en: 'Local library only'),
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            context.tr(zh: '同步参数', en: 'Sync parameters'),
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
                label: context.tr(zh: '备份频率', en: 'Backup schedule'),
                value: _scheduleLabel(_schedule, context),
                textMain: textMain,
                textMuted: textMuted,
                onTap: _pickSchedule,
              ),
              _InputRow(
                label: context.tr(zh: '版本保留数量', en: 'Retention'),
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
            context.tr(
              zh: '增加保留数量会占用更多存储空间，建议定期清理旧版本。',
              en: 'Keeping more versions uses more storage. Consider cleaning old versions.',
            ),
            style: TextStyle(fontSize: 12, height: 1.4, color: textMuted),
          ),
          if (backupStatus.lastError != null &&
              backupStatus.lastError!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              backupStatus.lastError!,
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 46,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: disabled || busy ? null : () => widget.onBackupNow(),
                icon: busy && backupStatus.running
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.backup_outlined),
                label: Text(
                  backupStatus.running
                      ? context.tr(zh: '备份中…', en: 'Backing up…')
                      : context.tr(zh: '开始备份', en: 'Start backup'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MemoFlowPalette.primary,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: disabled || busy ? null : () => widget.onRestore(),
                icon: backupStatus.restoring
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download_outlined),
                label: Text(
                  backupStatus.restoring
                      ? context.tr(zh: '恢复中…', en: 'Restoring…')
                      : context.tr(zh: '从云端恢复', en: 'Restore from cloud'),
                ),
                style: OutlinedButton.styleFrom(
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
