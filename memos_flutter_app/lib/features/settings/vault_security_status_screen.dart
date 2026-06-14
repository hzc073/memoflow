// ignore_for_file: use_build_context_synchronously

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
          .read(desktopSyncFacadeProvider)
          .fetchWebDavSyncMeta();
      final exportStatus = await ref
          .read(desktopSyncFacadeProvider)
          .fetchWebDavExportStatus();
      final vaultState = await ref
          .read(webDavVaultStateRepositoryProvider)
          .read();
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
      debugPrint(
        'Vault status load failed: ${LogSanitizer.sanitizeText(error.toString())}',
      );
    }
    final message = error is SyncError
        ? presentSyncError(language: context.appLanguage, error: error)
        : context.tr(zh: 'WebDAV 请求失败', en: 'WebDAV request failed');
    showTopToast(context, message);
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
          final confirm = await showSettingsConfirmationDialog(
            context: context,
            title: context.tr(zh: '清理远端明文', en: 'Clean remote plaintext'),
            message: context.tr(
              zh: '检测到旧明文文件，是否清理？',
              en: 'Legacy plaintext files were detected. Clean them now?',
            ),
            confirmLabel: context.tr(zh: '确认', en: 'Confirm'),
            cancelLabel: context.tr(zh: '取消', en: 'Cancel'),
            destructive: true,
          );
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
      final confirm = await showSettingsConfirmationDialog(
        context: context,
        title: context.tr(zh: '清理导出明文', en: 'Clean export plaintext'),
        message: context.tr(
          zh: '检测到旧明文导出，是否清理？',
          en: 'Legacy plaintext export was detected. Clean it now?',
        ),
        confirmLabel: context.tr(zh: '确认', en: 'Confirm'),
        cancelLabel: context.tr(zh: '取消', en: 'Cancel'),
        destructive: true,
      );
      if (confirm) {
        await _handleCleanExportPlain();
      }
    });
  }

  Future<void> _handleCleanRemotePlain() async {
    final cleaned = await ref
        .read(desktopSyncFacadeProvider)
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
        .read(desktopSyncFacadeProvider)
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
    final controller = TextEditingController();
    try {
      final confirmed =
          await showPlatformDialog<bool>(
            context: context,
            builder: (dialogContext) => SettingsFormDialog(
              title: Text(title),
              actions: [
                SettingsDialogAction(
                  onPressed: () => dialogContext.safePop(false),
                  label: Text(context.tr(zh: '取消', en: 'Cancel')),
                ),
                SettingsDialogAction(
                  onPressed: () => dialogContext.safePop(true),
                  label: Text(context.tr(zh: '确认', en: 'Confirm')),
                  variant: PlatformPrimaryActionVariant.filled,
                ),
              ],
              children: [
                SettingsDialogTextField(
                  label: context.tr(zh: 'Vault 密码', en: 'Vault password'),
                  controller: controller,
                  hint: context.tr(
                    zh: '请输入 Vault 密码',
                    en: 'Enter Vault password',
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => dialogContext.safePop(true),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return null;
      final password = controller.text.trim();
      if (password.isEmpty) return null;
      return password;
    } finally {
      controller.dispose();
    }
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
      showTopToast(context, message);
      return false;
    } catch (e) {
      if (!mounted) return false;
      showTopToast(context, e.toString());
      return false;
    }
  }

  Future<void> _handleViewRecoveryCode() async {
    final password = await _promptVaultPassword(
      title: context.tr(zh: '验证 Vault 密码', en: 'Verify Vault password'),
    );
    if (!mounted || password == null) return;
    final verified = await _verifyVaultPassword(password);
    if (!mounted || !verified) return;

    final recovery = await ref
        .read(webDavVaultRecoveryRepositoryProvider)
        .read();
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

    await showPlatformDialog<void>(
      context: context,
      builder: (dialogContext) => SettingsFormDialog(
        title: Text(context.tr(zh: 'Vault 恢复码', en: 'Vault recovery code')),
        actions: [
          SettingsDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: recovery));
              if (!dialogContext.mounted) return;
              showTopToast(
                dialogContext,
                context.tr(zh: '恢复码已复制', en: 'Recovery code copied'),
              );
            },
            icon: const Icon(Icons.copy),
            label: Text(context.tr(zh: '复制', en: 'Copy')),
            variant: PlatformPrimaryActionVariant.filled,
          ),
          SettingsDialogAction(
            onPressed: () => dialogContext.safePop(),
            label: Text(context.tr(zh: '确定', en: 'OK')),
          ),
        ],
        children: [
          SelectableText(
            recovery,
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

  Future<void> _handleBackupTest() async {
    final mode = await showSettingsSingleChoicePicker<_BackupTestMode>(
      context: context,
      title: context.tr(zh: '备份恢复测试', en: 'Backup restore test'),
      value: null,
      options: [
        SettingsChoiceOption<_BackupTestMode>(
          value: _BackupTestMode.quick,
          label: context.tr(zh: '快速验证', en: 'Quick verify'),
          description: context.tr(
            zh: '解密索引与快照，不落盘',
            en: 'Decrypt index and snapshot without writing files',
          ),
        ),
        SettingsChoiceOption<_BackupTestMode>(
          value: _BackupTestMode.deep,
          label: context.tr(zh: '完整恢复（高级）', en: 'Full restore (advanced)'),
          description: context.tr(
            zh: '解密全部对象并执行临时写入',
            en: 'Decrypt all objects with temporary writes',
          ),
        ),
      ],
    );
    if (!mounted || mode == null) return;

    String? password;
    final stored = await ref.read(webDavVaultPasswordRepositoryProvider).read();
    if (stored != null && stored.trim().isNotEmpty) {
      password = stored;
    } else {
      password = await _promptVaultPassword(
        title: context.tr(zh: '请输入 Vault 密码', en: 'Enter Vault password'),
      );
    }
    if (!mounted || password == null || password.trim().isEmpty) return;

    final error = await ref
        .read(desktopSyncFacadeProvider)
        .verifyWebDavBackup(
          password: password,
          deep: mode == _BackupTestMode.deep,
        );
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
    showTopToast(context, message);
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
    final statusEntries = <_StatusEntry>[
      _StatusEntry(
        label: context.tr(zh: 'Vault 已启用', en: 'Vault enabled'),
        value: vaultEnabled
            ? context.tr(zh: '是', en: 'Yes')
            : context.tr(zh: '否', en: 'No'),
        status: vaultEnabled ? _StatusKind.good : _StatusKind.warn,
      ),
      _StatusEntry(
        label: context.tr(zh: '恢复码', en: 'Recovery code'),
        value: recoveryVerified
            ? context.tr(zh: '已验证', en: 'Verified')
            : context.tr(zh: '未验证', en: 'Not verified'),
        status: recoveryVerified ? _StatusKind.good : _StatusKind.warn,
      ),
      _StatusEntry(
        label: context.tr(zh: '远端明文', en: 'Remote plaintext'),
        value: deprecatedCount == 0
            ? context.tr(zh: '未检测到', en: 'Not detected')
            : context.tr(
                zh: '检测到 $deprecatedCount 个',
                en: '$deprecatedCount detected',
              ),
        status: deprecatedCount == 0 ? _StatusKind.good : _StatusKind.warn,
      ),
      _StatusEntry(
        label: context.tr(zh: '本地明文缓存', en: 'Local plaintext cache'),
        value: hasLocalPlainCache
            ? context.tr(zh: '可能存在', en: 'Possible')
            : context.tr(zh: '未检测到', en: 'Not detected'),
        status: hasLocalPlainCache ? _StatusKind.warn : _StatusKind.good,
      ),
      if (exportPathAvailable) ...[
        _StatusEntry(
          label: context.tr(zh: '导出路径明文', en: 'Export plaintext'),
          value: exportPlainDetected
              ? exportPlainDeprecated
                    ? context.tr(zh: '检测到（残留）', en: 'Detected (legacy)')
                    : context.tr(zh: '检测到', en: 'Detected')
              : context.tr(zh: '未检测到', en: 'Not detected'),
          status: exportPlainDetected ? _StatusKind.warn : _StatusKind.good,
        ),
        _StatusEntry(
          label: context.tr(zh: '最近一次导出', en: 'Last export'),
          value: _formatTimeLabel(exportStatus?.lastExportSuccessAt),
          status: (exportStatus?.lastExportSuccessAt ?? '').isNotEmpty
              ? _StatusKind.good
              : _StatusKind.warn,
        ),
        _StatusEntry(
          label: context.tr(zh: '最近一次上传', en: 'Last upload'),
          value: _formatTimeLabel(exportStatus?.lastUploadSuccessAt),
          status: (exportStatus?.lastUploadSuccessAt ?? '').isNotEmpty
              ? _StatusKind.good
              : _StatusKind.warn,
        ),
      ],
    ];

    return SettingsPage(
      title: Text(context.tr(zh: '安全状态检查', en: 'Vault security status')),
      children: [
        SettingsSection(
          children: [
            for (final entry in statusEntries) _VaultStatusRow(entry: entry),
            if (_loading)
              _VaultLoadingRow(
                label: context.tr(zh: '正在检测…', en: 'Checking…'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          children: [
            SettingsToggleRow(
              label: context.tr(
                zh: '过渡期保留本地明文',
                en: 'Keep local plaintext temporarily',
              ),
              description: context.tr(
                zh: '用于兼容过渡期，建议确认后关闭',
                en: 'For transition only. Turn off after verification.',
              ),
              value: hasLocalPlainCache,
              onChanged: vaultEnabled ? _setLocalPlainCache : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _VaultActionButton(
              label: context.tr(zh: '查看恢复码', en: 'View recovery code'),
              icon: Icons.visibility_outlined,
              onPressed: vaultEnabled ? _handleViewRecoveryCode : null,
            ),
            _VaultActionButton(
              label: context.tr(zh: '清理远端明文', en: 'Clean remote plaintext'),
              icon: Icons.delete_outline,
              onPressed: deprecatedCount == 0 ? null : _handleCleanRemotePlain,
            ),
            if (exportPathAvailable)
              _VaultActionButton(
                label: context.tr(zh: '清理导出明文', en: 'Clean export plaintext'),
                icon: Icons.delete_sweep_outlined,
                onPressed: exportPlainDetected ? _handleCleanExportPlain : null,
              ),
            _VaultActionButton(
              label: context.tr(zh: '清理本地明文', en: 'Clean local plaintext'),
              icon: Icons.cleaning_services_outlined,
              onPressed: hasLocalPlainCache
                  ? _handleClearLocalPlainCache
                  : null,
            ),
            _VaultActionButton(
              label: context.tr(zh: '备份恢复测试', en: 'Backup restore test'),
              icon: Icons.shield_outlined,
              onPressed: vaultEnabled ? _handleBackupTest : null,
              variant: PlatformPrimaryActionVariant.filled,
            ),
          ],
        ),
      ],
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

class _VaultStatusRow extends StatelessWidget {
  const _VaultStatusRow({required this.entry});

  final _StatusEntry entry;

  @override
  Widget build(BuildContext context) {
    final isGood = entry.status == _StatusKind.good;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = isGood
        ? (isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32))
        : (isDark ? const Color(0xFFFFD54F) : const Color(0xFFF9A825));

    return SettingsCustomRow(
      leading: Icon(
        isGood ? Icons.check_circle : Icons.warning_amber_rounded,
        color: statusColor,
        size: 18,
      ),
      title: SettingsRowTitle(entry.label),
      description: SettingsRowDescription(entry.value),
    );
  }
}

class _VaultLoadingRow extends StatelessWidget {
  const _VaultLoadingRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SettingsCustomRow(
      leading: const SizedBox(width: 18, height: 18, child: PlatformProgress()),
      title: SettingsRowDescription(label),
    );
  }
}

class _VaultActionButton extends StatelessWidget {
  const _VaultActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.variant = PlatformPrimaryActionVariant.outlined,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final PlatformPrimaryActionVariant variant;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 184, maxWidth: 280),
      child: SettingsAction(
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        icon: Icon(icon, size: 18),
        onPressed: onPressed,
        variant: variant,
      ),
    );
  }
}

enum _BackupTestMode { quick, deep }
