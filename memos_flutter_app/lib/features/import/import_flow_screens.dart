import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_localization.dart';
import '../../core/desktop_quick_input_channel.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../platform/platform_icons.dart';
import '../../platform/platform_route.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../platform/widgets/platform_page.dart';
import '../../state/sync/sync_coordinator_provider.dart';
import '../../application/sync/sync_request.dart';
import '../../state/system/database_provider.dart';
import '../../state/system/home_loading_overlay_provider.dart';
import '../../state/system/local_library_provider.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../../state/system/session_provider.dart';
import '../memos/memos_list_screen.dart';
import 'flomo_import_service.dart';
import 'generic_markdown_import_service.dart';
import 'import_source_format.dart';
import 'import_source_kind.dart';
import 'swashbuckler_diary_import_service.dart' as swashbuckler_diary;
import '../../i18n/strings.g.dart';

const _flomoImportIconAsset = 'assets/images/flomo_import_logo.svg';
const _swashbucklerDiaryImportIconAsset =
    'assets/images/swashbuckler_diary_import_logo.png';
const _memoFlowImportIconAsset = 'assets/splash/splash_logo.png';

class ImportSourceScreen extends StatelessWidget {
  const ImportSourceScreen({
    super.key,
    this.onSelectFlomo,
    this.onSelectMarkdown,
    this.onSelectMemoFlowMarkdown,
    this.onSelectGenericMarkdown,
    this.onSelectSwashbucklerDiary,
  });

  final VoidCallback? onSelectFlomo;
  final VoidCallback? onSelectMarkdown;
  final VoidCallback? onSelectMemoFlowMarkdown;
  final VoidCallback? onSelectGenericMarkdown;
  final VoidCallback? onSelectSwashbucklerDiary;

  String _sanitizeFilename(String input, {required String fallbackExtension}) {
    final trimmed = input.trim();
    final sanitized = trimmed.isEmpty ? 'import.$fallbackExtension' : trimmed;
    return sanitized.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  Future<({String filePath, String fileName})?> _pickImportFile(
    BuildContext context, {
    required List<String> allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );
    if (!context.mounted || result == null) return null;

    final file = result.files.isNotEmpty ? result.files.first : null;
    if (file == null) return null;

    var path = file.path;
    final fileName = file.name.trim();
    final displayName = fileName.isNotEmpty
        ? fileName
        : (path == null ? '' : p.basename(path));
    final bytes = file.bytes;

    if ((path == null || path.trim().isEmpty || !File(path).existsSync()) &&
        bytes != null) {
      final tempDir = await getTemporaryDirectory();
      if (!context.mounted) return null;
      final fallbackExt = (file.extension ?? '').trim().isNotEmpty
          ? file.extension!.trim()
          : 'zip';
      final safeName = _sanitizeFilename(
        displayName.isEmpty ? 'import.$fallbackExt' : displayName,
        fallbackExtension: fallbackExt,
      );
      final tempPath = p.join(tempDir.path, safeName);
      await File(tempPath).writeAsBytes(bytes, flush: true);
      if (!context.mounted) return null;
      path = tempPath;
    }

    if (path == null || path.trim().isEmpty) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_unable_read_file_path),
        ),
      );
      return null;
    }

    if (!context.mounted) return null;
    final resolvedPath = path;
    final shownName = displayName.isNotEmpty
        ? displayName
        : p.basename(resolvedPath);

    return (filePath: resolvedPath, fileName: shownName);
  }

  Future<void> _openImportRunScreen(
    BuildContext context, {
    required List<String> allowedExtensions,
    required ImportSourceKind sourceKind,
  }) async {
    final picked = await _pickImportFile(
      context,
      allowedExtensions: allowedExtensions,
    );
    if (!context.mounted || picked == null) return;

    await Navigator.of(context).push(
      buildPlatformPageRoute<void>(
        context: context,
        builder: (_) => ImportRunScreen(
          filePath: picked.filePath,
          fileName: picked.fileName,
          sourceKind: sourceKind,
        ),
      ),
    );
  }

  Future<void> _selectFlomoFile(BuildContext context) {
    return _openImportRunScreen(
      context,
      allowedExtensions: const ['zip', 'html', 'htm'],
      sourceKind: ImportSourceKind.flomo,
    );
  }

  Future<void> _selectMemoFlowMarkdownZip(BuildContext context) {
    return _openImportRunScreen(
      context,
      allowedExtensions: const ['zip'],
      sourceKind: ImportSourceKind.memoFlowMarkdown,
    );
  }

  Future<void> _selectGenericMarkdownZip(BuildContext context) {
    return _openImportRunScreen(
      context,
      allowedExtensions: const ['zip'],
      sourceKind: ImportSourceKind.genericMarkdown,
    );
  }

  Future<void> _selectSwashbucklerDiaryZip(BuildContext context) {
    return _openImportRunScreen(
      context,
      allowedExtensions: const ['zip'],
      sourceKind: ImportSourceKind.swashbucklerDiary,
    );
  }

  Future<void> _showSourceHelp(
    BuildContext context,
    ImportSourceKind sourceKind,
  ) async {
    final description = importSourceFormatDescription(context, sourceKind);
    await showPlatformAlertDialog<bool>(
      context: context,
      title: description.title,
      message: description.help,
      details: description.structure,
      actions: [
        PlatformDialogAction<bool>(
          value: true,
          label: context.t.strings.legacy.msg_got_it,
          isDefault: true,
        ),
      ],
    );
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
    final textMuted = textMain.withValues(alpha: isDark ? 0.58 : 0.65);
    final shadow = isDark
        ? null
        : [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ];
    return PlatformPage(
      backgroundColor: bg,
      title: Text(context.t.strings.legacy.msg_import),
      leading: IconButton(
        tooltip: context.t.strings.legacy.msg_back,
        icon: Icon(PlatformIcons.back),
        onPressed: () => Navigator.of(context).maybePop(),
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
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 8,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context
                                .t
                                .strings
                                .legacy
                                .msg_choose_data_source_start_importing_memos,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ImportSourceTile(
                            title: importSourceFormatDescription(
                              context,
                              ImportSourceKind.flomo,
                            ).title,
                            icon: SvgPicture.asset(
                              _flomoImportIconAsset,
                              width: 24,
                              height: 24,
                            ),
                            iconBg: MemoFlowPalette.primary.withValues(
                              alpha: isDark ? 0.2 : 0.12,
                            ),
                            iconColor: MemoFlowPalette.primary,
                            card: card,
                            textMain: textMain,
                            textMuted: textMuted,
                            shadow: shadow,
                            onHelp: () => _showSourceHelp(
                              context,
                              ImportSourceKind.flomo,
                            ),
                            onTap:
                                onSelectFlomo ??
                                () => _selectFlomoFile(context),
                          ),
                          const SizedBox(height: 12),
                          _ImportSourceTile(
                            title: importSourceFormatDescription(
                              context,
                              ImportSourceKind.swashbucklerDiary,
                            ).title,
                            icon: Image.asset(
                              _swashbucklerDiaryImportIconAsset,
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                            ),
                            iconBg: MemoFlowPalette.primary.withValues(
                              alpha: isDark ? 0.18 : 0.1,
                            ),
                            iconColor: MemoFlowPalette.primary.withValues(
                              alpha: 0.9,
                            ),
                            card: card,
                            textMain: textMain,
                            textMuted: textMuted,
                            shadow: shadow,
                            onHelp: () => _showSourceHelp(
                              context,
                              ImportSourceKind.swashbucklerDiary,
                            ),
                            onTap:
                                onSelectSwashbucklerDiary ??
                                () => _selectSwashbucklerDiaryZip(context),
                          ),
                          const SizedBox(height: 12),
                          _ImportSourceTile(
                            title: importSourceFormatDescription(
                              context,
                              ImportSourceKind.memoFlowMarkdown,
                            ).title,
                            icon: Image.asset(
                              _memoFlowImportIconAsset,
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                            ),
                            iconBg: MemoFlowPalette.primary.withValues(
                              alpha: isDark ? 0.2 : 0.1,
                            ),
                            iconColor: MemoFlowPalette.primary.withValues(
                              alpha: 0.9,
                            ),
                            card: card,
                            textMain: textMain,
                            textMuted: textMuted,
                            shadow: shadow,
                            onHelp: () => _showSourceHelp(
                              context,
                              ImportSourceKind.memoFlowMarkdown,
                            ),
                            onTap:
                                onSelectMemoFlowMarkdown ??
                                onSelectMarkdown ??
                                () => _selectMemoFlowMarkdownZip(context),
                          ),
                          const SizedBox(height: 12),
                          _ImportSourceTile(
                            title: importSourceFormatDescription(
                              context,
                              ImportSourceKind.genericMarkdown,
                            ).title,
                            icon: Text(
                              'md',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: MemoFlowPalette.primary.withValues(
                                  alpha: 0.92,
                                ),
                              ),
                            ),
                            iconBg: MemoFlowPalette.primary.withValues(
                              alpha: isDark ? 0.18 : 0.09,
                            ),
                            iconColor: MemoFlowPalette.primary.withValues(
                              alpha: 0.9,
                            ),
                            card: card,
                            textMain: textMain,
                            textMuted: textMuted,
                            shadow: shadow,
                            onHelp: () => _showSourceHelp(
                              context,
                              ImportSourceKind.genericMarkdown,
                            ),
                            onTap:
                                onSelectGenericMarkdown ??
                                () => _selectGenericMarkdownZip(context),
                          ),
                          const Spacer(),
                          _ImportNoteCard(
                            text: context
                                .t
                                .strings
                                .legacy
                                .msg_after_import_memos_sync_list_automatically,
                            textMuted: textMuted,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

typedef ImportRunOverride =
    Future<ImportResult> Function({
      required ImportProgressCallback onProgress,
      required ImportCancelCheck isCancelled,
    });

class ImportRunScreen extends ConsumerStatefulWidget {
  const ImportRunScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    this.sourceKind = ImportSourceKind.flomo,
    this.importOverride,
  });

  final String filePath;
  final String fileName;
  final ImportSourceKind sourceKind;
  final ImportRunOverride? importOverride;

  @override
  ConsumerState<ImportRunScreen> createState() => _ImportRunScreenState();
}

class _ImportRunScreenState extends ConsumerState<ImportRunScreen> {
  double _progress = 0;
  String? _statusText;
  String? _progressLabel;
  String? _progressDetail;
  var _cancelRequested = false;
  var _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startImport());
  }

  Future<void> _startImport() async {
    if (_started) return;
    _started = true;

    var session = ref.read(appSessionProvider).valueOrNull;
    var account = session?.currentAccount;
    var isLocalLibraryMode = ref.read(isLocalLibraryModeProvider);

    // Recover local-only workspace when secure storage loses currentKey.
    if (account == null && !isLocalLibraryMode) {
      final localLibraries = ref.read(localLibrariesProvider);
      if (localLibraries.length == 1) {
        await ref
            .read(appSessionProvider.notifier)
            .switchWorkspace(localLibraries.first.key);
        session = ref.read(appSessionProvider).valueOrNull;
        account = session?.currentAccount;
        isLocalLibraryMode = ref.read(isLocalLibraryModeProvider);
      }
    }

    if (account == null && !isLocalLibraryMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_not_authenticated_2),
          ),
        );
        context.safePop();
      }
      return;
    }

    final db = ref.read(databaseProvider);
    final language = ref.read(devicePreferencesProvider).language;
    final tagRecognitionPolicy = ref
        .read(currentWorkspacePreferencesProvider)
        .tagRecognitionPolicy;
    Future<ImportResult> runImport() {
      final override = widget.importOverride;
      if (override != null) {
        return override(
          onProgress: _handleProgress,
          isCancelled: () => _cancelRequested,
        );
      }
      return switch (widget.sourceKind) {
        ImportSourceKind.swashbucklerDiary =>
          swashbuckler_diary.SwashbucklerDiaryImportService(
            db: db,
            account: account,
            importScopeKey: session?.currentKey,
            language: language,
            tagRecognitionPolicy: tagRecognitionPolicy,
          ).importFile(
            filePath: widget.filePath,
            onProgress: _handleProgress,
            isCancelled: () => _cancelRequested,
          ),
        ImportSourceKind.flomo =>
          FlomoImportService(
            db: db,
            account: account,
            importScopeKey: session?.currentKey,
            language: language,
            tagRecognitionPolicy: tagRecognitionPolicy,
          ).importFile(
            filePath: widget.filePath,
            onProgress: _handleProgress,
            isCancelled: () => _cancelRequested,
          ),
        ImportSourceKind.memoFlowMarkdown =>
          FlomoImportService(
            db: db,
            account: account,
            importScopeKey: session?.currentKey,
            language: language,
            tagRecognitionPolicy: tagRecognitionPolicy,
          ).importMemoFlowMarkdownFile(
            filePath: widget.filePath,
            onProgress: _handleProgress,
            isCancelled: () => _cancelRequested,
          ),
        ImportSourceKind.genericMarkdown =>
          GenericMarkdownImportService(
            db: db,
            account: account,
            importScopeKey: session?.currentKey,
            language: language,
            tagRecognitionPolicy: tagRecognitionPolicy,
          ).importFile(
            filePath: widget.filePath,
            onProgress: _handleProgress,
            isCancelled: () => _cancelRequested,
          ),
      };
    }

    try {
      final result = await runImport();
      if (!mounted) return;

      // Force memo streams to re-query after bulk import.
      db.notifyDataChanged();
      unawaited(
        ref
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
              const SyncRequest(
                kind: SyncRequestKind.memos,
                reason: SyncRequestReason.manual,
              ),
            ),
      );
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        buildPlatformPageRoute<void>(
          context: context,
          builder: (resultContext) => ImportResultScreen(
            memoCount: result.memoCount,
            attachmentCount: result.attachmentCount,
            failedCount: result.failedCount,
            newTags: result.newTags,
            onGoHome: () {
              final container = ProviderScope.containerOf(
                resultContext,
                listen: false,
              );
              container.read(homeLoadingOverlayForceProvider.notifier).state =
                  true;
              if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                unawaited(
                  DesktopMultiWindow.invokeMethod(
                    0,
                    desktopHomeShowLoadingOverlayMethod,
                    null,
                  ).catchError((_) {}),
                );
              }
              Navigator.of(resultContext).popUntil((route) => route.isFirst);
            },
            onViewImported: () => Navigator.of(resultContext).push(
              buildPlatformPageRoute<void>(
                context: resultContext,
                builder: (_) => const ImportedMemosScreen(),
              ),
            ),
          ),
        ),
      );
    } on ImportCancelled {
      if (!mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_import_canceled);
      context.safePop();
    } on ImportException catch (e) {
      if (!mounted) return;
      await _showImportFailure(e.message);
      if (!mounted) return;
      context.safePop();
    } catch (e) {
      if (!mounted) return;
      await _showImportFailure(
        context.t.strings.legacy.msg_import_failed(e: e),
      );
      if (!mounted) return;
      context.safePop();
    }
  }

  Future<void> _showImportFailure(String message) async {
    final description = importSourceFormatDescription(
      context,
      widget.sourceKind,
    );
    await showPlatformAlertDialog<bool>(
      context: context,
      title: context.t.strings.legacy.msg_import_failed_title,
      message: message,
      details: description.structure,
      actions: [
        PlatformDialogAction<bool>(
          value: true,
          label: context.t.strings.legacy.msg_got_it,
          isDefault: true,
        ),
      ],
    );
  }

  void _handleProgress(ImportProgressUpdate update) {
    if (!mounted) return;
    setState(() {
      _progress = update.progress;
      _statusText = update.statusText;
      _progressLabel = update.progressLabel;
      _progressDetail = update.progressDetail;
    });
  }

  void _requestCancel() {
    if (_cancelRequested) return;
    setState(() {
      _cancelRequested = true;
      _statusText = context.t.strings.legacy.msg_cancelling_2;
      _progressLabel = context.t.strings.legacy.msg_cancelling;
      _progressDetail = context.t.strings.legacy.msg_waiting_tasks_stop;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ImportProgressScreen(
      fileName: widget.fileName,
      progress: _progress,
      statusText: _statusText,
      progressLabel: _progressLabel,
      progressDetail: _progressDetail,
      onCancel: _requestCancel,
    );
  }
}

class ImportProgressScreen extends StatelessWidget {
  const ImportProgressScreen({
    super.key,
    required this.fileName,
    required this.progress,
    this.statusText,
    this.progressLabel,
    this.progressDetail,
    this.onCancel,
  });

  final String fileName;
  final double progress;
  final String? statusText;
  final String? progressLabel;
  final String? progressDetail;
  final VoidCallback? onCancel;

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
    final shadow = isDark
        ? null
        : [
            BoxShadow(
              blurRadius: 22,
              offset: const Offset(0, 10),
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ];
    final clamped = progress.clamp(0.0, 1.0).toDouble();
    final percentText = '${(clamped * 100).round()}%';
    final label =
        progressLabel ?? context.t.strings.legacy.msg_parsing_progress;
    final status = statusText ?? context.t.strings.legacy.msg_parsing_file;
    final detail =
        progressDetail ?? context.t.strings.legacy.msg_processing_content;

    return PlatformPage(
      backgroundColor: bg,
      title: Text(context.t.strings.legacy.msg_import_file),
      leading: IconButton(
        tooltip: context.t.strings.legacy.msg_back,
        icon: Icon(PlatformIcons.back),
        onPressed: () => Navigator.of(context).maybePop(),
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
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: shadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: MemoFlowPalette.primary.withValues(
                            alpha: isDark ? 0.22 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.insert_drive_file_rounded,
                          color: MemoFlowPalette.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        fileName,
                        style: TextStyle(fontSize: 12.5, color: textMuted),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            label,
                            style: TextStyle(fontSize: 12.5, color: textMuted),
                          ),
                          Text(
                            percentText,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: MemoFlowPalette.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _RoundedProgressBar(value: clamped, isDark: isDark),
                      const SizedBox(height: 8),
                      Text(
                        detail,
                        style: TextStyle(fontSize: 12, color: textMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed:
                            onCancel ?? () => Navigator.of(context).maybePop(),
                        style: TextButton.styleFrom(
                          foregroundColor: MemoFlowPalette.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 6,
                          ),
                        ),
                        child: Text(context.t.strings.legacy.msg_cancel_2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ImportResultScreen extends StatelessWidget {
  const ImportResultScreen({
    super.key,
    required this.memoCount,
    required this.attachmentCount,
    required this.failedCount,
    required this.newTags,
    required this.onGoHome,
    required this.onViewImported,
  });

  final int memoCount;
  final int attachmentCount;
  final int failedCount;
  final List<String> newTags;
  final VoidCallback onGoHome;
  final VoidCallback onViewImported;

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
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final shadow = isDark
        ? null
        : [
            BoxShadow(
              blurRadius: 22,
              offset: const Offset(0, 10),
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ];
    final formatter = NumberFormat.decimalPattern();

    String formatCount(int value) {
      return formatter.format(value);
    }

    String formatCountLabel(int value, String key) {
      return trByLanguageKey(
        language: context.appLanguage,
        key: key,
        params: {'count': formatCount(value)},
      );
    }

    return PlatformPage(
      backgroundColor: bg,
      title: Text(context.t.strings.legacy.msg_import_result),
      leading: IconButton(
        tooltip: context.t.strings.legacy.msg_back,
        icon: Icon(PlatformIcons.back),
        onPressed: () => Navigator.of(context).maybePop(),
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
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 12,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: shadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: MemoFlowPalette.primary.withValues(
                                      alpha: isDark ? 0.22 : 0.14,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    color: MemoFlowPalette.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  context
                                      .t
                                      .strings
                                      .legacy
                                      .msg_import_complete_2,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: textMain,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  context
                                      .t
                                      .strings
                                      .legacy
                                      .msg_data_has_been_migrated_app_successfully,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.4,
                                    color: textMuted,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Divider(height: 1, color: divider),
                                const SizedBox(height: 12),
                                _ResultRow(
                                  label: context
                                      .t
                                      .strings
                                      .legacy
                                      .msg_imported_memos,
                                  value: formatCountLabel(
                                    memoCount,
                                    'legacy.import_count_memos',
                                  ),
                                  textMain: textMain,
                                  textMuted: textMuted,
                                ),
                                const SizedBox(height: 8),
                                _ResultRow(
                                  label: context
                                      .t
                                      .strings
                                      .legacy
                                      .msg_attachments_2,
                                  value: formatCountLabel(
                                    attachmentCount,
                                    'legacy.import_count_attachments',
                                  ),
                                  textMain: textMain,
                                  textMuted: textMuted,
                                ),
                                const SizedBox(height: 8),
                                _ResultRow(
                                  label:
                                      context.t.strings.legacy.msg_failed_items,
                                  value: formatCount(failedCount),
                                  textMain: textMain,
                                  textMuted: textMuted,
                                ),
                                const SizedBox(height: 12),
                                Divider(height: 1, color: divider),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    context.t.strings.legacy.msg_tags_created,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: textMain,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (newTags.isEmpty)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      context.t.strings.legacy.msg_none,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: textMuted,
                                      ),
                                    ),
                                  )
                                else
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: newTags
                                          .map(
                                            (tag) => _TagChip(
                                              label: '#$tag',
                                              isDark: isDark,
                                            ),
                                          )
                                          .toList(growable: false),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          _ActionButton(
                            label: context.t.strings.legacy.msg_back_home,
                            onTap: onGoHome,
                            background: MemoFlowPalette.primary,
                            foreground: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          _ActionButton(
                            label: context
                                .t
                                .strings
                                .legacy
                                .msg_view_imported_memos,
                            onTap: onViewImported,
                            background: isDark
                                ? MemoFlowPalette.cardDark
                                : const Color(0xFFF0ECE6),
                            foreground: textMain,
                            border: divider,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ImportedMemosScreen extends StatelessWidget {
  const ImportedMemosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MemosListScreen(
      title: context.t.strings.legacy.msg_imported_memos_2,
      state: 'NORMAL',
      showDrawer: false,
      enableCompose: false,
      enableTitleMenu: false,
      showPillActions: false,
      showFilterTagChip: false,
      showTagFilters: true,
    );
  }
}

class _ImportSourceTile extends StatelessWidget {
  const _ImportSourceTile({
    required this.title,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.shadow,
    this.onHelp,
    this.onTap,
  });

  final String title;
  final Widget icon;
  final Color iconBg;
  final Color iconColor;
  final Color card;
  final Color textMain;
  final Color textMuted;
  final List<BoxShadow>? shadow;
  final VoidCallback? onHelp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            boxShadow: shadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(color: iconColor, size: 22),
                    child: DefaultTextStyle(
                      style: TextStyle(color: iconColor),
                      child: icon,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: context.t.strings.legacy.msg_import_format_help,
                      icon: const Icon(Icons.help_outline_rounded),
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                      style: IconButton.styleFrom(
                        shape: const CircleBorder(),
                        foregroundColor: textMuted,
                      ),
                      onPressed: onHelp,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 22, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportNoteCard extends StatelessWidget {
  const _ImportNoteCard({
    required this.text,
    required this.textMuted,
    required this.isDark,
  });

  final String text;
  final Color textMuted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? MemoFlowPalette.cardDark : const Color(0xFFF1ECE6);
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border.withValues(alpha: 0.75)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, height: 1.4, color: textMuted),
      ),
    );
  }
}

class _RoundedProgressBar extends StatelessWidget {
  const _RoundedProgressBar({required this.value, required this.isDark});

  final double value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 6,
        backgroundColor: bg,
        valueColor: AlwaysStoppedAnimation(MemoFlowPalette.primary),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: textMuted)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textMain,
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : MemoFlowPalette.primary.withValues(alpha: 0.1);
    final border = MemoFlowPalette.primary.withValues(
      alpha: isDark ? 0.5 : 0.6,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: MemoFlowPalette.primary,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.border,
  });

  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 50,
          width: double.infinity,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: border == null ? null : Border.all(color: border!),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
