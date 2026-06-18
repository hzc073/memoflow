import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/attachment_toast.dart';
import '../../../core/location_launcher.dart';
import '../../../core/memoflow_palette.dart';
import '../../../core/platform_layout.dart';
import '../../../core/url.dart';
import '../../../data/models/attachment.dart';
import '../../../data/models/local_memo.dart';
import '../../../i18n/strings.g.dart';
import '../../../state/settings/location_settings_provider.dart';
import '../../../state/settings/workspace_preferences_provider.dart';
import '../../../state/system/session_provider.dart';
import '../../../state/tags/tag_color_lookup.dart';
import '../../image_preview/image_preview_launcher.dart';
import '../../share/share_inline_image_content.dart';
import '../attachment_gallery_screen.dart';
import '../memo_image_grid.dart';
import '../memo_image_preview_adapters.dart';
import '../memo_inline_image_sources.dart';
import '../memo_location_line.dart';
import '../memo_markdown.dart';
import '../memo_media_grid.dart';
import '../memo_video_grid.dart';

final DateFormat _memoReaderDateFormatter = DateFormat('yyyy-MM-dd HH:mm');

DateTime resolveMemoReaderDisplayTime(LocalMemo memo) {
  return memo.effectiveDisplayTime.millisecondsSinceEpoch > 0
      ? memo.effectiveDisplayTime
      : memo.updateTime;
}

String formatMemoReaderDisplayTime(LocalMemo memo) {
  return _memoReaderDateFormatter.format(resolveMemoReaderDisplayTime(memo));
}

const memoReaderTimeAdjustTriggerKey = ValueKey<String>(
  'memo-reader-time-adjust-trigger',
);

class _MemoReaderTimeLabel extends StatelessWidget {
  const _MemoReaderTimeLabel({
    required this.text,
    required this.style,
    required this.onTap,
  });

  final String text;
  final TextStyle? style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return Text(text, style: style);
    }
    final color = style?.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      child: InkWell(
        key: memoReaderTimeAdjustTriggerKey,
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: style),
              const SizedBox(width: 4),
              Icon(Icons.edit_calendar_outlined, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class MemoReaderContent extends ConsumerWidget {
  const MemoReaderContent({
    super.key,
    required this.memo,
    this.highlightQuery,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.showDivider = false,
    this.contentTextStyle,
    this.metaTextStyle,
    this.showMetadata = true,
    this.selectable = true,
    this.previewImageOnTap = true,
    this.mediaMaxHeightFactor = 0.42,
    this.contentOverride,
    this.mediaEntriesOverride,
    this.nonMediaAttachmentsOverride,
    this.showAttachmentsSection = true,
    this.mediaMaxCount = 18,
    this.onTimeTap,
    this.onReplaceAttachment,
  });

  final LocalMemo memo;
  final String? highlightQuery;
  final EdgeInsetsGeometry padding;
  final bool showDivider;
  final TextStyle? contentTextStyle;
  final TextStyle? metaTextStyle;
  final bool showMetadata;
  final bool selectable;
  final bool previewImageOnTap;
  final double mediaMaxHeightFactor;
  final Widget? contentOverride;
  final List<MemoMediaEntry>? mediaEntriesOverride;
  final List<Attachment>? nonMediaAttachmentsOverride;
  final bool showAttachmentsSection;
  final int mediaMaxCount;
  final VoidCallback? onTimeTap;
  final Future<void> Function(EditedImageResult result)? onReplaceAttachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider).valueOrNull;
    final account = session?.currentAccount;
    final sessionController = ref.read(appSessionProvider.notifier);
    final serverVersion = account == null
        ? ''
        : sessionController.resolveEffectiveServerVersionForAccount(
            account: account,
          );
    final baseUrl = account?.baseUrl;
    final token = account?.personalAccessToken ?? '';
    final authHeader = token.trim().isEmpty ? null : 'Bearer $token';
    final rebaseAbsoluteFileUrlForV024 = isServerVersion024(serverVersion);
    final attachAuthForSameOriginAbsolute = isServerVersion021(serverVersion);
    final renderInlineImages = contentHasThirdPartyShareMarker(memo.content);
    final inlineImageSourcePolicy = renderInlineImages
        ? buildMemoInlineImageSourcePolicy(
            content: memo.content,
            attachments: memo.attachments,
          )
        : MemoInlineImageSourcePolicy.empty;
    final tagRecognitionPolicy = ref.watch(
      currentWorkspacePreferencesProvider.select(
        (prefs) => prefs.tagRecognitionPolicy,
      ),
    );
    final mediaEntries =
        mediaEntriesOverride ??
        () {
          final imageEntries = collectMemoImageEntries(
            content: memo.content,
            attachments: memo.attachments,
            baseUrl: baseUrl,
            authHeader: authHeader,
            rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
            attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
          );
          final videoEntries = collectMemoVideoEntries(
            attachments: memo.attachments,
            baseUrl: baseUrl,
            authHeader: authHeader,
            rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
            attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
          );
          return renderInlineImages
              ? buildMemoMediaEntries(
                  images: imageEntries
                      .where((entry) => entry.isAttachment)
                      .toList(growable: false),
                  videos: videoEntries,
                )
              : buildMemoMediaEntries(
                  images: imageEntries,
                  videos: videoEntries,
                );
        }();
    final imagePreviewItems = collectMemoDocumentImagePreviewItems(
      content: memo.content,
      attachments: memo.attachments,
      baseUrl: baseUrl,
      authHeader: authHeader,
      rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
      attachAuthForSameOriginAbsolute: attachAuthForSameOriginAbsolute,
    );
    final nonMediaAttachments =
        nonMediaAttachmentsOverride ??
        filterNonMediaAttachments(memo.attachments);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final imageBg = isDark
        ? MemoFlowPalette.audioSurfaceDark.withValues(alpha: 0.6)
        : MemoFlowPalette.audioSurfaceLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final tagColors = ref.watch(tagColorLookupProvider);
    final locationProvider = ref.watch(
      locationSettingsProvider.select((value) => value.provider),
    );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDivider)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.32),
              ),
            ),
          if (showMetadata) ...[
            _MemoReaderTimeLabel(
              text: formatMemoReaderDisplayTime(memo),
              style:
                  metaTextStyle ??
                  Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              onTap: onTimeTap,
            ),
            if (memo.location != null) ...[
              const SizedBox(height: 6),
              MemoLocationLine(
                location: memo.location!,
                textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                onTap: () => openMemoLocation(
                  context,
                  memo.location!,
                  memoUid: memo.uid,
                  provider: locationProvider,
                ),
                fontSize: 12,
              ),
            ],
            const SizedBox(height: 10),
          ],
          contentOverride ??
              MemoMarkdown(
                cacheKey:
                    'reader|${memo.uid}|${memo.contentFingerprint}|${highlightQuery ?? ''}|${renderInlineImages ? 1 : 0}|tagPolicy=${tagRecognitionPolicy.cacheToken}|localInline=${inlineImageSourcePolicy.fingerprint}',
                data: memo.content,
                highlightQuery: highlightQuery,
                tagRecognitionPolicy: tagRecognitionPolicy,
                textStyle:
                    contentTextStyle ?? Theme.of(context).textTheme.bodyLarge,
                selectable: selectable,
                blockSpacing: 8,
                renderImages: renderInlineImages,
                tagColors: tagColors,
                baseUrl: baseUrl,
                authHeader: authHeader,
                rebaseAbsoluteFileUrlForV024: rebaseAbsoluteFileUrlForV024,
                attachAuthForSameOriginAbsolute:
                    attachAuthForSameOriginAbsolute,
                imagePreviewItems: imagePreviewItems,
                allowedLocalImageUrls:
                    inlineImageSourcePolicy.allowedLocalImageUrls,
                onOpenImagePreview: (request) =>
                    ImagePreviewLauncher.open(context, request),
              ),
          if (mediaEntries.isNotEmpty) ...[
            const SizedBox(height: 14),
            MemoMediaGrid(
              entries: mediaEntries,
              columns: 3,
              maxCount: mediaMaxCount,
              maxHeight:
                  MediaQuery.of(context).size.height * mediaMaxHeightFactor,
              preserveSquareTilesWhenHeightLimited: isDesktopTargetPlatform(),
              borderColor: borderColor.withValues(alpha: 0.65),
              backgroundColor: imageBg,
              textColor: textMain,
              radius: 12,
              spacing: 8,
              onReplace: onReplaceAttachment,
              enableDownload: true,
              enablePreviewOnTap: previewImageOnTap,
            ),
          ],
          if (showAttachmentsSection && nonMediaAttachments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              context.t.strings.legacy.msg_attachments,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: 8),
            ...nonMediaAttachments.map(
              (attachment) => _ReaderAttachmentTile(attachment: attachment),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReaderAttachmentTile extends StatelessWidget {
  const _ReaderAttachmentTile({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final title = attachment.filename.trim().isNotEmpty
        ? attachment.filename.trim()
        : attachment.uid;
    final subtitle = attachment.type.trim().isNotEmpty
        ? attachment.type.trim()
        : context.t.strings.legacy.msg_attachments;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.22 : 0.34,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isDark ? 0.12 : 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.attach_file_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
