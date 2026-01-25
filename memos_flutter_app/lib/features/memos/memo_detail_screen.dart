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
import '../../data/models/content_fingerprint.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo.dart';
import '../../data/models/reaction.dart';
import '../../data/models/user.dart';
import '../../state/database_provider.dart';
import '../../state/memos_providers.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import 'memo_editor_screen.dart';
import 'memo_markdown.dart';

class MemoDetailScreen extends ConsumerStatefulWidget {
  const MemoDetailScreen({
    super.key,
    required this.initialMemo,
    this.readOnly = false,
  });

  final LocalMemo initialMemo;
  final bool readOnly;

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
    if (widget.readOnly) return;
    final memo = _memo;
    if (memo == null) return;
    await _updateLocalAndEnqueue(
      memo: memo,
      pinned: !memo.pinned,
    );
    await _reload();
  }

  Future<void> _toggleArchived() async {
    if (widget.readOnly) return;
    final memo = _memo;
    if (memo == null) return;
    final next = memo.state == 'ARCHIVED' ? 'NORMAL' : 'ARCHIVED';
    await _updateLocalAndEnqueue(
      memo: memo,
      state: next,
    );
    if (!mounted) return;
    context.safePop();
  }

  Future<void> _edit() async {
    if (widget.readOnly) return;
    final memo = _memo;
    if (memo == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MemoEditorScreen(existing: memo)),
    );
    await _reload();
  }

  Future<void> _delete() async {
    if (widget.readOnly) return;
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
              TextButton(onPressed: () => context.safePop(false), child: Text(context.tr(zh: '取消', en: 'Cancel'))),
              FilledButton(onPressed: () => context.safePop(true), child: Text(context.tr(zh: '删除', en: 'Delete'))),
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
    context.safePop();
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

    final updateTime = memo.updateTime;
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
        updateTimeSec: updateTime.toUtc().millisecondsSinceEpoch ~/ 1000,
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

      if (!mounted) return;
      setState(() {
        _memo = LocalMemo(
          uid: memo.uid,
          content: updated,
          contentFingerprint: computeContentFingerprint(updated),
          visibility: memo.visibility,
          pinned: memo.pinned,
          state: memo.state,
          createTime: memo.createTime,
          updateTime: updateTime,
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

  Widget _buildImageAttachmentGrid({
    required BuildContext context,
    required List<Attachment> attachments,
    required Uri? baseUrl,
    required String? authHeader,
  }) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    const gridSpacing = 8.0;
    const gridRadius = 12.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final previewBg =
        isDark ? MemoFlowPalette.audioSurfaceDark.withValues(alpha: 0.6) : MemoFlowPalette.audioSurfaceLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;

    Widget placeholder(IconData icon) {
      return Container(
        color: previewBg,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: textMain.withValues(alpha: 0.5)),
      );
    }

    Widget buildTile(Attachment attachment) {
      final localFile = _localAttachmentFile(attachment);
      final thumbUrl = (baseUrl == null) ? '' : _attachmentUrl(baseUrl, attachment, thumbnail: true);
      final fullUrl = (baseUrl == null) ? '' : _attachmentUrl(baseUrl, attachment, thumbnail: false);

      Widget image;
      if (localFile != null) {
        image = Image.file(
          localFile,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => placeholder(Icons.broken_image_outlined),
        );
      } else if (thumbUrl.isNotEmpty) {
        image = CachedNetworkImage(
          imageUrl: thumbUrl,
          httpHeaders: authHeader == null ? null : {'Authorization': authHeader},
          fit: BoxFit.cover,
          placeholder: (context, _) => placeholder(Icons.image_outlined),
          errorWidget: (context, url, error) => placeholder(Icons.broken_image_outlined),
        );
      } else {
        image = placeholder(Icons.image_outlined);
      }

      final tile = Container(
        decoration: BoxDecoration(
          color: previewBg,
          borderRadius: BorderRadius.circular(gridRadius),
          border: Border.all(color: borderColor.withValues(alpha: 0.65)),
        ),
        clipBehavior: Clip.antiAlias,
        child: image,
      );

      if (fullUrl.isEmpty || baseUrl == null) return tile;
      return GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _ImageViewerScreen(
                imageUrl: fullUrl,
                authHeader: authHeader,
                title: attachment.filename,
              ),
            ),
          );
        },
        child: tile,
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: gridSpacing,
        mainAxisSpacing: gridSpacing,
        childAspectRatio: 1,
      ),
      itemCount: attachments.length,
      itemBuilder: (context, index) => buildTile(attachments[index]),
    );
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
    final contentStyle = Theme.of(context).textTheme.bodyLarge;
    final canToggleTasks = !widget.readOnly;

    final contentWidget = _CollapsibleText(
      text: memo.content,
      collapseEnabled: prefs.collapseLongContent,
      initiallyExpanded: true,
      style: contentStyle,
      hapticsEnabled: hapticsEnabled,
      onToggleTask: canToggleTasks
          ? (request) {
              maybeHaptic();
              unawaited(_toggleTask(request, skipReferenceLines: prefs.collapseReferences));
            }
          : null,
    );

    final displayTime = memo.createTime.millisecondsSinceEpoch > 0 ? memo.createTime : memo.updateTime;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _dateFmt.format(displayTime),
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
        actions: widget.readOnly
            ? null
            : [
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
                final safeChild = SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: child,
                );
                return Material(color: Colors.transparent, child: RepaintBoundary(child: safeChild));
              },
              child: RepaintBoundary(child: Container(color: cardColor)),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                header,
                _MemoEngagementSection(memoUid: memo.uid, memoVisibility: memo.visibility),
                _MemoRelationsSection(memoUid: memo.uid),
                if (memo.attachments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(context.tr(zh: '附件', en: 'Attachments'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final images = memo.attachments
                          .where((a) => a.type.startsWith('image/'))
                          .toList(growable: false);
                      final others = memo.attachments
                          .where((a) => !a.type.startsWith('image/'))
                          .toList(growable: false);
                  
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (images.isNotEmpty)
                            _buildImageAttachmentGrid(
                              context: context,
                              attachments: images,
                              baseUrl: baseUrl,
                              authHeader: authHeader,
                            ),
                          if (images.isNotEmpty && others.isNotEmpty) const SizedBox(height: 8),
                          ...others.map(
                            (a) {
                              final isAudio = a.type.startsWith('audio');
                              final fullUrl = (baseUrl == null) ? '' : _attachmentUrl(baseUrl, a, thumbnail: false);
                  
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

class _MemoEngagementSection extends ConsumerStatefulWidget {
  const _MemoEngagementSection({
    required this.memoUid,
    required this.memoVisibility,
  });

  final String memoUid;
  final String memoVisibility;

  @override
  ConsumerState<_MemoEngagementSection> createState() => _MemoEngagementSectionState();
}

class _MemoEngagementSectionState extends ConsumerState<_MemoEngagementSection> {
  final _creatorCache = <String, User>{};
  final _creatorFetching = <String>{};
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();

  List<Reaction> _reactions = [];
  List<Memo> _comments = [];
  int _reactionTotal = 0;
  int _commentTotal = 0;
  bool _reactionsLoading = false;
  bool _commentsLoading = false;
  bool _commenting = false;
  bool _commentSending = false;
  String? _reactionsError;
  String? _commentsError;
  String? _replyingCommentCreator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEngagement();
    });
  }

  @override
  void didUpdateWidget(covariant _MemoEngagementSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memoUid == widget.memoUid) return;
    _reactions = [];
    _comments = [];
    _reactionTotal = 0;
    _commentTotal = 0;
    _commenting = false;
    _commentSending = false;
    _replyingCommentCreator = null;
    _commentController.clear();
    _reactionsError = null;
    _commentsError = null;
    _creatorCache.clear();
    _creatorFetching.clear();
    _loadEngagement();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _loadEngagement() {
    final uid = widget.memoUid.trim();
    if (uid.isEmpty) return;
    unawaited(_loadReactions(uid));
    unawaited(_loadComments(uid));
  }

  Future<void> _loadReactions(String uid) async {
    if (_reactionsLoading) return;
    setState(() {
      _reactionsLoading = true;
      _reactionsError = null;
    });
    try {
      final api = ref.read(memosApiProvider);
      final result = await api.listMemoReactions(memoUid: uid, pageSize: 50);
      if (!mounted) return;
      setState(() {
        _reactions = result.reactions;
        _reactionTotal = result.totalSize;
      });
      unawaited(_prefetchCreators(result.reactions.map((r) => r.creator)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _reactionsError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _reactionsLoading = false);
      }
    }
  }

  Future<void> _loadComments(String uid) async {
    if (_commentsLoading) return;
    setState(() {
      _commentsLoading = true;
      _commentsError = null;
    });
    try {
      final api = ref.read(memosApiProvider);
      final result = await api.listMemoComments(memoUid: uid, pageSize: 50);
      if (!mounted) return;
      setState(() {
        _comments = result.memos;
        _commentTotal = result.totalSize;
      });
      unawaited(_prefetchCreators(result.memos.map((m) => m.creator)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _commentsError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _commentsLoading = false);
      }
    }
  }

  void _toggleCommentComposer() {
    setState(() {
      _commenting = !_commenting;
      if (!_commenting) {
        _replyingCommentCreator = null;
        _commentController.clear();
      }
    });
    if (_commenting) {
      _commentFocusNode.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  void _replyToComment(Memo comment) {
    setState(() {
      _commenting = true;
      _replyingCommentCreator = comment.creator;
    });
    _commentController.clear();
    _commentFocusNode.requestFocus();
  }

  void _exitCommentEditing() {
    if (_replyingCommentCreator == null) return;
    setState(() {
      _commenting = false;
      _replyingCommentCreator = null;
      _commentController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  String _commentHint() {
    final replyCreator = _replyingCommentCreator?.trim() ?? '';
    if (replyCreator.isNotEmpty) {
      final creator = _creatorCache[replyCreator];
      final name = _creatorDisplayName(creator, replyCreator, context);
      if (name.isNotEmpty) {
        return context.tr(zh: '回复 $name...', en: 'Reply $name...');
      }
    }
    return context.tr(zh: '写下评论...', en: 'Write a comment...');
  }

  Future<void> _submitComment() async {
    final uid = widget.memoUid.trim();
    if (uid.isEmpty) return;
    final content = _commentController.text.trim();
    if (content.isEmpty || _commentSending) return;

    setState(() => _commentSending = true);
    try {
      final visibility = widget.memoVisibility.trim().isNotEmpty ? widget.memoVisibility.trim() : 'PUBLIC';
      final api = ref.read(memosApiProvider);
      final created = await api.createMemoComment(
        memoUid: uid,
        content: content,
        visibility: visibility,
      );
      if (!mounted) return;
      setState(() {
        _comments = [created, ..._comments];
        _commentTotal = _commentTotal > 0 ? _commentTotal + 1 : _comments.length;
        _commentController.clear();
        _replyingCommentCreator = null;
      });
      unawaited(_prefetchCreators([created.creator]));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(zh: '评论失败：$e', en: 'Failed to comment: $e'))),
      );
    } finally {
      if (mounted) {
        setState(() => _commentSending = false);
      }
    }
  }

  Widget _buildCommentComposer({
    required Color textMain,
    required Color textMuted,
    required Color cardBg,
    required Color borderColor,
    required bool isDark,
  }) {
    final inputBg = isDark ? MemoFlowPalette.backgroundDark : const Color(0xFFF7F5F1);
    return TapRegion(
      onTapOutside: _replyingCommentCreator == null ? null : (_) => _exitCommentEditing(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitComment(),
                  style: TextStyle(color: textMain),
                  decoration: InputDecoration(
                    hintText: _commentHint(),
                    hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.7)),
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: textMuted.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: textMuted.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: MemoFlowPalette.primary.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _commentSending ? null : _submitComment,
                style: TextButton.styleFrom(
                  foregroundColor: MemoFlowPalette.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: Text(
                  context.tr(zh: '发送', en: 'Send'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _prefetchCreators(Iterable<String> creators) async {
    final api = ref.read(memosApiProvider);
    final updates = <String, User>{};
    for (final creator in creators) {
      final normalized = creator.trim();
      if (normalized.isEmpty) continue;
      if (_creatorCache.containsKey(normalized) || _creatorFetching.contains(normalized)) continue;
      _creatorFetching.add(normalized);
      try {
        updates[normalized] = await api.getUser(name: normalized);
      } catch (_) {
      } finally {
        _creatorFetching.remove(normalized);
      }
    }
    if (!mounted) return;
    if (updates.isNotEmpty) {
      setState(() => _creatorCache.addAll(updates));
    }
  }

  String _creatorDisplayName(User? creator, String fallback, BuildContext context) {
    final display = creator?.displayName.trim() ?? '';
    if (display.isNotEmpty) return display;
    final username = creator?.username.trim() ?? '';
    if (username.isNotEmpty) return username;
    final trimmed = fallback.trim();
    if (trimmed.startsWith('users/')) {
      return '${context.tr(zh: '用户', en: 'User')} ${trimmed.substring('users/'.length)}';
    }
    return trimmed.isEmpty ? context.tr(zh: '未知用户', en: 'Unknown') : trimmed;
  }

  String _creatorInitial(User? creator, String fallback, BuildContext context) {
    final display = _creatorDisplayName(creator, fallback, context);
    if (display.isEmpty) return '?';
    return display.characters.first.toUpperCase();
  }

  String _resolveAvatarUrl(String rawUrl, Uri? baseUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    if (baseUrl == null) return trimmed;
    return joinBaseUrl(baseUrl, trimmed);
  }

  static List<Reaction> _uniqueReactions(List<Reaction> reactions) {
    final seen = <String>{};
    final unique = <Reaction>[];
    for (final reaction in reactions) {
      final creator = reaction.creator.trim();
      if (creator.isEmpty) continue;
      if (seen.add(creator)) {
        unique.add(reaction);
      }
    }
    return unique;
  }

  static String _commentSnippet(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isImageAttachment(Attachment attachment) {
    final type = attachment.type.trim().toLowerCase();
    return type.startsWith('image');
  }

  String _resolveCommentAttachmentUrl(Uri? baseUrl, Attachment attachment, {required bool thumbnail}) {
    final external = attachment.externalLink.trim();
    if (external.isNotEmpty) return external;
    if (baseUrl == null) return '';
    final url = joinBaseUrl(baseUrl, 'file/${attachment.name}/${attachment.filename}');
    return thumbnail ? '$url?thumbnail=true' : url;
  }

  Widget _buildCommentItem({
    required Memo comment,
    required Color textMain,
    required Uri? baseUrl,
    required String? authHeader,
  }) {
    final images = comment.attachments.where(_isImageAttachment).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 12, color: textMain),
            children: [
              TextSpan(
                text: '${_creatorDisplayName(_creatorCache[comment.creator], comment.creator, context)}: ',
                style: TextStyle(fontWeight: FontWeight.w700, color: MemoFlowPalette.primary),
              ),
              TextSpan(
                text: _commentSnippet(comment.content),
                style: TextStyle(color: textMain),
              ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final attachment in images)
                _buildCommentImage(
                  attachment: attachment,
                  baseUrl: baseUrl,
                  authHeader: authHeader,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCommentImage({
    required Attachment attachment,
    required Uri? baseUrl,
    required String? authHeader,
  }) {
    final thumbUrl = _resolveCommentAttachmentUrl(baseUrl, attachment, thumbnail: true);
    final fullUrl = _resolveCommentAttachmentUrl(baseUrl, attachment, thumbnail: false);
    final displayUrl = thumbUrl.isNotEmpty ? thumbUrl : fullUrl;
    if (displayUrl.isEmpty) return const SizedBox.shrink();
    final viewUrl = fullUrl.isNotEmpty ? fullUrl : displayUrl;

    return GestureDetector(
      onTap: viewUrl.isEmpty
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _ImageViewerScreen(
                    imageUrl: viewUrl,
                    authHeader: authHeader,
                    title: attachment.filename,
                  ),
                ),
              );
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: displayUrl,
          httpHeaders: authHeader == null ? null : {'Authorization': authHeader},
          width: 110,
          height: 80,
          fit: BoxFit.cover,
          placeholder: (context, _) => const SizedBox(
            width: 110,
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => const SizedBox(
            width: 110,
            height: 80,
            child: Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar({
    required User? creator,
    required String fallback,
    required Color textMuted,
    required Uri? baseUrl,
    double size = 28,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallbackWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
      ),
      alignment: Alignment.center,
      child: Text(
        _creatorInitial(creator, fallback, context),
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: textMuted),
      ),
    );

    final avatarUrl = _resolveAvatarUrl(creator?.avatarUrl ?? '', baseUrl);
    if (avatarUrl.isEmpty || avatarUrl.startsWith('data:')) return fallbackWidget;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => fallbackWidget,
        errorWidget: (context, url, error) => fallbackWidget,
      ),
    );
  }

  Widget _buildReactionsRow({
    required Color textMuted,
    required Uri? baseUrl,
  }) {
    if (_reactionsLoading && _reactions.isEmpty) {
      return Row(
        children: [
          Icon(Icons.favorite, size: 16, color: MemoFlowPalette.primary),
          const SizedBox(width: 8),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      );
    }

    if (_reactionsError != null && _reactions.isEmpty) {
      return Text(
        context.tr(zh: '加载失败', en: 'Failed to load'),
        style: TextStyle(fontSize: 12, color: textMuted),
      );
    }

    if (_reactions.isEmpty) {
      return Row(
        children: [
          Icon(Icons.favorite_border, size: 16, color: textMuted),
          const SizedBox(width: 8),
          Text(context.tr(zh: '暂无点赞', en: 'No likes yet'), style: TextStyle(fontSize: 12, color: textMuted)),
        ],
      );
    }

    final total = _reactionTotal > 0 ? _reactionTotal : _reactions.length;
    final unique = _uniqueReactions(_reactions);
    final shown = unique.take(3).toList(growable: false);
    final remaining = total - shown.length;
    const avatarSize = 28.0;
    const overlap = 18.0;
    final width = avatarSize + ((shown.length - 1) * overlap) + (remaining > 0 ? overlap : 0);

    return Row(
      children: [
        Icon(Icons.favorite, size: 16, color: MemoFlowPalette.primary),
        const SizedBox(width: 8),
        SizedBox(
          height: avatarSize,
          width: width < avatarSize ? avatarSize : width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(
                  left: i * overlap,
                  child: _buildAvatar(
                    creator: _creatorCache[shown[i].creator],
                    fallback: shown[i].creator,
                    textMuted: textMuted,
                    baseUrl: baseUrl,
                    size: avatarSize,
                  ),
                ),
              if (remaining > 0)
                Positioned(
                  left: shown.length * overlap,
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+$remaining',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsList({
    required Color textMain,
    required Color textMuted,
    required Uri? baseUrl,
    required String? authHeader,
  }) {
    if (_commentsLoading && _comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_commentsError != null && _comments.isEmpty) {
      return Text(
        context.tr(zh: '加载失败', en: 'Failed to load'),
        style: TextStyle(fontSize: 12, color: textMuted),
      );
    }

    if (_comments.isEmpty) {
      return Text(
        context.tr(zh: '暂无评论', en: 'No comments yet'),
        style: TextStyle(fontSize: 12, color: textMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _comments.length; i++) ...[
          GestureDetector(
            onTap: () => _replyToComment(_comments[i]),
            child: _buildCommentItem(
              comment: _comments[i],
              textMain: textMain,
              baseUrl: baseUrl,
              authHeader: authHeader,
            ),
          ),
          if (i != _comments.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.7);
    final cardBg = isDark ? MemoFlowPalette.audioSurfaceDark : MemoFlowPalette.audioSurfaceLight;
    final borderColor = isDark ? MemoFlowPalette.borderDark : MemoFlowPalette.borderLight;
    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final authHeader =
        (account?.personalAccessToken ?? '').isEmpty ? null : 'Bearer ${account!.personalAccessToken}';
    final reactionCount = _reactionTotal > 0 ? _reactionTotal : _reactions.length;
    final commentCount = _commentTotal > 0 ? _commentTotal : _comments.length;
    final currentUser = account?.user.name.trim() ?? '';
    final hasOwnComment =
        currentUser.isNotEmpty && _comments.any((comment) => comment.creator.trim() == currentUser);
    final commentActive = _commenting || hasOwnComment;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _EngagementAction(
                icon: Icons.favorite,
                label: context.tr(zh: '点赞', en: 'Like'),
                count: reactionCount,
                color: MemoFlowPalette.primary,
              ),
              const SizedBox(width: 18),
              _EngagementAction(
                icon: commentActive ? Icons.chat_bubble : Icons.chat_bubble_outline,
                label: context.tr(zh: '评论', en: 'Comment'),
                count: commentCount,
                color: commentActive ? MemoFlowPalette.primary : textMuted,
                onTap: _toggleCommentComposer,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReactionsRow(textMuted: textMuted, baseUrl: baseUrl),
                const SizedBox(height: 12),
                Divider(height: 1, color: borderColor.withValues(alpha: 0.6)),
                const SizedBox(height: 10),
                _buildCommentsList(
                  textMain: textMain,
                  textMuted: textMuted,
                  baseUrl: baseUrl,
                  authHeader: authHeader,
                ),
              ],
            ),
          ),
          if (_commenting)
            _buildCommentComposer(
              textMain: textMain,
              textMuted: textMuted,
              cardBg: cardBg,
              borderColor: borderColor,
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}

class _EngagementAction extends StatelessWidget {
  const _EngagementAction({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          '$label $count',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: content,
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
          final type = relation.type.trim().toUpperCase();
          if (type != 'REFERENCE') {
            continue;
          }
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

class _CollapsibleText extends StatefulWidget {
  const _CollapsibleText({
    required this.text,
    required this.collapseEnabled,
    required this.style,
    required this.hapticsEnabled,
    this.initiallyExpanded = false,
    this.onToggleTask,
  });

  final String text;
  final bool collapseEnabled;
  final TextStyle? style;
  final bool hapticsEnabled;
  final bool initiallyExpanded;
  final ValueChanged<TaskToggleRequest>? onToggleTask;

  @override
  State<_CollapsibleText> createState() => _CollapsibleTextState();
}

class _CollapsibleTextState extends State<_CollapsibleText> {
  static const _collapsedLines = 14;
  static const _collapsedRunes = 420;

  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

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
