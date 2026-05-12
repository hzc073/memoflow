import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_motion.dart';
import '../../../core/image_error_logger.dart';
import '../../../core/memoflow_palette.dart';
import '../../../core/url.dart';
import '../../../core/windows_adaptive_surface.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/memo.dart';
import '../../../data/models/reaction.dart';
import '../../../data/models/user.dart';
import '../../../i18n/strings.g.dart';
import '../../../state/memos/memo_detail_providers.dart';
import '../../../state/memos/memo_engagement_provider.dart';
import '../../../state/system/session_provider.dart';
import '../../image_preview/image_preview_item.dart';
import '../../image_preview/image_preview_launcher.dart';
import '../../image_preview/image_preview_open_request.dart';
import '../../image_preview/widgets/image_preview_tile.dart';

@visibleForTesting
const Key memoEngagementCompactBarKey = ValueKey<String>(
  'memo-engagement-compact-bar',
);

@visibleForTesting
const Key memoEngagementSurfaceKey = ValueKey<String>(
  'memo-engagement-surface',
);

@visibleForTesting
const Key memoEngagementLikeButtonKey = ValueKey<String>(
  'memo-engagement-like-button',
);

@visibleForTesting
const Key memoEngagementCommentButtonKey = ValueKey<String>(
  'memo-engagement-comment-button',
);

@visibleForTesting
const Key memoEngagementCompactPreviewKey = ValueKey<String>(
  'memo-engagement-compact-preview',
);

@visibleForTesting
const Key memoEngagementCompactLikeAvatarsKey = ValueKey<String>(
  'memo-engagement-compact-like-avatars',
);

@visibleForTesting
const Key memoEngagementCompactCommentPreviewKey = ValueKey<String>(
  'memo-engagement-compact-comment-preview',
);

@visibleForTesting
const Key memoEngagementViewAllCommentsButtonKey = ValueKey<String>(
  'memo-engagement-view-all-comments-button',
);

enum MemoEngagementSurfaceMode { detail, compact }

const int _compactMaxLikerAvatars = 5;
const int _compactMaxCommentPreviewCount = 2;

Future<void> showMemoEngagementSurfaceSheet({
  required BuildContext context,
  required String memoUid,
  required String memoVisibility,
  bool initiallyComposeComment = false,
}) {
  Widget builder(BuildContext surfaceContext) {
    final content = SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: MemoEngagementSurface(
          memoUid: memoUid,
          memoVisibility: memoVisibility,
          initiallyComposeComment: initiallyComposeComment,
        ),
      ),
    );
    return content;
  }

  if (shouldUseWindowsAdaptiveSurface(context)) {
    return showWindowsAdaptiveSurface<void>(
      context: context,
      kind: WindowsAdaptiveSurfaceKind.dialog,
      maxWidth: 560,
      builder: builder,
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: builder,
  );
}

class MemoEngagementSurface extends ConsumerStatefulWidget {
  const MemoEngagementSurface({
    super.key,
    required this.memoUid,
    required this.memoVisibility,
    this.mode = MemoEngagementSurfaceMode.detail,
    this.initiallyComposeComment = false,
  });

  final String memoUid;
  final String memoVisibility;
  final MemoEngagementSurfaceMode mode;
  final bool initiallyComposeComment;

  @override
  ConsumerState<MemoEngagementSurface> createState() =>
      _MemoEngagementSurfaceState();
}

class _MemoEngagementSurfaceState extends ConsumerState<MemoEngagementSurface> {
  final _creatorCache = <String, User>{};
  final _creatorFetching = <String>{};
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();

  bool _commenting = false;
  bool _initialComposerOpened = false;
  String? _replyingCommentCreator;

  MemoEngagementRequest get _request {
    return MemoEngagementRequest(
      memoUid: widget.memoUid,
      memoVisibility: widget.memoVisibility,
    );
  }

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
    _scheduleInitialComposer();
  }

  @override
  void didUpdateWidget(covariant MemoEngagementSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memoUid == widget.memoUid &&
        oldWidget.memoVisibility == widget.memoVisibility) {
      return;
    }
    _creatorCache.clear();
    _creatorFetching.clear();
    _replyingCommentCreator = null;
    _commenting = false;
    _initialComposerOpened = false;
    _commentController.clear();
    _scheduleLoad();
    _scheduleInitialComposer();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _scheduleLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(memoEngagementControllerProvider(_request).notifier).load(),
      );
    });
  }

  void _scheduleInitialComposer() {
    if (!widget.initiallyComposeComment || _initialComposerOpened) return;
    _initialComposerOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _commenting = true);
      _commentFocusNode.requestFocus();
    });
  }

  void _schedulePrefetchCreators(MemoEngagementSnapshot snapshot) {
    final pending = <String>{};
    final creators = widget.mode == MemoEngagementSurfaceMode.compact
        ? _compactPreviewCreatorNames(snapshot)
        : <String>[
            ...snapshot.reactions.map((reaction) => reaction.creator),
            ...snapshot.comments.map((comment) => comment.creator),
          ];
    for (final creator in creators) {
      final normalized = creator.trim();
      if (normalized.isEmpty) continue;
      if (_creatorCache.containsKey(normalized) ||
          _creatorFetching.contains(normalized)) {
        continue;
      }
      pending.add(normalized);
    }
    if (pending.isEmpty) return;
    _creatorFetching.addAll(pending);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_prefetchCreators(pending));
    });
  }

  List<String> _compactPreviewCreatorNames(MemoEngagementSnapshot snapshot) {
    final names = <String>[];
    names.addAll(
      uniqueMemoCreatorReactions(
        snapshot.likeReactions,
      ).take(_compactMaxLikerAvatars).map((reaction) => reaction.creator),
    );
    names.addAll(
      snapshot.comments
          .take(_compactMaxCommentPreviewCount)
          .map((comment) => comment.creator),
    );
    return names;
  }

  Future<void> _prefetchCreators(Iterable<String> creators) async {
    final updates = <String, User>{};
    for (final creator in creators) {
      try {
        final user = await ref
            .read(memoDetailControllerProvider)
            .fetchUser(name: creator);
        if (user != null) {
          updates[creator] = user;
        }
      } finally {
        _creatorFetching.remove(creator);
      }
    }
    if (!mounted || updates.isEmpty) return;
    setState(() => _creatorCache.addAll(updates));
  }

  Future<void> _toggleLike() async {
    try {
      await ref
          .read(memoEngagementControllerProvider(_request).notifier)
          .toggleLike();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_failed_react(e: error)),
        ),
      );
    }
  }

  void _toggleCommentComposer() {
    if (widget.mode == MemoEngagementSurfaceMode.compact) {
      _openEngagementSurface(initiallyComposeComment: true);
      return;
    }

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

  void _openEngagementSurface({bool initiallyComposeComment = false}) {
    unawaited(
      showMemoEngagementSurfaceSheet(
        context: context,
        memoUid: widget.memoUid,
        memoVisibility: widget.memoVisibility,
        initiallyComposeComment: initiallyComposeComment,
      ),
    );
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

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    try {
      final created = await ref
          .read(memoEngagementControllerProvider(_request).notifier)
          .createComment(content);
      if (!mounted || created == null) return;
      setState(() {
        _commentController.clear();
        _replyingCommentCreator = null;
      });
      _schedulePrefetchCreators(
        MemoEngagementSnapshot(comments: <Memo>[created]),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_failed_comment(e: error)),
        ),
      );
    }
  }

  String _commentHint() {
    final replyCreator = _replyingCommentCreator?.trim() ?? '';
    if (replyCreator.isNotEmpty) {
      final creator = _creatorCache[replyCreator];
      final name = _creatorDisplayName(creator, replyCreator, context);
      if (name.isNotEmpty) {
        return context.t.strings.legacy.msg_reply_2(name: name);
      }
    }
    return context.t.strings.legacy.msg_write_comment;
  }

  String _creatorDisplayName(
    User? creator,
    String fallback,
    BuildContext context,
  ) {
    final display = creator?.displayName.trim() ?? '';
    if (display.isNotEmpty) return display;
    final username = creator?.username.trim() ?? '';
    if (username.isNotEmpty) return username;
    final trimmed = fallback.trim();
    if (trimmed.startsWith('users/')) {
      return '${context.t.strings.legacy.msg_user} ${trimmed.substring('users/'.length)}';
    }
    return trimmed.isEmpty ? context.t.strings.legacy.msg_unknown : trimmed;
  }

  String _creatorInitial(User? creator, String fallback, BuildContext context) {
    final display = _creatorDisplayName(creator, fallback, context);
    if (display.isEmpty) return '?';
    return display.characters.first.toUpperCase();
  }

  String _resolveAvatarUrl(String rawUrl, Uri? baseUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('data:')) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (baseUrl == null) return trimmed;
    return joinBaseUrl(baseUrl, trimmed);
  }

  String _remainingPeopleLabel(BuildContext context, int count) {
    final locale = Localizations.localeOf(context);
    return switch (locale.languageCode) {
      'zh' => '\u7b49 $count \u4eba',
      'ja' => '\u307b\u304b$count\u4eba',
      'de' => 'und $count weitere',
      _ => 'and $count more',
    };
  }

  String _remainingLikesLabel(BuildContext context, int count) {
    final locale = Localizations.localeOf(context);
    return switch (locale.languageCode) {
      'zh' => '\u7b49 $count \u4eba\u70b9\u8d5e',
      'ja' => '\u307b\u304b$count\u4eba\u304c\u3044\u3044\u306d',
      'ko' => '\uc678 $count\uba85\uc774 \uc88b\uc544\uc694',
      'de' => 'und $count weitere',
      'pt' => 'e mais $count curtiram',
      _ => 'and $count more liked',
    };
  }

  void _showLikersSheet({
    required List<Reaction> likers,
    required int total,
    required Color textMuted,
    required Uri? baseUrl,
  }) {
    if (likers.isEmpty) return;

    Widget buildLikersContent(BuildContext surfaceContext) {
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(surfaceContext).height * 0.65,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  '${surfaceContext.t.strings.legacy.msg_like_2} $total',
                  style: Theme.of(surfaceContext).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: likers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final reaction = likers[index];
                    final creator = reaction.creator;
                    final user = _creatorCache[creator];
                    final displayName = _creatorDisplayName(
                      user,
                      creator,
                      context,
                    );
                    return Row(
                      children: [
                        _buildAvatar(
                          creator: user,
                          fallback: creator,
                          textMuted: textMuted,
                          baseUrl: baseUrl,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            displayName,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (shouldUseWindowsAdaptiveSurface(context)) {
      unawaited(
        showWindowsAdaptiveSurface<void>(
          context: context,
          kind: WindowsAdaptiveSurfaceKind.dialog,
          maxWidth: 520,
          builder: buildLikersContent,
        ),
      );
      return;
    }

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: buildLikersContent,
      ),
    );
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

  String _resolveCommentAttachmentUrl(
    Uri? baseUrl,
    Attachment attachment, {
    required bool thumbnail,
  }) {
    final external = attachment.externalLink.trim();
    if (external.isNotEmpty) {
      final isRelative = !isAbsoluteUrl(external);
      final resolved = resolveMaybeRelativeUrl(baseUrl, external);
      return (thumbnail && isRelative)
          ? appendThumbnailParam(resolved)
          : resolved;
    }
    if (baseUrl == null) return '';
    final url = joinBaseUrl(
      baseUrl,
      'file/${attachment.name}/${attachment.filename}',
    );
    return thumbnail ? appendThumbnailParam(url) : url;
  }

  List<ImagePreviewItem> _buildCommentPreviewItems({
    required List<Attachment> attachments,
    required Uri? baseUrl,
    required String? authHeader,
  }) {
    return attachments
        .map((attachment) {
          final thumbUrl = _resolveCommentAttachmentUrl(
            baseUrl,
            attachment,
            thumbnail: true,
          );
          final fullUrl = _resolveCommentAttachmentUrl(
            baseUrl,
            attachment,
            thumbnail: false,
          );
          return ImagePreviewItem(
            id: attachment.name.isNotEmpty ? attachment.name : attachment.uid,
            title: attachment.filename,
            mimeType: attachment.type,
            localFile: null,
            thumbnailUrl: thumbUrl.isNotEmpty ? thumbUrl : null,
            fullUrl: fullUrl.isNotEmpty ? fullUrl : null,
            headers: authHeader == null ? null : {'Authorization': authHeader},
            width: attachment.width,
            height: attachment.height,
          );
        })
        .toList(growable: false);
  }

  Widget _buildCommentItem({
    required Memo comment,
    required Color textMain,
    required Uri? baseUrl,
    required String? authHeader,
  }) {
    final images = comment.attachments
        .where(_isImageAttachment)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 12, color: textMain),
            children: [
              TextSpan(
                text:
                    '${_creatorDisplayName(_creatorCache[comment.creator], comment.creator, context)}: ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: MemoFlowPalette.primary,
                ),
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
              for (var i = 0; i < images.length; i++)
                _buildCommentImage(
                  attachment: images[i],
                  attachments: images,
                  index: i,
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
    required List<Attachment> attachments,
    required int index,
    required Uri? baseUrl,
    required String? authHeader,
  }) {
    final thumbUrl = _resolveCommentAttachmentUrl(
      baseUrl,
      attachment,
      thumbnail: true,
    );
    final fullUrl = _resolveCommentAttachmentUrl(
      baseUrl,
      attachment,
      thumbnail: false,
    );
    final displayUrl = thumbUrl.isNotEmpty ? thumbUrl : fullUrl;
    if (displayUrl.isEmpty) return const SizedBox.shrink();
    final viewUrl = fullUrl.isNotEmpty ? fullUrl : displayUrl;
    final previewItems = _buildCommentPreviewItems(
      attachments: attachments,
      baseUrl: baseUrl,
      authHeader: authHeader,
    );

    return GestureDetector(
      onTap: viewUrl.isEmpty
          ? null
          : () {
              unawaited(
                ImagePreviewLauncher.open(
                  context,
                  ImagePreviewOpenRequest(
                    items: previewItems,
                    initialIndex: index,
                    enableDownload: true,
                  ),
                ),
              );
            },
      child: ImagePreviewTile(
        item: ImagePreviewItem(
          id: attachment.name.isNotEmpty ? attachment.name : attachment.uid,
          title: attachment.filename,
          mimeType: attachment.type,
          thumbnailUrl: displayUrl,
          fullUrl: viewUrl,
          headers: authHeader == null ? null : {'Authorization': authHeader},
          width: attachment.width,
          height: attachment.height,
        ),
        width: 110,
        height: 80,
        borderRadius: 10,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderColor: Colors.transparent,
        placeholderColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
        logScope: 'memo_engagement_comment_image',
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
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
      ),
      alignment: Alignment.center,
      child: Text(
        _creatorInitial(creator, fallback, context),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: textMuted,
        ),
      ),
    );

    final avatarUrl = _resolveAvatarUrl(creator?.avatarUrl ?? '', baseUrl);
    if (avatarUrl.isEmpty) return fallbackWidget;
    if (avatarUrl.startsWith('data:')) {
      final bytes = tryDecodeDataUri(avatarUrl);
      if (bytes == null) return fallbackWidget;
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) {
            logImageLoadError(
              scope: 'memo_engagement_avatar_data_uri',
              source: avatarUrl,
              error: error,
              stackTrace: stackTrace,
              extraContext: <String, Object?>{
                'userName': creator?.name,
                'avatarKind': 'data_uri',
              },
            );
            return fallbackWidget;
          },
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => fallbackWidget,
        errorWidget: (context, _, error) {
          logImageLoadError(
            scope: 'memo_engagement_avatar_network',
            source: avatarUrl,
            error: error,
            extraContext: <String, Object?>{
              'userName': creator?.name,
              'avatarKind': 'network',
            },
          );
          return fallbackWidget;
        },
      ),
    );
  }

  Widget _buildCommentComposer({
    required MemoEngagementState state,
    required Color textMain,
    required Color textMuted,
    required Color cardBg,
    required Color borderColor,
    required bool isDark,
  }) {
    final inputBg = isDark
        ? MemoFlowPalette.backgroundDark
        : const Color(0xFFF7F5F1);
    final inputMotionDuration = AppMotion.effectiveDuration(
      context,
      AppMotion.fast,
    );
    return TapRegion(
      onTapOutside: _replyingCommentCreator == null
          ? null
          : (_) => _exitCommentEditing(),
      child: AnimatedPadding(
        duration: inputMotionDuration,
        curve: AppMotion.standardCurve,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
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
                    hintStyle: TextStyle(
                      color: textMuted.withValues(alpha: 0.7),
                    ),
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: textMuted.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: textMuted.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: MemoFlowPalette.primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: state.commentSending ? null : _submitComment,
                style: TextButton.styleFrom(
                  foregroundColor: MemoFlowPalette.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  context.t.strings.legacy.msg_send,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactionsRow({
    required MemoEngagementState state,
    required Color textMuted,
    required Uri? baseUrl,
  }) {
    final snapshot = state.snapshot;
    if (state.reactionsLoading && snapshot.reactions.isEmpty) {
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

    if (state.reactionsError != null && snapshot.reactions.isEmpty) {
      return Text(
        context.t.strings.legacy.msg_failed_load_2,
        style: TextStyle(fontSize: 12, color: textMuted),
      );
    }

    final likeReactions = snapshot.likeReactions;
    final reactionSummaries = snapshot.otherReactionSummaries;
    if (likeReactions.isEmpty && reactionSummaries.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = snapshot.likeCount;
    final unique = uniqueMemoCreatorReactions(likeReactions);
    final shown = unique.take(8).toList(growable: false);
    final remaining = total - shown.length;
    const avatarSize = 28.0;
    const overlap = 18.0;
    final width = shown.isEmpty
        ? 0.0
        : avatarSize + ((shown.length - 1) * overlap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(Icons.favorite, size: 16, color: MemoFlowPalette.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showLikersSheet(
                        likers: unique,
                        total: total,
                        textMuted: textMuted,
                        baseUrl: baseUrl,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            if (shown.isNotEmpty)
                              SizedBox(
                                height: avatarSize,
                                width: width,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    for (var i = 0; i < shown.length; i++)
                                      Positioned(
                                        left: i * overlap,
                                        child: _buildAvatar(
                                          creator:
                                              _creatorCache[shown[i].creator],
                                          fallback: shown[i].creator,
                                          textMuted: textMuted,
                                          baseUrl: baseUrl,
                                          size: avatarSize,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            if (remaining > 0) ...[
                              if (shown.isNotEmpty) const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _remainingPeopleLabel(context, remaining),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted,
                                  ),
                                ),
                              ),
                            ] else if (shown.isEmpty)
                              Expanded(
                                child: Text(
                                  total.toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (reactionSummaries.isNotEmpty) ...[
          if (total > 0) const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final summary in reactionSummaries)
                _ReactionChip(
                  label: '${summary.reactionType} ${summary.count}',
                  textColor: textMuted,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCommentsList({
    required MemoEngagementState state,
    required Color textMain,
    required Color textMuted,
    required Uri? baseUrl,
    required String? authHeader,
  }) {
    final comments = state.snapshot.comments;
    if (state.commentsLoading && comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (state.commentsError != null && comments.isEmpty) {
      return Text(
        context.t.strings.legacy.msg_failed_load_2,
        style: TextStyle(fontSize: 12, color: textMuted),
      );
    }

    if (comments.isEmpty) {
      return Text(
        context.t.strings.legacy.msg_no_comments_yet,
        style: TextStyle(fontSize: 12, color: textMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < comments.length; i++) ...[
          GestureDetector(
            onTap: () => _replyToComment(comments[i]),
            child: _buildCommentItem(
              comment: comments[i],
              textMain: textMain,
              baseUrl: baseUrl,
              authHeader: authHeader,
            ),
          ),
          if (i != comments.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildCompact({
    required MemoEngagementState state,
    required Color textMain,
    required Color textMuted,
    required Uri? baseUrl,
    required String currentUser,
  }) {
    final snapshot = state.snapshot;
    final hasOwnLike = snapshot.hasUserLike(currentUser);
    final hasOwnComment = snapshot.hasUserComment(currentUser);
    final commentActive = hasOwnComment;
    final reactionSummaries = snapshot.otherReactionSummaries;
    final loading = state.loading && !state.loaded;
    final hasPreview = snapshot.likeCount > 0 || snapshot.comments.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        key: memoEngagementCompactBarKey,
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _EngagementAction(
                  key: memoEngagementLikeButtonKey,
                  icon: hasOwnLike ? Icons.favorite : Icons.favorite_border,
                  label: context.t.strings.legacy.msg_like_2,
                  count: snapshot.likeCount,
                  color: hasOwnLike ? MemoFlowPalette.primary : textMuted,
                  compact: true,
                  onTap: state.reactionUpdating ? null : _toggleLike,
                ),
                const SizedBox(width: 8),
                _EngagementAction(
                  key: memoEngagementCommentButtonKey,
                  icon: commentActive
                      ? Icons.chat_bubble
                      : Icons.chat_bubble_outline,
                  label: context.t.strings.legacy.msg_comment,
                  count: snapshot.visibleCommentCount,
                  color: commentActive ? MemoFlowPalette.primary : textMuted,
                  compact: true,
                  onTap: _toggleCommentComposer,
                ),
                if (loading) ...[
                  const SizedBox(width: 8),
                  SizedBox.square(
                    dimension: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textMuted,
                    ),
                  ),
                ],
                if (reactionSummaries.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final summary in reactionSummaries.take(3))
                          _ReactionChip(
                            label: '${summary.reactionType} ${summary.count}',
                            textColor: textMuted,
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                ] else
                  const Spacer(),
              ],
            ),
            if (hasPreview) ...[
              const SizedBox(height: 8),
              _buildCompactPreview(
                state: state,
                textMain: textMain,
                textMuted: textMuted,
                baseUrl: baseUrl,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPreview({
    required MemoEngagementState state,
    required Color textMain,
    required Color textMuted,
    required Uri? baseUrl,
  }) {
    final snapshot = state.snapshot;
    final likeReactions = uniqueMemoCreatorReactions(
      snapshot.likeReactions,
    ).take(_compactMaxLikerAvatars).toList(growable: false);
    final commentPreviews = snapshot.comments
        .take(_compactMaxCommentPreviewCount)
        .toList(growable: false);
    final remainingLikes = snapshot.likeCount - likeReactions.length;
    final remainingComments =
        snapshot.visibleCommentCount - commentPreviews.length;

    if (likeReactions.isEmpty && commentPreviews.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      key: memoEngagementCompactPreviewKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (likeReactions.isNotEmpty)
          _buildCompactLikesPreview(
            likeReactions: likeReactions,
            totalLikes: snapshot.likeCount,
            remainingLikes: remainingLikes,
            textMuted: textMuted,
            baseUrl: baseUrl,
          ),
        if (likeReactions.isNotEmpty && commentPreviews.isNotEmpty)
          const SizedBox(height: 8),
        if (commentPreviews.isNotEmpty)
          Column(
            key: memoEngagementCompactCommentPreviewKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < commentPreviews.length; i++) ...[
                _buildCompactCommentPreviewLine(
                  comment: commentPreviews[i],
                  textMain: textMain,
                  textMuted: textMuted,
                  baseUrl: baseUrl,
                ),
                if (i != commentPreviews.length - 1) const SizedBox(height: 6),
              ],
              if (remainingComments > 0) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: memoEngagementViewAllCommentsButtonKey,
                    onPressed: () => _openEngagementSurface(),
                    style: TextButton.styleFrom(
                      foregroundColor: textMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                    ),
                    child: Text(
                      context.t.strings.legacy.msg_view_all_comments,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildCompactLikesPreview({
    required List<Reaction> likeReactions,
    required int totalLikes,
    required int remainingLikes,
    required Color textMuted,
    required Uri? baseUrl,
  }) {
    const avatarSize = 20.0;
    const overlap = 13.0;
    final width = likeReactions.isEmpty
        ? 0.0
        : avatarSize + ((likeReactions.length - 1) * overlap);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: likeReactions.isEmpty
            ? null
            : () => _showLikersSheet(
                likers: likeReactions,
                total: totalLikes,
                textMuted: textMuted,
                baseUrl: baseUrl,
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              Icon(Icons.favorite, size: 16, color: MemoFlowPalette.primary),
              const SizedBox(width: 8),
              if (likeReactions.isNotEmpty)
                SizedBox(
                  key: memoEngagementCompactLikeAvatarsKey,
                  height: avatarSize,
                  width: width,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var i = 0; i < likeReactions.length; i++)
                        Positioned(
                          left: i * overlap,
                          child: _buildAvatar(
                            creator: _creatorCache[likeReactions[i].creator],
                            fallback: likeReactions[i].creator,
                            textMuted: textMuted,
                            baseUrl: baseUrl,
                            size: avatarSize,
                          ),
                        ),
                    ],
                  ),
                ),
              if (remainingLikes > 0) ...[
                if (likeReactions.isNotEmpty) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _remainingLikesLabel(context, remainingLikes),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCommentPreviewLine({
    required Memo comment,
    required Color textMain,
    required Color textMuted,
    required Uri? baseUrl,
  }) {
    final previewCreator = _creatorCache[comment.creator];
    final previewName = _creatorDisplayName(
      previewCreator,
      comment.creator,
      context,
    );
    final previewText = _commentSnippet(comment.content);
    final snippet = previewText.isEmpty
        ? context.t.strings.legacy.msg_comment_unavailable
        : previewText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openEngagementSurface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(
                creator: previewCreator,
                fallback: comment.creator,
                textMuted: textMuted,
                baseUrl: baseUrl,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$previewName ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                      TextSpan(
                        text: snippet,
                        style: TextStyle(fontSize: 12, color: textMain),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetail({
    required MemoEngagementState state,
    required Color textMain,
    required Color textMuted,
    required Color cardBg,
    required Color borderColor,
    required bool isDark,
    required Uri? baseUrl,
    required String? authHeader,
    required String currentUser,
  }) {
    final snapshot = state.snapshot;
    final hasOwnLike = snapshot.hasUserLike(currentUser);
    final hasOwnComment = snapshot.hasUserComment(currentUser);
    final commentActive = _commenting || hasOwnComment;
    final showReactionSummary =
        (state.reactionsLoading && snapshot.reactions.isEmpty) ||
        (state.reactionsError != null && snapshot.reactions.isEmpty) ||
        snapshot.likeCount > 0 ||
        snapshot.otherReactionSummaries.isNotEmpty;

    return Padding(
      key: memoEngagementSurfaceKey,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _EngagementAction(
                key: memoEngagementLikeButtonKey,
                icon: hasOwnLike ? Icons.favorite : Icons.favorite_border,
                label: context.t.strings.legacy.msg_like_2,
                count: snapshot.likeCount,
                color: hasOwnLike ? MemoFlowPalette.primary : textMuted,
                onTap: state.reactionUpdating ? null : _toggleLike,
              ),
              const SizedBox(width: 18),
              _EngagementAction(
                key: memoEngagementCommentButtonKey,
                icon: commentActive
                    ? Icons.chat_bubble
                    : Icons.chat_bubble_outline,
                label: context.t.strings.legacy.msg_comment,
                count: snapshot.visibleCommentCount,
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
                if (showReactionSummary) ...[
                  _buildReactionsRow(
                    state: state,
                    textMuted: textMuted,
                    baseUrl: baseUrl,
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: borderColor.withValues(alpha: 0.6)),
                  const SizedBox(height: 10),
                ],
                _buildCommentsList(
                  state: state,
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
              state: state,
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

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final state = ref.watch(memoEngagementControllerProvider(request));
    final snapshot = state.snapshot;
    _schedulePrefetchCreators(snapshot);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.7);
    final cardBg = isDark
        ? MemoFlowPalette.audioSurfaceDark
        : MemoFlowPalette.audioSurfaceLight;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final baseUrl = account?.baseUrl;
    final token = account?.personalAccessToken ?? '';
    final authHeader = token.trim().isEmpty ? null : 'Bearer $token';
    final currentUser = account?.user.name.trim() ?? '';

    if (widget.mode == MemoEngagementSurfaceMode.compact) {
      return _buildCompact(
        state: state,
        textMain: textMain,
        textMuted: textMuted,
        baseUrl: baseUrl,
        currentUser: currentUser,
      );
    }

    return _buildDetail(
      state: state,
      textMain: textMain,
      textMuted: textMuted,
      cardBg: cardBg,
      borderColor: borderColor,
      isDark: isDark,
      baseUrl: baseUrl,
      authHeader: authHeader,
      currentUser: currentUser,
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.label,
    required this.textColor,
    this.dense = false,
  });

  final String label;
  final Color textColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: dense ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _EngagementAction extends StatelessWidget {
  const _EngagementAction({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    this.compact = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 16 : 18, color: color),
        const SizedBox(width: 5),
        Text(
          '$label $count',
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 2 : 4,
          vertical: compact ? 4 : 2,
        ),
        child: content,
      ),
    );
  }
}
