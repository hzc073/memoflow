import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/webdav_url.dart';
import '../../data/models/webdav_settings.dart';
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
  ProviderSubscription<WebDavSettings>? _settingsSubscription;

  var _authMode = WebDavAuthMode.basic;
  var _ignoreTlsErrors = false;
  var _enabled = false;
  var _dirty = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(webDavSettingsProvider);
    _applySettings(settings);
    _settingsSubscription = ref.listenManual<WebDavSettings>(webDavSettingsProvider, (prev, next) {
      if (_dirty || !mounted) return;
      _applySettings(next);
    });
  }

  @override
  void dispose() {
    _settingsSubscription?.close();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootPathController.dispose();
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
    setState(() {});
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  Future<void> _selectAuthMode() async {
    final selected = await showModalBottomSheet<WebDavAuthMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Basic'),
              trailing: _authMode == WebDavAuthMode.basic ? const Icon(Icons.check) : null,
              onTap: () => context.safePop(WebDavAuthMode.basic),
            ),
            ListTile(
              title: const Text('Digest'),
              trailing: _authMode == WebDavAuthMode.digest ? const Icon(Icons.check) : null,
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
    await ref.read(webDavSyncControllerProvider.notifier).syncNow(context: context);
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(webDavSyncControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);
    final serverUrl = _serverUrlController.text.trim();
    final isHttp = serverUrl.startsWith('http://');

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
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _ToggleCard(
                card: card,
                textMain: textMain,
                textMuted: textMuted,
                label: context.tr(zh: '启用 WebDAV 同步', en: 'Enable WebDAV sync'),
                description: context.tr(
                  zh: '将设置保存到 WebDAV，并在设备之间保持一致。',
                  en: 'Sync settings to WebDAV and keep devices consistent.',
                ),
                value: _enabled,
                onChanged: (value) {
                  setState(() => _enabled = value);
                  ref.read(webDavSettingsProvider.notifier).setEnabled(value);
                },
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(zh: '连接信息', en: 'Connection'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMuted),
              ),
              const SizedBox(height: 10),
              _Group(
                card: card,
                divider: divider,
                children: [
                  _InputRow(
                    label: context.tr(zh: '服务器地址', en: 'Server URL'),
                    hint: 'https://example.com/dav',
                    controller: _serverUrlController,
                    textMain: textMain,
                    textMuted: textMuted,
                    keyboardType: TextInputType.url,
                    onChanged: (v) {
                      _markDirty();
                      ref.read(webDavSettingsProvider.notifier).setServerUrl(v);
                    },
                    onEditingComplete: _normalizeServerUrl,
                  ),
                  _InputRow(
                    label: context.tr(zh: '用户名', en: 'Username'),
                    hint: context.tr(zh: '请输入用户名', en: 'Enter username'),
                    controller: _usernameController,
                    textMain: textMain,
                    textMuted: textMuted,
                    onChanged: (v) {
                      _markDirty();
                      ref.read(webDavSettingsProvider.notifier).setUsername(v);
                    },
                  ),
                  _InputRow(
                    label: context.tr(zh: '密码', en: 'Password'),
                    hint: context.tr(zh: '请输入密码', en: 'Enter password'),
                    controller: _passwordController,
                    textMain: textMain,
                    textMuted: textMuted,
                    obscureText: true,
                    onChanged: (v) {
                      _markDirty();
                      ref.read(webDavSettingsProvider.notifier).setPassword(v);
                    },
                  ),
                  _SelectRow(
                    label: context.tr(zh: '认证方式', en: 'Auth mode'),
                    value: _authMode == WebDavAuthMode.basic ? 'Basic' : 'Digest',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: _selectAuthMode,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(zh: '安全', en: 'Security'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMuted),
              ),
              const SizedBox(height: 10),
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
                      ref.read(webDavSettingsProvider.notifier).setIgnoreTlsErrors(v);
                    },
                  ),
                  _InputRow(
                    label: context.tr(zh: '根路径', en: 'Root path'),
                    hint: '/MemoFlow/settings/v1',
                    controller: _rootPathController,
                    textMain: textMain,
                    textMuted: textMuted,
                    onChanged: (v) {
                      _markDirty();
                      ref.read(webDavSettingsProvider.notifier).setRootPath(v);
                    },
                    onEditingComplete: _normalizeRootPath,
                  ),
                ],
              ),
              if (isHttp || _ignoreTlsErrors) ...[
                const SizedBox(height: 12),
                _WarningCard(
                  text: context.tr(
                    zh: '为保护 Token/密码安全，建议使用 HTTPS 并避免忽略证书校验。',
                    en: 'Use HTTPS and avoid ignoring TLS errors to protect credentials.',
                  ),
                  isDark: isDark,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                context.tr(zh: '同步', en: 'Sync'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMuted),
              ),
              const SizedBox(height: 10),
              _Group(
                card: card,
                divider: divider,
                children: [
                  _InfoRow(
                    label: context.tr(zh: '上次成功', en: 'Last success'),
                    value: _formatTime(syncStatus.lastSuccessAt),
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                  if (syncStatus.lastError != null && syncStatus.lastError!.trim().isNotEmpty)
                    _InfoRow(
                      label: context.tr(zh: '错误信息', en: 'Last error'),
                      value: syncStatus.lastError!,
                      textMain: textMain,
                      textMuted: textMuted,
                      emphasize: true,
                    ),
                  if (syncStatus.hasPendingConflict)
                    _InfoRow(
                      label: context.tr(zh: '冲突提示', en: 'Conflicts'),
                      value: context.tr(zh: '存在冲突，点击同步处理', en: 'Conflicts detected. Tap sync to resolve.'),
                      textMain: textMain,
                      textMuted: textMuted,
                      emphasize: true,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (!_enabled || syncStatus.syncing) ? null : _syncNow,
                  icon: syncStatus.syncing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                    syncStatus.syncing
                        ? context.tr(zh: '同步中…', en: 'Syncing…')
                        : context.tr(zh: '立即同步', en: 'Sync now'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MemoFlowPalette.primary,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(
                  zh: '提示：修改设置后会自动同步。手动同步可用于处理冲突或强制刷新。',
                  en: 'Tip: Settings changes auto-sync. Manual sync helps resolve conflicts or force refresh.',
                ),
                style: TextStyle(fontSize: 12, height: 1.4, color: textMuted),
              ),
            ],
          ),
        ],
      ),
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
    final textColor = isDark ? const Color(0xFFF5C8C8) : const Color(0xFFB23A2C);
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
  final ValueChanged<bool> onChanged;

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
                  child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: textMain)),
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
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textMain)),
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
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textMain)),
      subtitle: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        onEditingComplete: onEditingComplete,
        style: TextStyle(color: textMain, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.6), fontSize: 12),
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
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textMain)),
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
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textMain)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(value, style: TextStyle(fontSize: 12, color: color, height: 1.3)),
      ),
    );
  }
}
