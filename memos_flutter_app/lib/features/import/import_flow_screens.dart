import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/top_toast.dart';
import '../../state/database_provider.dart';
import '../../state/local_library_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import '../memos/memos_list_screen.dart';
import 'flomo_import_service.dart';
import '../../i18n/strings.g.dart';

class ImportSourceScreen extends StatelessWidget {
  const ImportSourceScreen({
    super.key,
    this.onSelectFlomo,
    this.onSelectMarkdown,
  });

  final VoidCallback? onSelectFlomo;
  final VoidCallback? onSelectMarkdown;

  String _sanitizeFilename(String input, {required String fallbackExtension}) {
    final trimmed = input.trim();
    final sanitized = trimmed.isEmpty ? 'import.$fallbackExtension' : trimmed;
    return sanitized.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  Future<void> _selectFlomoFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip', 'html', 'htm'],
      withData: true,
    );
    if (!context.mounted || result == null) return;

    final file = result.files.isNotEmpty ? result.files.first : null;
    if (file == null) return;

    var path = file.path;
    final fileName = file.name.trim();
    final displayName = fileName.isNotEmpty
        ? fileName
        : (path == null ? '' : p.basename(path));
    final bytes = file.bytes;

    if ((path == null || path.trim().isEmpty || !File(path).existsSync()) &&
        bytes != null) {
      final tempDir = await getTemporaryDirectory();
      if (!context.mounted) return;
      final fallbackExt = (file.extension ?? '').trim().isNotEmpty
          ? file.extension!.trim()
          : 'zip';
      final safeName = _sanitizeFilename(
        displayName.isEmpty ? 'import.$fallbackExt' : displayName,
        fallbackExtension: fallbackExt,
      );
      final tempPath = p.join(tempDir.path, safeName);
      await File(tempPath).writeAsBytes(bytes, flush: true);
      if (!context.mounted) return;
      path = tempPath;
    }

    if (path == null || path.trim().isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_unable_read_file_path),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final resolvedPath = path;
    final shownName = displayName.isNotEmpty
        ? displayName
        : p.basename(resolvedPath);

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ImportRunScreen(filePath: resolvedPath, fileName: shownName),
      ),
    );
  }

  Future<void> _selectMarkdownZip(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true,
    );
    if (!context.mounted || result == null) return;

    final file = result.files.isNotEmpty ? result.files.first : null;
    if (file == null) return;

    var path = file.path;
    final fileName = file.name.trim();
    final displayName = fileName.isNotEmpty
        ? fileName
        : (path == null ? '' : p.basename(path));
    final bytes = file.bytes;

    if ((path == null || path.trim().isEmpty || !File(path).existsSync()) &&
        bytes != null) {
      final tempDir = await getTemporaryDirectory();
      if (!context.mounted) return;
      final fallbackExt = (file.extension ?? '').trim().isNotEmpty
          ? file.extension!.trim()
          : 'zip';
      final safeName = _sanitizeFilename(
        displayName.isEmpty ? 'import.$fallbackExt' : displayName,
        fallbackExtension: fallbackExt,
      );
      final tempPath = p.join(tempDir.path, safeName);
      await File(tempPath).writeAsBytes(bytes, flush: true);
      if (!context.mounted) return;
      path = tempPath;
    }

    if (path == null || path.trim().isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_unable_read_file_path),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final resolvedPath = path;
    final shownName = displayName.isNotEmpty
        ? displayName
        : p.basename(resolvedPath);

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ImportRunScreen(filePath: resolvedPath, fileName: shownName),
      ),
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
        title: Text(context.t.strings.legacy.msg_import),
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
                            title: context.t.strings.legacy.msg_import_flomo,
                            subtitle: context
                                .t
                                .strings
                                .legacy
                                .msg_import_exported_html_zip_package,
                            icon: Icons.auto_awesome_rounded,
                            iconBg: MemoFlowPalette.primary.withValues(
                              alpha: isDark ? 0.2 : 0.12,
                            ),
                            iconColor: MemoFlowPalette.primary,
                            card: card,
                            textMain: textMain,
                            textMuted: textMuted,
                            shadow: shadow,
                            onTap:
                                onSelectFlomo ??
                                () => _selectFlomoFile(context),
                          ),
                          const SizedBox(height: 12),
                          _ImportSourceTile(
                            title: context.t.strings.legacy.msg_import_markdown,
                            subtitle: context
                                .t
                                .strings
                                .legacy
                                .msg_upload_zip_package_md_files,
                            icon: Icons.description_rounded,
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
                            onTap:
                                onSelectMarkdown ??
                                () => _selectMarkdownZip(context),
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

class ImportRunScreen extends ConsumerStatefulWidget {
  const ImportRunScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  final String filePath;
  final String fileName;

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

    final session = ref.read(appSessionProvider).valueOrNull;
    final account = session?.currentAccount;
    final isLocalLibraryMode = ref.read(isLocalLibraryModeProvider);
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
    final language = ref.read(appPreferencesProvider).language;
    final importer = FlomoImportService(
      db: db,
      account: account,
      importScopeKey: session?.currentKey,
      language: language,
    );

    try {
      final result = await importer.importFile(
        filePath: widget.filePath,
        onProgress: _handleProgress,
        isCancelled: () => _cancelRequested,
      );
      if (!mounted) return;

      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (resultContext) => ImportResultScreen(
            memoCount: result.memoCount,
            attachmentCount: result.attachmentCount,
            failedCount: result.failedCount,
            newTags: result.newTags,
            onGoHome: () =>
                Navigator.of(resultContext).popUntil((route) => route.isFirst),
            onViewImported: () => Navigator.of(resultContext).push(
              MaterialPageRoute<void>(
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      context.safePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_import_failed(e: e)),
        ),
      );
      context.safePop();
    }
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
        title: Text(context.t.strings.legacy.msg_import_file),
        centerTitle: true,
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
        title: Text(context.t.strings.legacy.msg_import_result),
        centerTitle: true,
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
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.shadow,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color card;
  final Color textMain;
  final Color textMuted;
  final List<BoxShadow>? shadow;
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
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: textMuted,
                      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: MemoFlowPalette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, height: 1.4, color: textMuted),
            ),
          ),
        ],
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
