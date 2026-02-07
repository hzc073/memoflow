import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:saf_util/saf_util.dart';

import '../../core/app_localization.dart';
import '../../core/hash.dart';
import '../../core/memoflow_palette.dart';
import '../../data/models/local_library.dart';
import '../../state/local_library_provider.dart';
import '../../state/local_library_scanner.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';

enum OnboardingMode { local, server }

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  late AppLanguage _selected;
  OnboardingMode _mode = OnboardingMode.server;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(appPreferencesProvider).language;
  }

  Future<String?> _promptLocalLibraryName(String initialName) async {
    var name = initialName;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          trByLanguage(
            language: _selected,
            zh: '本地库名称',
            en: 'Local library name',
          ),
        ),
        content: TextFormField(
          initialValue: initialName,
          decoration: InputDecoration(
            hintText: trByLanguage(
              language: _selected,
              zh: '请输入名称',
              en: 'Enter a name',
            ),
          ),
          onChanged: (value) => name = value,
          onFieldSubmitted: (_) => context.safePop(name.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => context.safePop(null),
            child: Text(
              trByLanguage(language: _selected, zh: '取消', en: 'Cancel'),
            ),
          ),
          FilledButton(
            onPressed: () => context.safePop(name.trim()),
            child: Text(
              trByLanguage(language: _selected, zh: '确认', en: 'Confirm'),
            ),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return null;
    return result.trim();
  }

  Future<({String? treeUri, String? rootPath, String defaultName})?>
  _pickLocalLibraryLocation() async {
    if (Platform.isAndroid) {
      final doc = await SafUtil().pickDirectory(
        writePermission: true,
        persistablePermission: true,
      );
      if (doc == null) return null;
      final name = doc.name.trim().isEmpty
          ? trByLanguage(language: _selected, zh: '本地库', en: 'Local library')
          : doc.name.trim();
      return (treeUri: doc.uri, rootPath: null, defaultName: name);
    }
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null || path.trim().isEmpty) return null;
    final name = p.basename(path.trim());
    return (
      treeUri: null,
      rootPath: path.trim(),
      defaultName: name.isEmpty
          ? trByLanguage(language: _selected, zh: '本地库', en: 'Local library')
          : name,
    );
  }

  Future<void> _scanLocalLibrarySilently() async {
    final scanner = ref.read(localLibraryScannerProvider);
    if (scanner == null) return;
    try {
      await scanner.scanAndMerge(context, forceDisk: true);
    } catch (_) {
      // Silent on purpose; users can re-scan from settings later.
    }
  }

  Future<bool> _createLocalLibrary() async {
    final picked = await _pickLocalLibraryLocation();
    if (picked == null) return false;
    final name = await _promptLocalLibraryName(picked.defaultName);
    if (name == null || name.trim().isEmpty) return false;
    final keySeed = (picked.treeUri ?? picked.rootPath ?? '').trim();
    if (keySeed.isEmpty) return false;
    final key = 'local_${fnv1a64Hex(keySeed)}';
    final now = DateTime.now();
    final library = LocalLibrary(
      key: key,
      name: name.trim(),
      treeUri: picked.treeUri,
      rootPath: picked.rootPath,
      createdAt: now,
      updatedAt: now,
    );
    ref.read(localLibrariesProvider.notifier).upsert(library);
    await ref.read(appSessionProvider.notifier).switchWorkspace(key);
    if (!mounted) return false;
    await _scanLocalLibrarySilently();
    return true;
  }

  Future<void> _confirmSelection() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    if (_mode == OnboardingMode.local) {
      final created = await _createLocalLibrary();
      if (!created) {
        if (!mounted) return;
        setState(() => _submitting = false);
        return;
      }
    }
    final notifier = ref.read(appPreferencesProvider.notifier);
    final current = ref.read(appPreferencesProvider);
    await notifier.setAll(
      current.copyWith(language: _selected, hasSelectedLanguage: true),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
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
    String tr({required String zh, required String en}) =>
        trByLanguage(language: _selected, zh: zh, en: en);

    return Scaffold(
      backgroundColor: bg,
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
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: MemoFlowPalette.primary,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                          color: MemoFlowPalette.primary.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mark_chat_unread_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'MemoFlow',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(zh: '简约而强大的笔记流', en: 'Minimal, powerful note stream'),
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr(zh: '选择语言', en: 'Select language'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _LanguageCard(
                          language: AppLanguage.zhHans,
                          selected: _selected == AppLanguage.zhHans,
                          background: card,
                          textMain: textMain,
                          textMuted: textMuted,
                          onTap: () =>
                              setState(() => _selected = AppLanguage.zhHans),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LanguageCard(
                          language: AppLanguage.en,
                          selected: _selected == AppLanguage.en,
                          background: card,
                          textMain: textMain,
                          textMuted: textMuted,
                          onTap: () =>
                              setState(() => _selected = AppLanguage.en),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr(zh: '选择工作模式', en: 'Choose a mode'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr(
                        zh: '您可以随时在设置中更改此项',
                        en: 'You can change this later in Settings.',
                      ),
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ModeCard(
                    selected: _mode == OnboardingMode.local,
                    background: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    title: tr(zh: '单机模式', en: 'Local mode'),
                    label: 'LOCAL MODE',
                    description: tr(
                      zh: '数据仅保存在手机本地，无需配置服务器，适合追求极致隐私与离线使用的用户。',
                      en: 'Data stays on device. No server setup required, ideal for privacy and offline use.',
                    ),
                    icon: Icons.folder_rounded,
                    onTap: () => setState(() => _mode = OnboardingMode.local),
                  ),
                  const SizedBox(height: 14),
                  _ModeCard(
                    selected: _mode == OnboardingMode.server,
                    background: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    title: tr(zh: '联机模式', en: 'Server mode'),
                    label: 'SERVER MODE',
                    description: tr(
                      zh: '连接到你的 Memos 后端，实现多端实时同步。支持 Web、移动端等多平台无缝衔接。',
                      en: 'Connect to your Memos backend for real-time multi-device sync.',
                    ),
                    icon: Icons.cloud_rounded,
                    onTap: () => setState(() => _mode = OnboardingMode.server),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _confirmSelection,
                      style: FilledButton.styleFrom(
                        backgroundColor: MemoFlowPalette.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              tr(zh: '开始使用', en: 'Get started'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.language,
    required this.selected,
    required this.background,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final Color background;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = selected
        ? MemoFlowPalette.primary
        : (isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight);
    final fill = selected
        ? MemoFlowPalette.primary.withValues(alpha: isDark ? 0.22 : 0.1)
        : background;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                language.labelFor(AppLanguage.en),
                style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      language.labelFor(AppLanguage.zhHans),
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? MemoFlowPalette.primary : textMuted,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.selected,
    required this.background,
    required this.textMain,
    required this.textMuted,
    required this.title,
    required this.label,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final Color background;
  final Color textMain;
  final Color textMuted;
  final String title;
  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = selected
        ? MemoFlowPalette.primary
        : (isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight);
    final fill = selected
        ? MemoFlowPalette.primary.withValues(alpha: isDark ? 0.14 : 0.08)
        : background;
    final labelColor = selected ? MemoFlowPalette.primary : textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: selected ? 1.6 : 1),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: MemoFlowPalette.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: MemoFlowPalette.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: MemoFlowPalette.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(fontSize: 12, height: 1.4, color: textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
