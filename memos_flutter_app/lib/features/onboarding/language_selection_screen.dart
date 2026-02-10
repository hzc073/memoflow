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
import '../../i18n/strings.g.dart';
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
        title: Text(context.t.strings.onboarding.localLibraryNameTitle),
        content: TextFormField(
          initialValue: initialName,
          decoration: InputDecoration(
            hintText: context.t.strings.onboarding.localLibraryNameHint,
          ),
          onChanged: (value) => name = value,
          onFieldSubmitted: (_) => context.safePop(name.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => context.safePop(null),
            child: Text(context.t.strings.common.cancel),
          ),
          FilledButton(
            onPressed: () => context.safePop(name.trim()),
            child: Text(context.t.strings.common.confirm),
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
          ? context.t.strings.onboarding.localLibraryDefaultName
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
          ? context.t.strings.onboarding.localLibraryDefaultName
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

  List<AppLanguage> get _languageOptions => const [
        AppLanguage.system,
        AppLanguage.zhHans,
        AppLanguage.zhHantTw,
        AppLanguage.en,
        AppLanguage.ja,
        AppLanguage.de,
      ];

  String _languageTitle(AppLanguage language) {
    final labels = context.t.strings.languages;
    return switch (language) {
      AppLanguage.system => labels.system,
      AppLanguage.zhHans => labels.zhHans,
      AppLanguage.zhHantTw => labels.zhHantTw,
      AppLanguage.en => labels.en,
      AppLanguage.ja => labels.ja,
      AppLanguage.de => labels.de,
    };
  }

  String _languageSubtitle(AppLanguage language) {
    final labels = context.t.strings.languagesNative;
    return switch (language) {
      AppLanguage.system => labels.system,
      AppLanguage.zhHans => labels.zhHans,
      AppLanguage.zhHantTw => labels.zhHantTw,
      AppLanguage.en => labels.en,
      AppLanguage.ja => labels.ja,
      AppLanguage.de => labels.de,
    };
  }

  void _handleLanguageChanged(AppLanguage? language) {
    if (language == null || language == _selected) return;
    setState(() => _selected = language);
    ref.read(appPreferencesProvider.notifier).setLanguage(language);
  }

  Widget _languageLabel({
    required AppLanguage language,
    required Color textMain,
    required Color textMuted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _languageTitle(language),
          style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
        ),
        const SizedBox(height: 2),
        Text(
          _languageSubtitle(language),
          style: TextStyle(fontSize: 12, color: textMuted),
        ),
      ],
    );
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
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final dropdownItems = [
      for (final language in _languageOptions)
        DropdownMenuItem<AppLanguage>(
          value: language,
          child: _languageLabel(
            language: language,
            textMain: textMain,
            textMuted: textMuted,
          ),
        ),
    ];

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
                    context.t.strings.onboarding.tagline,
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.t.strings.onboarding.selectLanguage,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: card,
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
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AppLanguage>(
                        value: _selected,
                        isExpanded: true,
                        items: dropdownItems,
                        onChanged: _handleLanguageChanged,
                        icon: Icon(
                          Icons.expand_more,
                          size: 20,
                          color: textMuted,
                        ),
                        dropdownColor: card,
                        selectedItemBuilder: (context) => [
                          for (final language in _languageOptions)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _languageLabel(
                                language: language,
                                textMain: textMain,
                                textMuted: textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.t.strings.onboarding.selectMode,
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
                      context.t.strings.onboarding.modeHint,
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ModeCard(
                    selected: _mode == OnboardingMode.local,
                    background: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    title: context.t.strings.onboarding.modeLocalTitle,
                    label: context.t.strings.onboarding.modeLocalLabel,
                    description: context.t.strings.onboarding.modeLocalDesc,
                    icon: Icons.folder_rounded,
                    onTap: () => setState(() => _mode = OnboardingMode.local),
                  ),
                  const SizedBox(height: 14),
                  _ModeCard(
                    selected: _mode == OnboardingMode.server,
                    background: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    title: context.t.strings.onboarding.modeServerTitle,
                    label: context.t.strings.onboarding.modeServerLabel,
                    description: context.t.strings.onboarding.modeServerDesc,
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
                              context.t.strings.onboarding.getStarted,
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
