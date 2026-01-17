import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../core/tags.dart';
import '../../core/url.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import 'memo_editor_screen.dart';
import 'memo_markdown.dart';

class MemoDetailScreen extends ConsumerStatefulWidget {
  const MemoDetailScreen({super.key, required this.initialMemo});

  final LocalMemo initialMemo;

  @override
  ConsumerState<MemoDetailScreen> createState() => _MemoDetailScreenState();
}

class _MemoDetailScreenState extends ConsumerState<MemoDetailScreen> {
  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final _player = AudioPlayer();

  LocalMemo? _memo;
  String? _currentAudioUrl;

  @override
  void initState() {
    super.initState();
    _memo = widget.initialMemo;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final uid = _memo?.uid ?? widget.initialMemo.uid;
    final row = await ref.read(databaseProvider).getMemoByUid(uid);
    if (row == null) return;
    if (!mounted) return;
    setState(() => _memo = LocalMemo.fromDb(row));
  }

  Future<void> _togglePinned() async {
    final memo = _memo;
    if (memo == null) return;
    await _updateLocalAndEnqueue(
      memo: memo,
      pinned: !memo.pinned,
    );
    await _reload();
  }

  Future<void> _toggleArchived() async {
    final memo = _memo;
    if (memo == null) return;
    final next = memo.state == 'ARCHIVED' ? 'NORMAL' : 'ARCHIVED';
    await _updateLocalAndEnqueue(
      memo: memo,
      state: next,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _edit() async {
    final memo = _memo;
    if (memo == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MemoEditorScreen(existing: memo)),
    );
    await _reload();
  }

  Future<void> _delete() async {
    final memo = _memo;
    if (memo == null) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr(zh: '删除 Memo？', en: 'Delete memo?')),
            content: Text(context.tr(
              zh: '本地会立即移除，联网后将同步删除服务器内容。',
              en: 'It will be removed locally now and deleted on the server when online.',
            )),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.tr(zh: '取消', en: 'Cancel'))),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.tr(zh: '删除', en: 'Delete'))),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    final db = ref.read(databaseProvider);
    await db.deleteMemoByUid(memo.uid);
    await db.enqueueOutbox(type: 'delete_memo', payload: {'uid': memo.uid, 'force': false});
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _updateLocalAndEnqueue({
    required LocalMemo memo,
    bool? pinned,
    String? state,
  }) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    await db.upsertMemo(
      uid: memo.uid,
      content: memo.content,
      visibility: memo.visibility,
      pinned: pinned ?? memo.pinned,
      state: state ?? memo.state,
      createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
      updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      tags: memo.tags,
      attachments: memo.attachments.map((a) => a.toJson()).toList(growable: false),
      syncState: 1,
      lastError: null,
    );

    await db.enqueueOutbox(type: 'update_memo', payload: {
      'uid': memo.uid,
      if (pinned != null) 'pinned': pinned,
      if (state != null) 'state': state,
    });
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());
  }

  static final RegExp _taskLinePattern = RegExp(r'^\s*(?:>\s*)?(?:[-*+]|\d+[.)])\s+\[( |x|X)\]');
  static final RegExp _codeFencePattern = RegExp(r'^\s*```');

  Future<void> _toggleTask(TaskToggleRequest request, {required bool skipReferenceLines}) async {
    final memo = _memo;
    if (memo == null) return;
    final updated = _applyTaskToggle(
      memo.content,
      request.taskIndex,
      checked: request.checked,
      skipReferenceLines: skipReferenceLines,
    );
    if (updated == null || updated == memo.content) return;

    final now = DateTime.now();
    final tags = extractTags(updated);
    final db = ref.read(databaseProvider);

    try {
      await db.upsertMemo(
        uid: memo.uid,
        content: updated,
        visibility: memo.visibility,
        pinned: memo.pinned,
        state: memo.state,
        createTimeSec: memo.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
        updateTimeSec: now.toUtc().millisecondsSinceEpoch ~/ 1000,
        tags: tags,
        attachments: memo.attachments.map((a) => a.toJson()).toList(growable: false),
        syncState: 1,
        lastError: null,
      );

      await db.enqueueOutbox(type: 'update_memo', payload: {
        'uid': memo.uid,
        'content': updated,
        'visibility': memo.visibility,
        'pinned': memo.pinned,
      });
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());

      if (!mounted) return;
      setState(() {
        _memo = LocalMemo(
          uid: memo.uid,
          content: updated,
          visibility: memo.visibility,
          pinned: memo.pinned,
          state: memo.state,
          createTime: memo.createTime,
          updateTime: now,
          tags: tags,
          attachments: memo.attachments,
          syncState: SyncState.pending,
          lastError: null,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  String? _applyTaskToggle(
    String content,
    int taskIndex, {
    required bool checked,
    required bool skipReferenceLines,
  }) {
    final lines = content.split('\n');
    var currentIndex = 0;
    var inCodeBlock = false;

    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trimLeft();
      if (_codeFencePattern.hasMatch(trimmed)) {
        inCodeBlock = !inCodeBlock;
        continue;
      }
      if (inCodeBlock) continue;
      if (skipReferenceLines && trimmed.startsWith('>')) continue;

      final match = _taskLinePattern.firstMatch(lines[i]);
      if (match == null) continue;
      if (currentIndex == taskIndex) {
        lines[i] = _toggleTaskLine(lines[i], checked);
        return lines.join('\n');
      }
      currentIndex++;
    }

    return null;
  }

  String _toggleTaskLine(String line, bool checked) {
    final match = _taskLinePattern.firstMatch(line);
    if (match == null) return line;
    final fullMatch = match.group(0);
    if (fullMatch == null) return line;
    final bracketIndex = fullMatch.indexOf('[');
    if (bracketIndex < 0) return line;
    final start = match.start + bracketIndex + 1;
    final replacement = checked ? ' ' : 'x';
    return line.replaceRange(start, start + 1, replacement);
  }

  String _attachmentUrl(Uri baseUrl, Attachment a, {required bool thumbnail}) {
    if (a.externalLink.isNotEmpty) return a.externalLink;
    final url = joinBaseUrl(baseUrl, 'file/${a.name}/${a.filename}');
    return thumbnail ? '$url?thumbnail=true' : url;
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

  Future<void> _togglePlayAudio(String url, {Map<String, String>? headers}) async {
    if (_currentAudioUrl == url) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }

    setState(() => _currentAudioUrl = url);
    try {
      await _player.setUrl(url, headers: headers);
      await _player.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '播放失败：$e', en: 'Playback failed: $e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final memo = _memo;
    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final authHeader = (account?.personalAccessToken ?? '').isEmpty ? null : 'Bearer ${account!.personalAccessToken}';
    final prefs = ref.watch(appPreferencesProvider);
    final hapticsEnabled = prefs.hapticsEnabled;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    void maybeHaptic() {
      if (!hapticsEnabled) return;
      HapticFeedback.selectionClick();
    }

    if (memo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isArchived = memo.state == 'ARCHIVED';
    final contentSplit = _MemoContentSplit.fromContent(memo.content);
    final showCollapsedReferences = prefs.collapseReferences && contentSplit.references.isNotEmpty && contentSplit.main.isNotEmpty;
    final contentStyle = Theme.of(context).textTheme.bodyLarge;

    final contentWidget = showCollapsedReferences
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CollapsibleText(
                text: contentSplit.main,
                collapseEnabled: prefs.collapseLongContent,
                style: contentStyle,
                hapticsEnabled: hapticsEnabled,
                onToggleTask: (request) {
                  maybeHaptic();
                  unawaited(_toggleTask(request, skipReferenceLines: true));
                },
              ),
              const SizedBox(height: 12),
              _ReferencesSection(
                references: contentSplit.references,
                lineCount: contentSplit.referenceLineCount,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                hapticsEnabled: hapticsEnabled,
              ),
            ],
          )
        : _CollapsibleText(
            text: memo.content,
            collapseEnabled: prefs.collapseLongContent,
            style: contentStyle,
            hapticsEnabled: hapticsEnabled,
            onToggleTask: (request) {
              maybeHaptic();
              unawaited(_toggleTask(request, skipReferenceLines: false));
            },
          );

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _dateFmt.format(memo.updateTime),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        contentWidget,
        const SizedBox(height: 12),
        if (memo.tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: memo.tags.map((t) => Chip(label: Text('#$t'))).toList(growable: false),
          ),
        if (memo.lastError != null && memo.lastError!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  memo.lastError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        maybeHaptic();
                        unawaited(ref.read(syncControllerProvider.notifier).syncNow());
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.tr(zh: '已开始重试同步', en: 'Retry started'))),
                        );
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(context.tr(zh: '重试同步', en: 'Retry sync')),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        maybeHaptic();
                        await Clipboard.setData(ClipboardData(text: memo.lastError!));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.tr(zh: '已复制错误信息', en: 'Error copied'))),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(context.tr(zh: '复制', en: 'Copy')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: cardColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(isArchived ? context.tr(zh: '已归档', en: 'Archived') : context.tr(zh: '笔记', en: 'Memo')),
        actions: [
          IconButton(
            tooltip: context.tr(zh: '编辑', en: 'Edit'),
            onPressed: () {
              maybeHaptic();
              unawaited(_edit());
            },
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            tooltip: memo.pinned ? context.tr(zh: '取消置顶', en: 'Unpin') : context.tr(zh: '置顶', en: 'Pin'),
            onPressed: () {
              maybeHaptic();
              unawaited(_togglePinned());
            },
            icon: Icon(memo.pinned ? Icons.push_pin : Icons.push_pin_outlined),
          ),
          IconButton(
            tooltip: isArchived ? context.tr(zh: '取消归档', en: 'Unarchive') : context.tr(zh: '归档', en: 'Archive'),
            onPressed: () {
              maybeHaptic();
              unawaited(_toggleArchived());
            },
            icon: Icon(isArchived ? Icons.unarchive : Icons.archive),
          ),
          IconButton(
            tooltip: context.tr(zh: '删除', en: 'Delete'),
            onPressed: () {
              maybeHaptic();
              unawaited(_delete());
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Hero(
              tag: memo.uid,
              createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
              flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                final fromHero = fromHeroContext.widget as Hero;
                final toHero = toHeroContext.widget as Hero;
                final child = flightDirection == HeroFlightDirection.push ? fromHero.child : toHero.child;
                return Material(color: Colors.transparent, child: RepaintBoundary(child: child));
              },
              child: RepaintBoundary(child: Container(color: cardColor)),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                header,
                _MemoRelationsSection(memoUid: memo.uid),
                if (memo.attachments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(context.tr(zh: '附件', en: 'Attachments'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...memo.attachments.map(
                    (a) {
                      final type = a.type;
                      final isImage = type.startsWith('image/');
                      final isAudio = type.startsWith('audio');
                      final localFile = _localAttachmentFile(a);
    
                      final url = (baseUrl == null) ? '' : _attachmentUrl(baseUrl, a, thumbnail: isImage);
                      final fullUrl = (baseUrl == null) ? '' : _attachmentUrl(baseUrl, a, thumbnail: false);
    
                      if (isImage && localFile != null) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              localFile,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      }
    
                      if (isImage && baseUrl != null && url.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => _ImageViewerScreen(
                                    imageUrl: fullUrl,
                                    authHeader: authHeader,
                                    title: a.filename,
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: url,
                                httpHeaders: authHeader == null ? null : {'Authorization': authHeader},
                                fit: BoxFit.cover,
                                placeholder: (context, _) => const SizedBox(
                                  height: 160,
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                                errorWidget: (context, url, error) =>
                                    const SizedBox(height: 160, child: Icon(Icons.broken_image)),
                              ),
                            ),
                          ),
                        );
                      }
    
                      if (isAudio && baseUrl != null && fullUrl.isNotEmpty) {
                        return StreamBuilder<PlayerState>(
                          stream: _player.playerStateStream,
                          builder: (context, snap) {
                            final playing = _player.playing && _currentAudioUrl == fullUrl;
                            return ListTile(
                              leading: Icon(playing ? Icons.pause : Icons.play_arrow),
                              title: Text(a.filename),
                              subtitle: Text(a.type),
                              onTap: () => _togglePlayAudio(
                                fullUrl,
                                headers: authHeader == null ? null : {'Authorization': authHeader},
                              ),
                            );
                          },
                        );
                      }
    
                      return ListTile(
                        leading: const Icon(Icons.attach_file),
                        title: Text(a.filename),
                        subtitle: Text(a.type),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoRelationsSection extends ConsumerWidget {
  const _MemoRelationsSection({required this.memoUid});

  final String memoUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relationsAsync = ref.watch(memoRelationsProvider(memoUid));
    return relationsAsync.when(
      data: (relations) {
        if (relations.isEmpty) return const SizedBox.shrink();

        final currentName = 'memos/$memoUid';
        final referencing = <_RelationLinkItem>[];
        final referencedBy = <_RelationLinkItem>[];
        final seenReferencing = <String>{};
        final seenReferencedBy = <String>{};

        for (final relation in relations) {
          final memoName = relation.memo.name.trim();
          final relatedName = relation.relatedMemo.name.trim();

          if (memoName == currentName && relatedName.isNotEmpty) {
            if (seenReferencing.add(relatedName)) {
              referencing.add(
                _RelationLinkItem(
                  name: relatedName,
                  snippet: relation.relatedMemo.snippet,
                ),
              );
            }
            continue;
          }
          if (relatedName == currentName && memoName.isNotEmpty) {
            if (seenReferencedBy.add(memoName)) {
              referencedBy.add(
                _RelationLinkItem(
                  name: memoName,
                  snippet: relation.memo.snippet,
                ),
              );
            }
          }
        }

        if (referencing.isEmpty && referencedBy.isEmpty) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final borderColor = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
        final bg = isDark ? MemoFlowPalette.audioSurfaceDark : MemoFlowPalette.audioSurfaceLight;
        final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
        final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.7);
        final chipBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
        final total = referencing.length + referencedBy.length;

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link, size: 16, color: textMuted),
                  const SizedBox(width: 6),
                  Text(
                    context.tr(zh: '双链', en: 'Links'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMain),
                  ),
                  const SizedBox(width: 6),
                  Text('$total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted)),
                ],
              ),
              const SizedBox(height: 10),
              if (referencing.isNotEmpty)
                _RelationGroup(
                  title: context.tr(zh: '引用了', en: 'References'),
                  items: referencing,
                  isDark: isDark,
                  borderColor: borderColor,
                  bg: bg,
                  textMain: textMain,
                  textMuted: textMuted,
                  chipBg: chipBg,
                  onTap: (item) => _openMemo(context, ref, item.name),
                ),
              if (referencing.isNotEmpty && referencedBy.isNotEmpty) const SizedBox(height: 10),
              if (referencedBy.isNotEmpty)
                _RelationGroup(
                  title: context.tr(zh: '被引用', en: 'Referenced by'),
                  items: referencedBy,
                  isDark: isDark,
                  borderColor: borderColor,
                  bg: bg,
                  textMain: textMain,
                  textMuted: textMuted,
                  chipBg: chipBg,
                  onTap: (item) => _openMemo(context, ref, item.name),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }

  Future<void> _openMemo(BuildContext context, WidgetRef ref, String rawName) async {
    final uid = _normalizeMemoUid(rawName);
    if (uid.isEmpty || uid == memoUid) return;

    final db = ref.read(databaseProvider);
    final row = await db.getMemoByUid(uid);
    LocalMemo? memo = row == null ? null : LocalMemo.fromDb(row);

    if (memo == null) {
      try {
        final api = ref.read(memosApiProvider);
        final remote = await api.getMemo(memoUid: uid);
        final remoteUid = remote.uid.isNotEmpty ? remote.uid : uid;
        await db.upsertMemo(
          uid: remoteUid,
          content: remote.content,
          visibility: remote.visibility,
          pinned: remote.pinned,
          state: remote.state,
          createTimeSec: remote.createTime.toUtc().millisecondsSinceEpoch ~/ 1000,
          updateTimeSec: remote.updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
          tags: remote.tags,
          attachments: remote.attachments.map((a) => a.toJson()).toList(growable: false),
          syncState: 0,
        );
        final refreshed = await db.getMemoByUid(remoteUid);
        if (refreshed != null) {
          memo = LocalMemo.fromDb(refreshed);
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(zh: '加载失败：$e', en: 'Failed to load: $e'))),
        );
        return;
      }
    }

    if (memo == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '本地暂无该笔记', en: 'Memo not found locally'))),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MemoDetailScreen(initialMemo: memo!)));
  }

  String _normalizeMemoUid(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('memos/')) return trimmed.substring('memos/'.length);
    return trimmed;
  }
}

class _RelationLinkItem {
  const _RelationLinkItem({required this.name, required this.snippet});

  final String name;
  final String snippet;
}

class _RelationGroup extends StatelessWidget {
  const _RelationGroup({
    required this.title,
    required this.items,
    required this.isDark,
    required this.borderColor,
    required this.bg,
    required this.textMain,
    required this.textMuted,
    required this.chipBg,
    required this.onTap,
  });

  final String title;
  final List<_RelationLinkItem> items;
  final bool isDark;
  final Color borderColor;
  final Color bg;
  final Color textMain;
  final Color textMuted;
  final Color chipBg;
  final ValueChanged<_RelationLinkItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 14, color: textMuted),
              const SizedBox(width: 6),
              Text(
                '$title (${items.length})',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onTap(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _shortMemoId(item.name),
                          style: TextStyle(fontSize: 10, color: textMuted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _relationSnippet(item),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: textMain),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right, size: 16, color: textMuted),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _relationSnippet(_RelationLinkItem item) {
    final snippet = item.snippet.trim();
    if (snippet.isNotEmpty) return snippet;
    final name = item.name.trim();
    if (name.isNotEmpty) return name;
    return '';
  }

  static String _shortMemoId(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '--';
    final raw = trimmed.startsWith('memos/') ? trimmed.substring('memos/'.length) : trimmed;
    return raw.length <= 6 ? raw : raw.substring(0, 6);
  }
}

class _MemoContentSplit {
  const _MemoContentSplit({
    required this.main,
    required this.references,
    required this.referenceLineCount,
  });

  final String main;
  final String references;
  final int referenceLineCount;

  factory _MemoContentSplit.fromContent(String content) {
    final trimmed = content.trim();
    final lines = trimmed.split('\n');
    final mainLines = <String>[];
    final referenceLines = <String>[];

    for (final line in lines) {
      if (line.trimLeft().startsWith('>')) {
        referenceLines.add(line.replaceFirst(RegExp(r'^\\s*>\\s?'), ''));
        continue;
      }
      mainLines.add(line);
    }

    return _MemoContentSplit(
      main: mainLines.join('\n').trim(),
      references: referenceLines.join('\n').trim(),
      referenceLineCount: referenceLines.length,
    );
  }
}

class _CollapsibleText extends StatefulWidget {
  const _CollapsibleText({
    required this.text,
    required this.collapseEnabled,
    required this.style,
    required this.hapticsEnabled,
    this.onToggleTask,
  });

  final String text;
  final bool collapseEnabled;
  final TextStyle? style;
  final bool hapticsEnabled;
  final ValueChanged<TaskToggleRequest>? onToggleTask;

  @override
  State<_CollapsibleText> createState() => _CollapsibleTextState();
}

class _CollapsibleTextState extends State<_CollapsibleText> {
  static const _collapsedLines = 14;
  static const _collapsedRunes = 420;

  var _expanded = false;

  bool _isLong(String text) {
    final lines = text.split('\n');
    if (lines.length > _collapsedLines) return true;
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    return compact.runes.length > _collapsedRunes;
  }

  String _collapseText(String text) {
    var result = text;
    var truncated = false;
    final lines = result.split('\n');
    if (lines.length > _collapsedLines) {
      result = lines.take(_collapsedLines).join('\n');
      truncated = true;
    }

    final compact = result.replaceAll(RegExp(r'\s+'), '');
    if (compact.runes.length > _collapsedRunes) {
      result = String.fromCharCodes(result.runes.take(_collapsedRunes));
      truncated = true;
    }

    if (truncated) {
      result = result.trimRight();
      result = result.endsWith('...') ? result : '$result...';
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    final shouldCollapse = widget.collapseEnabled && _isLong(text);
    final showCollapsed = shouldCollapse && !_expanded;
    final displayText = showCollapsed ? _collapseText(text) : text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MemoMarkdown(
          data: displayText,
          textStyle: widget.style,
          selectable: !showCollapsed,
          blockSpacing: 8,
          onToggleTask: showCollapsed ? null : widget.onToggleTask,
        ),
        if (shouldCollapse)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                if (widget.hapticsEnabled) {
                  HapticFeedback.selectionClick();
                }
                setState(() => _expanded = !_expanded);
              },
              child: Text(_expanded ? context.tr(zh: '收起', en: 'Collapse') : context.tr(zh: '展开', en: 'Expand')),
            ),
          ),
      ],
    );
  }
}

class _ReferencesSection extends StatefulWidget {
  const _ReferencesSection({
    required this.references,
    required this.lineCount,
    required this.style,
    required this.hapticsEnabled,
  });

  final String references;
  final int lineCount;
  final TextStyle? style;
  final bool hapticsEnabled;

  @override
  State<_ReferencesSection> createState() => _ReferencesSectionState();
}

class _ReferencesSectionState extends State<_ReferencesSection> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.references.trim().isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final border = scheme.outlineVariant.withValues(alpha: 0.6);
    final headerText = widget.lineCount > 0
        ? context.tr(zh: '引用 ${widget.lineCount} 行', en: 'Quoted ${widget.lineCount} lines')
        : context.tr(zh: '引用', en: 'Quotes');

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (widget.hapticsEnabled) {
                  HapticFeedback.selectionClick();
                }
                setState(() => _expanded = !_expanded);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(child: Text(headerText, style: Theme.of(context).textTheme.labelLarge)),
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: MemoMarkdown(
                data: widget.references.trim(),
                textStyle: widget.style,
                selectable: true,
                blockSpacing: 4,
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageViewerScreen extends StatelessWidget {
  const _ImageViewerScreen({
    required this.imageUrl,
    required this.authHeader,
    required this.title,
  });

  final String imageUrl;
  final String? authHeader;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: InteractiveViewer(
          child: Center(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              httpHeaders: authHeader == null ? null : {'Authorization': authHeader!},
              placeholder: (context, _) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.broken_image),
            ),
          ),
        ),
      ),
    );
  }
}
