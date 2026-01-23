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
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import '../memos/memos_list_screen.dart';
import 'flomo_import_service.dart';

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
    final displayName = fileName.isNotEmpty ? fileName : (path == null ? '' : p.basename(path));
    final bytes = file.bytes;

    if ((path == null || path.trim().isEmpty || !File(path).existsSync()) && bytes != null) {
      final tempDir = await getTemporaryDirectory();
      if (!context.mounted) return;
      final fallbackExt = (file.extension ?? '').trim().isNotEmpty ? file.extension!.trim() : 'zip';
      final safeName =
          _sanitizeFilename(displayName.isEmpty ? 'import.$fallbackExt' : displayName, fallbackExtension: fallbackExt);
      final tempPath = p.join(tempDir.path, safeName);
      await File(tempPath).writeAsBytes(bytes, flush: true);
      if (!context.mounted) return;
      path = tempPath;
    }

    if (path == null || path.trim().isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '无法获取文件路径', en: 'Unable to read file path.'))),
      );
      return;
    }

    if (!context.mounted) return;
    final resolvedPath = path;
    final shownName = displayName.isNotEmpty ? displayName : p.basename(resolvedPath);

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImportRunScreen(
          filePath: resolvedPath,
          fileName: shownName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
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
    final fallbackNotice = context.tr(zh: '暂未支持', en: 'Not supported yet');

    void fallbackTap() {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(fallbackNotice)));
    }

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
        title: Text(context.tr(zh: '导入', en: 'Import')),
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
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 8),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(
                              zh: '选择一个数据来源开始导入您的笔记',
                              en: 'Choose a data source to start importing your memos',
                            ),
                            style: TextStyle(fontSize: 12.5, height: 1.4, color: textMuted),
                          ),
                          const SizedBox(height: 16),
                          _ImportSourceTile(
                            title: context.tr(zh: '从 Flomo 导入', en: 'Import from Flomo'),
                            subtitle: context.tr(
                              zh: '导入导出的 HTML 或压缩包',
                              en: 'Import exported HTML or ZIP package',
                            ),
                            icon: Icons.auto_awesome_rounded,
                            iconBg: MemoFlowPalette.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                            iconColor: MemoFlowPalette.primary,
                            card: card,
                            textMain: textMain,
                            textMuted: textMuted,
                            shadow: shadow,
                            onTap: onSelectFlomo ?? () => _selectFlomoFile(context),
                          ),
                          const SizedBox(height: 12),
                          _ImportSourceTile(
                            title: context.tr(zh: '从 Markdown 导入', en: 'Import from Markdown'),
                            subtitle: context.tr(
                              zh: '请上传包含 .md 文件的 .zip 压缩包',
                              en: 'Upload a .zip package with .md files',
                            ),
                            icon: Icons.description_rounded,
                            iconBg: MemoFlowPalette.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                            iconColor: MemoFlowPalette.primary.withValues(alpha: 0.9),
                            card: card,
                            textMain: textMain,
                            textMuted: textMuted,
                            shadow: shadow,
                            onTap: onSelectMarkdown ?? fallbackTap,
                          ),
                          const Spacer(),
                          _ImportNoteCard(
                            text: context.tr(
                              zh: '导入完成后，您的笔记将自动同步到笔记列表。对于压缩包导入，请确保文件结构完整。',
                              en: 'After import, your memos sync to the list automatically. For ZIP imports, ensure the file structure is intact.',
                            ),
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

    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    if (account == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(zh: '未登录账号', en: 'Not authenticated.'))),
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
            onGoHome: () => Navigator.of(resultContext).popUntil((route) => route.isFirst),
            onViewImported: () => Navigator.of(resultContext).push(
              MaterialPageRoute<void>(builder: (_) => const ImportedMemosScreen()),
            ),
          ),
        ),
      );
    } on ImportCancelled {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '已取消导入', en: 'Import canceled.'))),
      );
      context.safePop();
    } on ImportException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      context.safePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '导入失败: $e', en: 'Import failed: $e'))),
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
      _statusText = context.tr(zh: '正在取消...', en: 'Cancelling...');
      _progressLabel = context.tr(zh: '取消中', en: 'Cancelling');
      _progressDetail = context.tr(zh: '正在等待任务停止', en: 'Waiting for tasks to stop');
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
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
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
    final label = progressLabel ?? context.tr(zh: '解析进度', en: 'Parsing progress');
    final status = statusText ?? context.tr(zh: '正在解析文件...', en: 'Parsing file...');
    final detail = progressDetail ?? context.tr(zh: '正在处理内容...', en: 'Processing content...');

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
        title: Text(context.tr(zh: '导入文件', en: 'Import File')),
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
                    colors: [
                      const Color(0xFF0B0B0B),
                      bg,
                      bg,
                    ],
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
                          color: MemoFlowPalette.primary.withValues(alpha: isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.insert_drive_file_rounded, color: MemoFlowPalette.primary, size: 26),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        status,
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: textMain),
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
                          Text(label, style: TextStyle(fontSize: 12.5, color: textMuted)),
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
                      _RoundedProgressBar(
                        value: clamped,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        detail,
                        style: TextStyle(fontSize: 12, color: textMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: onCancel ?? () => Navigator.of(context).maybePop(),
                        style: TextButton.styleFrom(
                          foregroundColor: MemoFlowPalette.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        ),
                        child: Text(context.tr(zh: '取消', en: 'Cancel')),
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
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
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

    String formatCount(int value, {String? suffix}) {
      final raw = formatter.format(value);
      return suffix == null ? raw : '$raw$suffix';
    }

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
        title: Text(context.tr(zh: '导入结果', en: 'Import Result')),
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
                    colors: [
                      const Color(0xFF0B0B0B),
                      bg,
                      bg,
                    ],
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
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 12),
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
                                    color: MemoFlowPalette.primary.withValues(alpha: isDark ? 0.22 : 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.check, color: MemoFlowPalette.primary, size: 28),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  context.tr(zh: '导入完成', en: 'Import Complete'),
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textMain),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  context.tr(
                                    zh: '您的数据已成功迁移至本应用。',
                                    en: 'Your data has been migrated to this app successfully.',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12.5, height: 1.4, color: textMuted),
                                ),
                                const SizedBox(height: 16),
                                Divider(height: 1, color: divider),
                                const SizedBox(height: 12),
                                _ResultRow(
                                  label: context.tr(zh: '导入笔记', en: 'Imported memos'),
                                  value: context.tr(
                                    zh: formatCount(memoCount, suffix: '条'),
                                    en: formatCount(memoCount),
                                  ),
                                  textMain: textMain,
                                  textMuted: textMuted,
                                ),
                                const SizedBox(height: 8),
                                _ResultRow(
                                  label: context.tr(zh: '附件资源', en: 'Attachments'),
                                  value: context.tr(
                                    zh: formatCount(attachmentCount, suffix: '个'),
                                    en: formatCount(attachmentCount),
                                  ),
                                  textMain: textMain,
                                  textMuted: textMuted,
                                ),
                                const SizedBox(height: 8),
                                _ResultRow(
                                  label: context.tr(zh: '失败条数', en: 'Failed items'),
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
                                    context.tr(zh: '新生成的标签', en: 'New tags created'),
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textMain),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (newTags.isEmpty)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      context.tr(zh: '无', en: 'None'),
                                      style: TextStyle(fontSize: 12.5, color: textMuted),
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
                            label: context.tr(zh: '返回主页', en: 'Back to Home'),
                            onTap: onGoHome,
                            background: MemoFlowPalette.primary,
                            foreground: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          _ActionButton(
                            label: context.tr(zh: '查看导入笔记', en: 'View imported memos'),
                            onTap: onViewImported,
                            background: isDark ? MemoFlowPalette.cardDark : const Color(0xFFF0ECE6),
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
      title: context.tr(zh: '查看导入笔记', en: 'Imported memos'),
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
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textMain),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, height: 1.3, color: textMuted),
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
    final border = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
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
  const _RoundedProgressBar({
    required this.value,
    required this.isDark,
  });

  final double value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
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
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMain)),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.isDark,
  });

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? Colors.white.withValues(alpha: 0.08) : MemoFlowPalette.primary.withValues(alpha: 0.1);
    final border = MemoFlowPalette.primary.withValues(alpha: isDark ? 0.5 : 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MemoFlowPalette.primary),
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
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
