part of 'webdav_sync_screen.dart';

class VaultSecurityStatusScreen extends ConsumerStatefulWidget {
  const VaultSecurityStatusScreen({super.key});

  @override
  ConsumerState<VaultSecurityStatusScreen> createState() =>
      _VaultSecurityStatusScreenState();
}

class _VaultSecurityStatusScreenState
    extends ConsumerState<VaultSecurityStatusScreen> {
  WebDavSyncMeta? _remoteMeta;
  WebDavVaultState _vaultState = WebDavVaultState.defaults;
  WebDavExportStatus? _exportStatus;
  final _timeFormat = DateFormat('yyyy-MM-dd HH:mm');
  bool _loading = true;
  bool _loadingInFlight = false;
  bool _reminderShown = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    if (_loadingInFlight) return;
    _loadingInFlight = true;
    setState(() => _loading = true);
    try {
      final meta = await ref
          .read(syncCoordinatorProvider.notifier)
          .fetchWebDavSyncMeta();
      final exportStatus = await ref
          .read(syncCoordinatorProvider.notifier)
          .fetchWebDavExportStatus();
      final vaultState =
          await ref.read(webDavVaultStateRepositoryProvider).read();
      if (!mounted) return;
      setState(() {
        _remoteMeta = meta;
        _vaultState = vaultState;
        _exportStatus = exportStatus;
        _loading = false;
      });
      _maybeShowCleanupReminder();
    } on SyncError catch (error) {
      _handleLoadError(error);
    } catch (error) {
      _handleLoadError(error);
    } finally {
      _loadingInFlight = false;
    }
  }

  void _handleLoadError(Object error) {
    if (!mounted) return;
    setState(() => _loading = false);
    if (kDebugMode) {
      debugPrint('Vault status load failed: $error');
    }
    final message =
        error is SyncError
            ? presentSyncError(language: context.appLanguage, error: error)
            : context.tr(
                zh: 'WebDAV 请求失败',
                en: 'WebDAV request failed',
              );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: context.tr(zh: '重试', en: 'Retry'),
          onPressed: _loadStatus,
        ),
      ),
    );
  }

  void _maybeShowCleanupReminder() {
    if (_reminderShown) return;
    final meta = _remoteMeta;
    if (meta != null && meta.deprecatedFiles.isNotEmpty) {
      final remindAfterRaw = meta.deprecatedRemindAfter ?? '';
      final remindAfter = DateTime.tryParse(remindAfterRaw);
      if (remindAfter != null &&
          !DateTime.now().toUtc().isBefore(remindAfter)) {
        _reminderShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    context.tr(zh: '清理远端明文', en: 'Clean remote plaintext'),
                  ),
                  content: Text(
                    context.tr(
                      zh: '检测到旧明文文件，是否清理？',
                      en:
                          'Legacy plaintext files were detected. Clean them now?',
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
          if (confirm) {
            await _handleCleanRemotePlain();
          }
        });
        return;
      }
    }

    final exportStatus = _exportStatus;
    if (exportStatus == null || !exportStatus.plainDeprecated) return;
    final remindAfterRaw = exportStatus.plainRemindAfter ?? '';
    final remindAfter = DateTime.tryParse(remindAfterRaw);
    if (remindAfter == null) return;
    if (DateTime.now().toUtc().isBefore(remindAfter)) return;
    _reminderShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                context.tr(zh: '清理导出明文', en: 'Clean export plaintext'),
              ),
              content: Text(
                context.tr(
                  zh: '检测到旧明文导出，是否清理？',
                  en:
                      'Legacy plaintext export was detected. Clean it now?',
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
      if (confirm) {
        await _handleCleanExportPlain();
      }
    });
  }

  Future<void> _handleCleanRemotePlain() async {
    final cleaned = await ref
        .read(syncCoordinatorProvider.notifier)
        .cleanWebDavDeprecatedPlainFiles();
    if (!mounted) return;
    if (cleaned == null) {
      showTopToast(
        context,
        context.tr(zh: '未检测到明文文件', en: 'No plaintext files detected'),
      );
      return;
    }
    await _loadStatus();
    showTopToast(
      context,
      context.tr(zh: '远端明文已清理', en: 'Remote plaintext cleaned'),
    );
  }

  Future<void> _handleCleanExportPlain() async {
    final result = await ref
        .read(syncCoordinatorProvider.notifier)
        .cleanWebDavPlainExport();
    if (!mounted) return;
    if (result == WebDavExportCleanupStatus.blocked) {
      showTopToast(
        context,
        context.tr(
          zh: '请先完成加密导出/上传',
          en: 'Complete an encrypted export/upload first',
        ),
      );
      return;
    }
    if (result == WebDavExportCleanupStatus.notFound) {
      showTopToast(
        context,
        context.tr(zh: '未检测到导出明文', en: 'No plaintext export detected'),
      );
      return;
    }
    await _loadStatus();
    showTopToast(
      context,
      context.tr(zh: '导出明文已清理', en: 'Plaintext export cleaned'),
    );
  }

  Future<String?> _promptVaultPassword({required String title}) async {
    var password = '';
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: TextField(
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(
                hintText:
                    context.tr(zh: '请输入 Vault 密码', en: 'Enter Vault password'),
              ),
              onChanged: (value) => password = value,
              onSubmitted: (_) => dialogContext.safePop(true),
            ),
            actions: [
              TextButton(
                onPressed: () => dialogContext.safePop(false),
                child: Text(context.tr(zh: '取消', en: 'Cancel')),
              ),
              FilledButton(
                onPressed: () => dialogContext.safePop(true),
                child: Text(context.tr(zh: '确认', en: 'Confirm')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return null;
    password = password.trim();
    if (password.isEmpty) return null;
    return password;
  }

  Future<bool> _verifyVaultPassword(String password) async {
    try {
      final settings = ref.read(webDavSettingsProvider);
      final accountKey = ref.read(appSessionProvider).valueOrNull?.currentKey;
      if (accountKey == null || accountKey.trim().isEmpty) return false;
      final vaultService = ref.read(webDavVaultServiceProvider);
      final config = await vaultService.loadConfig(
        settings: settings,
        accountKey: accountKey,
      );
      if (config == null) return false;
      await vaultService.resolveMasterKey(password, config);
      return true;
    } on SyncError catch (error) {
      if (!mounted) return false;
      final message = presentSyncError(
        language: context.appLanguage,
        error: error,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
      return false;
    }
  }

  Future<void> _handleViewRecoveryCode() async {
    final password = await _promptVaultPassword(
      title: context.tr(
        zh: '验证 Vault 密码',
        en: 'Verify Vault password',
      ),
    );
    if (!mounted || password == null) return;
    final verified = await _verifyVaultPassword(password);
    if (!mounted || !verified) return;

    final recovery =
        await ref.read(webDavVaultRecoveryRepositoryProvider).read();
    if (!mounted) return;
    if (recovery == null || recovery.trim().isEmpty) {
      showTopToast(
        context,
        context.tr(
          zh: '本机未保存恢复码',
          en: 'Recovery code is not stored on this device',
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(zh: 'Vault 恢复码', en: 'Vault recovery code')),
        content: SelectableText(
          recovery,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: recovery));
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  content: Text(
                    context.tr(zh: '恢复码已复制', en: 'Recovery code copied'),
                  ),
                ),
              );
            },
            child: Text(context.tr(zh: '复制', en: 'Copy')),
          ),
          FilledButton(
            onPressed: () => dialogContext.safePop(),
            child: Text(context.tr(zh: '确定', en: 'OK')),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBackupTest() async {
    final mode = await showDialog<_BackupTestMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr(zh: '备份恢复测试', en: 'Backup restore test')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(context.tr(zh: '快速验证', en: 'Quick verify')),
              subtitle: Text(
                context.tr(
                  zh: '解密索引与快照，不落盘',
                  en: 'Decrypt index and snapshot without writing files',
                ),
              ),
              onTap: () => Navigator.of(context).pop(_BackupTestMode.quick),
            ),
            ListTile(
              title: Text(context.tr(zh: '完整恢复（高级）', en: 'Full restore (advanced)')),
              subtitle: Text(
                context.tr(
                  zh: '解密全部对象并执行临时写入',
                  en: 'Decrypt all objects with temporary writes',
                ),
              ),
              onTap: () => Navigator.of(context).pop(_BackupTestMode.deep),
            ),
          ],
        ),
      ),
    );
    if (!mounted || mode == null) return;

    String? password;
    final stored = await ref.read(webDavVaultPasswordRepositoryProvider).read();
    if (stored != null && stored.trim().isNotEmpty) {
      password = stored;
    } else {
      password = await _promptVaultPassword(
        title: context.tr(
          zh: '请输入 Vault 密码',
          en: 'Enter Vault password',
        ),
      );
    }
    if (!mounted || password == null || password.trim().isEmpty) return;

    final error = await ref
        .read(syncCoordinatorProvider.notifier)
        .verifyWebDavBackup(password: password, deep: mode == _BackupTestMode.deep);
    if (!mounted) return;
    if (error == null) {
      showTopToast(
        context,
        context.tr(zh: '备份验证成功', en: 'Backup verified successfully'),
      );
      return;
    }
    final message = presentSyncError(
      language: context.appLanguage,
      error: error,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _setLocalPlainCache(bool value) {
    ref.read(webDavSettingsProvider.notifier).setVaultKeepPlainCache(value);
    setState(() {});
  }

  Future<void> _handleClearLocalPlainCache() async {
    if (!mounted) return;
    _setLocalPlainCache(false);
    showTopToast(
      context,
      context.tr(zh: '本地明文缓存已清理', en: 'Local plaintext cache cleared'),
    );
  }

  String _formatTimeLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return context.tr(zh: '未记录', en: 'Not recorded');
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return _timeFormat.format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain =
        isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

    final settings = ref.watch(webDavSettingsProvider);
    final localLibrary = ref.watch(currentLocalLibraryProvider);
    final vaultEnabled = settings.vaultEnabled;
    final deprecatedCount = _remoteMeta?.deprecatedFiles.length ?? 0;
    final hasLocalPlainCache = settings.vaultKeepPlainCache;
    final recoveryVerified = _vaultState.recoveryVerified;
    final exportStatus = _exportStatus;
    final exportPathAvailable =
        localLibrary == null &&
        (settings.backupMirrorTreeUri.trim().isNotEmpty ||
            settings.backupMirrorRootPath.trim().isNotEmpty);
    final exportPlainDetected = exportStatus?.plainDetected ?? false;
    final exportPlainDeprecated = exportStatus?.plainDeprecated ?? false;

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
        title: Text(context.tr(zh: '安全状态检查', en: 'Vault security status')),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _StatusCard(
                card: card,
                textMain: textMain,
                textMuted: textMuted,
                loading: _loading,
                entries: [
                  _StatusEntry(
                    label: context.tr(zh: 'Vault 已启用', en: 'Vault enabled'),
                    value: vaultEnabled
                        ? context.tr(zh: '是', en: 'Yes')
                        : context.tr(zh: '否', en: 'No'),
                    status: vaultEnabled
                        ? _StatusKind.good
                        : _StatusKind.warn,
                  ),
                  _StatusEntry(
                    label: context.tr(zh: '恢复码', en: 'Recovery code'),
                    value: recoveryVerified
                        ? context.tr(zh: '已验证', en: 'Verified')
                        : context.tr(zh: '未验证', en: 'Not verified'),
                    status: recoveryVerified
                        ? _StatusKind.good
                        : _StatusKind.warn,
                  ),
                  _StatusEntry(
                    label: context.tr(zh: '远端明文', en: 'Remote plaintext'),
                    value: deprecatedCount == 0
                        ? context.tr(zh: '未检测到', en: 'Not detected')
                        : context.tr(
                            zh: '检测到 $deprecatedCount 个',
                            en: '$deprecatedCount detected',
                          ),
                    status:
                        deprecatedCount == 0 ? _StatusKind.good : _StatusKind.warn,
                  ),
                  _StatusEntry(
                    label: context.tr(
                      zh: '本地明文缓存',
                      en: 'Local plaintext cache',
                    ),
                    value: hasLocalPlainCache
                        ? context.tr(zh: '可能存在', en: 'Possible')
                        : context.tr(zh: '未检测到', en: 'Not detected'),
                    status: hasLocalPlainCache
                        ? _StatusKind.warn
                        : _StatusKind.good,
                  ),
                  if (exportPathAvailable) ...[
                    _StatusEntry(
                      label: context.tr(
                        zh: '导出路径明文',
                        en: 'Export plaintext',
                      ),
                      value: exportPlainDetected
                          ? exportPlainDeprecated
                              ? context.tr(
                                  zh: '检测到（残留）',
                                  en: 'Detected (legacy)',
                                )
                              : context.tr(zh: '检测到', en: 'Detected')
                          : context.tr(zh: '未检测到', en: 'Not detected'),
                      status: exportPlainDetected
                          ? _StatusKind.warn
                          : _StatusKind.good,
                    ),
                    _StatusEntry(
                      label: context.tr(zh: '最近一次导出', en: 'Last export'),
                      value: _formatTimeLabel(
                        exportStatus?.lastExportSuccessAt,
                      ),
                      status:
                          (exportStatus?.lastExportSuccessAt ?? '').isNotEmpty
                              ? _StatusKind.good
                              : _StatusKind.warn,
                    ),
                    _StatusEntry(
                      label: context.tr(zh: '最近一次上传', en: 'Last upload'),
                      value: _formatTimeLabel(
                        exportStatus?.lastUploadSuccessAt,
                      ),
                      status:
                          (exportStatus?.lastUploadSuccessAt ?? '').isNotEmpty
                              ? _StatusKind.good
                              : _StatusKind.warn,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    context.tr(
                      zh: '过渡期保留本地明文',
                      en: 'Keep local plaintext temporarily',
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textMain,
                    ),
                  ),
                  subtitle: Text(
                    context.tr(
                      zh: '用于兼容过渡期，建议确认后关闭',
                      en: 'For transition only. Turn off after verification.',
                    ),
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                  value: hasLocalPlainCache,
                  onChanged: vaultEnabled ? _setLocalPlainCache : null,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: vaultEnabled ? _handleViewRecoveryCode : null,
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: Text(
                        context.tr(zh: '查看恢复码', en: 'View recovery code'),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed:
                          deprecatedCount == 0 ? null : _handleCleanRemotePlain,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(
                        context.tr(zh: '清理远端明文', en: 'Clean remote plaintext'),
                      ),
                    ),
                  ),
                  if (exportPathAvailable)
                    SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed:
                            exportPlainDetected ? _handleCleanExportPlain : null,
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        label: Text(
                          context.tr(
                            zh: '清理导出明文',
                            en: 'Clean export plaintext',
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: hasLocalPlainCache
                          ? _handleClearLocalPlainCache
                          : null,
                      icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                      label: Text(
                        context.tr(zh: '清理本地明文', en: 'Clean local plaintext'),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: vaultEnabled ? _handleBackupTest : null,
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: Text(
                        context.tr(zh: '备份恢复测试', en: 'Backup restore test'),
                      ),
                    ),
                  ),
                ],
              ),
              if (_loading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  minHeight: 2,
                  color: isDark
                      ? MemoFlowPalette.textDark
                      : MemoFlowPalette.textLight,
                  backgroundColor: Colors.transparent,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusEntry {
  const _StatusEntry({
    required this.label,
    required this.value,
    required this.status,
  });

  final String label;
  final String value;
  final _StatusKind status;
}

enum _StatusKind { good, warn }

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.entries,
    required this.loading,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final List<_StatusEntry> entries;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final entry in entries) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  entry.status == _StatusKind.good
                      ? Icons.check_circle
                      : Icons.warning_amber_rounded,
                  color: entry.status == _StatusKind.good
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFF9A825),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
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
                      const SizedBox(height: 2),
                      Text(
                        entry.value,
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (entry != entries.last) const SizedBox(height: 12),
          ],
          if (loading) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.tr(zh: '正在检测…', en: 'Checking…'),
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _BackupTestMode { quick, deep }

