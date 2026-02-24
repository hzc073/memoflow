import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hash.dart';
import '../../core/memoflow_palette.dart';
import '../../data/db/app_database.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/local_library.dart';
import '../settings/local_mode_setup_screen.dart';
import '../../i18n/strings.g.dart';
import '../../state/database_provider.dart';
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

  void _logFlow(
    String message, {
    Map<String, Object?>? context,
    bool warn = false,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    if (warn) {
      LogManager.instance.warn(
        'Onboarding: $message',
        context: context,
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    LogManager.instance.info(
      'Onboarding: $message',
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void initState() {
    super.initState();
    _selected = ref.read(appPreferencesProvider).language;
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

  Future<String?> _createLocalLibrary() async {
    final librariesNotifier = ref.read(localLibrariesProvider.notifier);
    final existingLibraries = ref.read(localLibrariesProvider);
    _logFlow('create_local_library_start');
    final result = await LocalModeSetupScreen.show(
      context,
      title: context.t.strings.onboarding.modeLocalTitle,
      subtitle: context.t.strings.onboarding.modeLocalDesc,
      confirmLabel: context.t.strings.common.confirm,
      cancelLabel: context.t.strings.common.cancel,
      initialName: context.t.strings.onboarding.localLibraryDefaultName,
    );
    if (result == null) {
      _logFlow('create_local_library_cancelled');
      return null;
    }
    _logFlow(
      'create_local_library_result',
      context: <String, Object?>{
        'nameLength': result.name.trim().length,
        'hasTreeUri': (result.treeUri ?? '').trim().isNotEmpty,
        'hasRootPath': (result.rootPath ?? '').trim().isNotEmpty,
        'encryptionEnabled': result.encryptionEnabled,
      },
    );
    final keySeed = (result.treeUri ?? result.rootPath ?? '').trim();
    if (keySeed.isEmpty) {
      _logFlow('create_local_library_invalid_seed', warn: true);
      return null;
    }
    final key = 'local_${fnv1a64Hex(keySeed)}';
    final existed = existingLibraries.any((l) => l.key == key);
    if (!existed) {
      try {
        await AppDatabase.deleteDatabaseFile(
          dbName: databaseNameForAccountKey(key),
        );
        _logFlow(
          'create_local_library_stale_db_cleared',
          context: {'workspaceKey': key},
        );
      } catch (error, stackTrace) {
        _logFlow(
          'create_local_library_stale_db_clear_failed',
          warn: true,
          context: {'workspaceKey': key},
          error: error,
          stackTrace: stackTrace,
        );
      }
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
    librariesNotifier.upsert(library);
    _logFlow(
      'local_library_upserted',
      context: <String, Object?>{'workspaceKey': key},
    );
    if (result.encryptionEnabled && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('加密功能当前仅占位，暂未真正生效。')));
    }
    _logFlow('local_library_ready', context: {'workspaceKey': key});
    return key;
  }

  Future<void> _confirmSelection() async {
    if (_submitting) return;
    final sessionNotifier = ref.read(appSessionProvider.notifier);
    final prefsNotifier = ref.read(appPreferencesProvider.notifier);
    final currentPrefs = ref.read(appPreferencesProvider);
    final prefsLoaded = ref.read(appPreferencesLoadedProvider);
    var sessionKeyForLog = ref.read(appSessionProvider).valueOrNull?.currentKey;
    setState(() => _submitting = true);
    _logFlow(
      'confirm_selection_start',
      context: <String, Object?>{
        'mode': _mode.name,
        'prefsLoaded': prefsLoaded,
      },
    );
    try {
      String? localWorkspaceKey;
      if (_mode == OnboardingMode.local) {
        localWorkspaceKey = await _createLocalLibrary();
        if (localWorkspaceKey == null) {
          _logFlow('confirm_selection_local_creation_aborted', warn: true);
          return;
        }
      } else {
        await sessionNotifier.setCurrentKey(null);
        sessionKeyForLog = null;
        _logFlow('confirm_selection_server_mode_selected');
      }
      _logFlow(
        'confirm_selection_before_set_all',
        context: <String, Object?>{
          'language': currentPrefs.language.name,
          'hasSelectedLanguage': currentPrefs.hasSelectedLanguage,
          'sessionKey': sessionKeyForLog,
          'pendingWorkspaceKey': localWorkspaceKey,
        },
      );
      await prefsNotifier.setAll(
        currentPrefs.copyWith(
          language: _selected,
          hasSelectedLanguage: true,
          onboardingMode: _mode == OnboardingMode.local
              ? AppOnboardingMode.local
              : AppOnboardingMode.server,
          homeInitialLoadingOverlayShown: false,
        ),
      );
      _logFlow(
        'confirm_selection_after_set_all',
        context: <String, Object?>{
          'language': _selected.name,
          'hasSelectedLanguage': true,
          'sessionKey': sessionKeyForLog,
          'pendingWorkspaceKey': localWorkspaceKey,
        },
      );
      if (localWorkspaceKey != null) {
        await sessionNotifier.switchWorkspace(localWorkspaceKey);
        sessionKeyForLog = localWorkspaceKey;
        _logFlow(
          'workspace_switched',
          context: <String, Object?>{
            'requestedKey': localWorkspaceKey,
            'currentKey': sessionKeyForLog,
            'switchApplied': true,
          },
        );
        if (mounted) {
          await _scanLocalLibrarySilently();
          _logFlow(
            'local_library_scan_completed',
            context: {'workspaceKey': localWorkspaceKey},
          );
        }
      }
    } catch (error, stackTrace) {
      _logFlow(
        'confirm_selection_failed',
        warn: true,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
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
