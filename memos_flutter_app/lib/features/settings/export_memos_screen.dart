import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:saf_stream/saf_stream.dart';

import '../../core/attachment_url.dart';
import '../../core/app_localization.dart';
import '../../core/memo_relations.dart';
import '../../core/top_toast.dart';
import '../../data/local_library/local_library_markdown.dart';
import '../../data/local_library/local_library_memo_sidecar.dart';
import '../../data/models/attachment.dart';
import '../../data/models/app_preferences.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_clip_card_metadata.dart';
import '../../i18n/strings.g.dart';
import '../../platform/widgets/platform_controls.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../../state/system/database_provider.dart';
import '../../state/system/session_provider.dart';
import 'settings_ui.dart';

class ExportMemosScreen extends ConsumerStatefulWidget {
  const ExportMemosScreen({super.key});

  @override
  ConsumerState<ExportMemosScreen> createState() => _ExportMemosScreenState();
}

class _ExportMemosScreenState extends ConsumerState<ExportMemosScreen> {
  DateTimeRange? _range;
  var _includeArchived = false;
  var _exporting = false;
  String? _lastExportPath;

  String _formatRange(DateTimeRange? range, AppLanguage language) {
    if (range == null) {
      return trByLanguageKey(language: language, key: 'legacy.msg_all_2');
    }
    final fmt = DateFormat('yyyy-MM-dd');
    return '${fmt.format(range.start)} ~ ${fmt.format(range.end)}';
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial =
        _range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );
    if (picked == null) return;
    setState(() => _range = picked);
  }

  (int? startSec, int? endSecExclusive) _rangeToUtcSec(DateTimeRange? range) {
    if (range == null) return (null, null);
    final startLocal = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final endLocalExclusive = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    ).add(const Duration(days: 1));
    return (
      startLocal.toUtc().millisecondsSinceEpoch ~/ 1000,
      endLocalExclusive.toUtc().millisecondsSinceEpoch ~/ 1000,
    );
  }

  String _memoFilename(LocalMemo memo) {
    final ts = DateFormat('yyyyMMdd_HHmmss').format(memo.createTime);
    final safeUid = memo.uid
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
        .padRight(8, '_')
        .substring(0, 8);
    return '${ts}_$safeUid.md';
  }

  String _sanitizePathSegment(String raw, {String fallback = 'attachment'}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return fallback;
    return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _attachmentArchiveName(Attachment attachment) {
    final rawName = attachment.filename.trim().isNotEmpty
        ? attachment.filename.trim()
        : (attachment.uid.isNotEmpty ? attachment.uid : attachment.name);
    final safeName = _sanitizePathSegment(rawName, fallback: 'attachment');
    final uid = attachment.uid.trim();
    if (uid.isEmpty) return safeName;
    if (safeName.startsWith('$uid.')) return safeName;
    if (safeName == uid) return safeName;
    return '${uid}_$safeName';
  }

  File? _localAttachmentFile(Attachment attachment) {
    final raw = attachment.externalLink.trim();
    if (!raw.startsWith('file://')) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final path = uri.toFilePath();
    if (path.trim().isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file;
  }

  String? _resolveAttachmentUrl(Uri? baseUrl, Attachment attachment) {
    return resolveAttachmentRemoteUrl(baseUrl, attachment);
  }

  Future<List<int>?> _readAttachmentBytes(
    Attachment attachment, {
    required Uri? baseUrl,
    required String? authHeader,
    Dio? dio,
  }) async {
    final localFile = _localAttachmentFile(attachment);
    if (localFile != null) {
      return localFile.readAsBytes();
    }

    final contentUri = attachment.externalLink.trim();
    if (contentUri.startsWith('content://')) {
      return SafStream().readFileBytes(contentUri);
    }

    final url = _resolveAttachmentUrl(baseUrl, attachment);
    if (url == null || url.isEmpty) return null;

    final client = dio ?? Dio();
    final response = await client.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: authHeader == null ? null : {'Authorization': authHeader},
      ),
    );
    return response.data;
  }

  Future<Directory?> _tryGetDownloadsDirectory() async {
    try {
      return await getDownloadsDirectory();
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _resolveExportDirectory() async {
    if (Platform.isAndroid) {
      final candidates = <Directory>[
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Downloads'),
      ];
      for (final dir in candidates) {
        if (await dir.exists()) return dir;
      }

      final external = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (external != null && external.isNotEmpty) return external.first;

      final fallback = await getExternalStorageDirectory();
      if (fallback != null) return fallback;
    }

    final downloads = await _tryGetDownloadsDirectory();
    if (downloads != null) return downloads;
    return getApplicationDocumentsDirectory();
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    showTopToast(
      context,
      context.t.strings.legacy.msg_exporting,
      duration: const Duration(seconds: 30),
    );
    final language = ref.read(devicePreferencesProvider).language;
    final account = ref.read(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final authHeader = (account?.personalAccessToken ?? '').isEmpty
        ? null
        : 'Bearer ${account!.personalAccessToken}';
    try {
      final db = ref.read(databaseProvider);
      final (startSec, endSecExclusive) = _rangeToUtcSec(_range);
      final rows = await db.listMemosForLosslessExport(
        startTimeSec: startSec,
        endTimeSecExclusive: endSecExclusive,
        includeArchived: _includeArchived,
      );
      final memos = rows
          .map(
            (row) => (
              row: row,
              memo: LocalMemo.fromDb(row),
              relationsJson: row['relations_json'] as String?,
            ),
          )
          .where((entry) => entry.memo.uid.isNotEmpty)
          .toList(growable: false);
      final totalMemoCount = rows.length;
      final exportedMemoCount = memos.length;
      final skippedMemoCount = totalMemoCount - exportedMemoCount;
      final relationSnapshotsByUid = <String, MemoRelationsSidecarSnapshot>{};

      final archive = Archive();
      final indexLines = <String>[
        trByLanguageKey(language: language, key: 'legacy.msg_memoflow_export'),
        '',
        '${trByLanguageKey(language: language, key: 'legacy.msg_export_time')}: ${DateTime.now().toIso8601String()}',
        '${trByLanguageKey(language: language, key: 'legacy.msg_date_range_4')}: ${_formatRange(_range, language)}',
        '${trByLanguageKey(language: language, key: 'legacy.msg_include_archived_2')}: ${_includeArchived ? trByLanguageKey(language: language, key: 'legacy.msg_yes') : trByLanguageKey(language: language, key: 'legacy.msg_no')}',
        '${trByLanguageKey(language: language, key: 'legacy.msg_count')}: $exportedMemoCount',
        '',
      ];
      final indexBytes = utf8.encode(indexLines.join('\n'));
      archive.addFile(ArchiveFile('index.md', indexBytes.length, indexBytes));

      for (final memoEntry in memos) {
        final memo = memoEntry.memo;
        final filename = _memoFilename(memo);
        final content = utf8.encode(buildLocalLibraryMarkdown(memo));
        archive.addFile(
          ArchiveFile('memos/$filename', content.length, content),
        );
      }

      var exportedAttachmentCount = 0;
      var skippedAttachmentCount = 0;
      final usedAttachmentPaths = <String>{};
      final sidecarsByUid = <String, LocalLibraryMemoSidecar>{};
      final clipCardsByUid = <String, MemoClipCardMetadata>{};
      final httpClient = Dio();
      for (final memoEntry in memos) {
        final memo = memoEntry.memo;
        final clipCardRow = await db.getMemoClipCardByUid(memo.uid);
        if (clipCardRow != null) {
          clipCardsByUid[memo.uid] = MemoClipCardMetadata.fromDb(clipCardRow);
        }
        if (memo.attachments.isEmpty) continue;
        final memoDir = _sanitizePathSegment(memo.uid, fallback: 'memo');
        final sidecarAttachments = <LocalLibraryAttachmentExportMeta>[];
        for (final attachment in memo.attachments) {
          try {
            final bytes = await _readAttachmentBytes(
              attachment,
              baseUrl: baseUrl,
              authHeader: authHeader,
              dio: httpClient,
            );
            if (bytes == null) {
              skippedAttachmentCount++;
              continue;
            }
            final name = _attachmentArchiveName(attachment);
            var entryPath = 'attachments/$memoDir/$name';
            if (usedAttachmentPaths.contains(entryPath)) {
              final base = p.basenameWithoutExtension(name);
              final ext = p.extension(name);
              var index = 1;
              do {
                entryPath = 'attachments/$memoDir/$base ($index)$ext';
                index++;
              } while (usedAttachmentPaths.contains(entryPath));
            }
            usedAttachmentPaths.add(entryPath);
            archive.addFile(ArchiveFile(entryPath, bytes.length, bytes));
            sidecarAttachments.add(
              LocalLibraryAttachmentExportMeta.fromAttachment(
                attachment: attachment,
                archiveName: p.basename(entryPath),
              ),
            );
            exportedAttachmentCount++;
          } catch (_) {
            skippedAttachmentCount++;
          }
        }

        final relationsJson = memoEntry.relationsJson;
        final relationSnapshot = resolveMemoRelationsSidecarSnapshot(
          relationCount: memo.relationCount,
          relationsJson: relationsJson,
        );
        relationSnapshotsByUid[memo.uid] = relationSnapshot;
        sidecarsByUid[memo.uid] = LocalLibraryMemoSidecar.fromMemo(
          memo: memo,
          hasRelations: true,
          relations: relationSnapshot.relations,
          attachments: sidecarAttachments,
          clipCard: clipCardsByUid[memo.uid],
          relationCount: relationSnapshot.relationCount,
          relationsComplete: relationSnapshot.relationsComplete,
        );
      }

      for (final memoEntry in memos) {
        final memo = memoEntry.memo;
        final relationSnapshot =
            relationSnapshotsByUid[memo.uid] ??
            resolveMemoRelationsSidecarSnapshot(
              relationCount: memo.relationCount,
              relationsJson: memoEntry.relationsJson,
            );
        final sidecar =
            sidecarsByUid[memo.uid] ??
            LocalLibraryMemoSidecar.fromMemo(
              memo: memo,
              hasRelations: true,
              relations: relationSnapshot.relations,
              attachments: const [],
              clipCard: clipCardsByUid[memo.uid],
              relationCount: relationSnapshot.relationCount,
              relationsComplete: relationSnapshot.relationsComplete,
            );
        final content = utf8.encode(sidecar.encodeJson());
        archive.addFile(
          ArchiveFile('memos/_meta/${memo.uid}.json', content.length, content),
        );
      }

      final zipData = ZipEncoder().encode(archive);

      final rootDir = await _resolveExportDirectory();
      final exportDir = Directory(p.join(rootDir.path, 'exports'));
      if (!exportDir.existsSync()) {
        exportDir.createSync(recursive: true);
      }
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final outPath = p.join(exportDir.path, 'MemoFlow_export_$now.zip');
      await File(outPath).writeAsBytes(zipData, flush: true);

      if (!mounted) return;
      setState(() => _lastExportPath = outPath);
      await showPlatformAlertDialog<bool>(
        context: context,
        barrierDismissible: false,
        title: context.t.strings.legacy.msg_export_finished,
        message: context.t.strings.legacy.msg_memos_skipped_attachments_skipped(
          exportedMemoCount: exportedMemoCount,
          skippedMemoCount: skippedMemoCount,
          exportedAttachmentCount: exportedAttachmentCount,
          skippedAttachmentCount: skippedAttachmentCount,
        ),
        actions: [
          PlatformDialogAction<bool>(
            value: true,
            label: context.t.strings.legacy.msg_ok,
            isDefault: true,
          ),
        ],
      );
    } catch (e) {
      if (!mounted) return;
      showTopToast(context, context.t.strings.legacy.msg_export_failed(e: e));
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(
      devicePreferencesProvider.select((p) => p.language),
    );
    final hapticsEnabled = ref.watch(
      devicePreferencesProvider.select((p) => p.hapticsEnabled),
    );

    void haptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    void copyLastExportPath() {
      final path = _lastExportPath;
      if (path == null) return;
      haptic();
      Clipboard.setData(ClipboardData(text: path)).then((_) {
        if (!context.mounted) return;
        showTopToast(context, context.t.strings.legacy.msg_path_copied);
      });
    }

    return SettingsPage(
      title: Text(context.t.strings.legacy.msg_export),
      children: [
        SettingsSection(
          children: [
            SettingsValueRow(
              label: context.t.strings.legacy.msg_date_range,
              value: _formatRange(_range, language),
              icon: Icons.date_range_outlined,
              onTap: () {
                haptic();
                _pickRange();
              },
            ),
            SettingsToggleRow(
              label: context.t.strings.legacy.msg_include_archived,
              value: _includeArchived,
              onChanged: (v) {
                haptic();
                setState(() => _includeArchived = v);
              },
            ),
            SettingsValueRow(
              label: context.t.strings.legacy.msg_export_format,
              value: 'Markdown + ZIP',
              icon: Icons.description_outlined,
              onTap: () {
                haptic();
                showTopToast(
                  context,
                  context.t.strings.legacy.msg_format_fixed_markdown_zip,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SettingsAction(
            key: const ValueKey<String>('exportMemos.exportAction'),
            onPressed: _exporting
                ? null
                : () {
                    haptic();
                    _export();
                  },
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: PlatformProgress(),
                  )
                : const Icon(Icons.download_outlined),
            label: Text(context.t.strings.legacy.msg_export),
          ),
        ),
        if (_lastExportPath != null) ...[
          const SizedBox(height: 12),
          SettingsSection(
            children: [
              SettingsValueRow(
                label: context.t.strings.legacy.msg_copy_path,
                value: _lastExportPath!,
                icon: Icons.copy,
                onTap: copyLastExportPath,
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        SettingsSection(
          children: [
            SettingsInfoRow(
              description: context
                  .t
                  .strings
                  .legacy
                  .msg_note_export_includes_content_already_synced,
            ),
          ],
        ),
      ],
    );
  }
}
