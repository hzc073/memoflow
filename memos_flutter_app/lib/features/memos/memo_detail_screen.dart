import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/url.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import 'memo_editor_screen.dart';

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
            title: const Text('删除 Memo？'),
            content: const Text('本地会立即移除，联网后将同步删除服务器内容。'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('删除')),
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

  String _attachmentUrl(Uri baseUrl, Attachment a, {required bool thumbnail}) {
    if (a.externalLink.isNotEmpty) return a.externalLink;
    final url = joinBaseUrl(baseUrl, 'file/${a.name}/${a.filename}');
    return thumbnail ? '$url?thumbnail=true' : url;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('播放失败：$e')));
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
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已开始重试同步')));
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('重试同步'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        maybeHaptic();
                        await Clipboard.setData(ClipboardData(text: memo.lastError!));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制错误信息')));
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('复制'),
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
      appBar: AppBar(
        title: Text(isArchived ? '已归档' : 'Memo'),
        actions: [
          IconButton(
            tooltip: '编辑',
            onPressed: () {
              maybeHaptic();
              unawaited(_edit());
            },
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            tooltip: memo.pinned ? '取消置顶' : '置顶',
            onPressed: () {
              maybeHaptic();
              unawaited(_togglePinned());
            },
            icon: Icon(memo.pinned ? Icons.push_pin : Icons.push_pin_outlined),
          ),
          IconButton(
            tooltip: isArchived ? '取消归档' : '归档',
            onPressed: () {
              maybeHaptic();
              unawaited(_toggleArchived());
            },
            icon: Icon(isArchived ? Icons.unarchive : Icons.archive),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: () {
              maybeHaptic();
              unawaited(_delete());
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            header,
            if (memo.attachments.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('附件', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...memo.attachments.map(
                (a) {
                  final type = a.type;
                  final isImage = type.startsWith('image/');
                  final isAudio = type.startsWith('audio');

                  final url = (baseUrl == null) ? '' : _attachmentUrl(baseUrl, a, thumbnail: isImage);
                  final fullUrl = (baseUrl == null) ? '' : _attachmentUrl(baseUrl, a, thumbnail: false);

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
    );
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
  });

  final String text;
  final bool collapseEnabled;
  final TextStyle? style;
  final bool hapticsEnabled;

  @override
  State<_CollapsibleText> createState() => _CollapsibleTextState();
}

class _CollapsibleTextState extends State<_CollapsibleText> {
  static const _collapsedLines = 14;

  var _expanded = false;

  bool _isLong(String text) {
    final lines = text.split('\n');
    if (lines.length > _collapsedLines) return true;
    final compact = text.replaceAll(RegExp(r'\\s+'), '');
    return compact.runes.length > 420;
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    final shouldCollapse = widget.collapseEnabled && _isLong(text);
    final showCollapsed = shouldCollapse && !_expanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCollapsed)
          Text(
            text,
            style: widget.style,
            maxLines: _collapsedLines,
            overflow: TextOverflow.ellipsis,
          )
        else
          SelectableText(text, style: widget.style),
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
              child: Text(_expanded ? '收起' : '展开'),
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
    final headerText = widget.lineCount > 0 ? '引用 ${widget.lineCount} 行' : '引用';

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
              child: SelectableText(widget.references.trim(), style: widget.style),
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
