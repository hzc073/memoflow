import 'package:flutter/material.dart';

import '../../../core/memoflow_palette.dart';
import '../../../data/models/memo_clip_card_metadata.dart';

const String _coolapkLogoAsset = 'assets/images/coolapk_logo.png';

class MemoClipReadonlyHeader extends StatelessWidget {
  const MemoClipReadonlyHeader({
    super.key,
    required this.metadata,
    required this.title,
    this.compact = false,
    this.onSourceTap,
  });

  final MemoClipCardMetadata metadata;
  final String? title;
  final bool compact;
  final VoidCallback? onSourceTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locale = Localizations.localeOf(context);
    final resolvedTitle = (title ?? '').trim();
    final sourceName = metadata.sourceName.trim().isNotEmpty
        ? metadata.sourceName.trim()
        : _platformLabel(metadata.platform, locale);
    final authorName = metadata.authorName.trim();
    final preferAuthorAsPrimary =
        metadata.platform == MemoClipPlatform.coolapk && authorName.isNotEmpty;
    final primaryName = preferAuthorAsPrimary ? authorName : sourceName;
    final showAuthor =
        !preferAuthorAsPrimary &&
        authorName.isNotEmpty &&
        authorName.toLowerCase() != sourceName.toLowerCase() &&
        !_looksLikeClipTimestampLabel(authorName);
    final titleText = resolvedTitle.isNotEmpty
        ? resolvedTitle
        : _untitledLabel(locale);
    final sourceLinkLabel = memoClipDisplaySourceLabel(metadata.sourceUrl);
    final platformColor = _platformColor(metadata.platform);
    final headerGap = compact ? 8.0 : 10.0;
    final primaryAvatarUrl = preferAuthorAsPrimary
        ? (metadata.authorAvatarUrl.trim().isNotEmpty
              ? metadata.authorAvatarUrl.trim()
              : metadata.sourceAvatarUrl.trim())
        : (metadata.sourceAvatarUrl.trim().isNotEmpty
              ? metadata.sourceAvatarUrl.trim()
              : metadata.authorAvatarUrl.trim());
    final showLeadImage =
        metadata.platform != MemoClipPlatform.wechat &&
        metadata.leadImageUrl.trim().isNotEmpty;
    final identityTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _PlatformMetaLabel(platform: metadata.platform, compact: compact),
            if (sourceLinkLabel.isNotEmpty) ...[
              SizedBox(width: compact ? 8 : 10),
              Flexible(
                child: onSourceTap == null
                    ? _SourceLinkLabel(label: sourceLinkLabel, compact: compact)
                    : InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onSourceTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: _SourceLinkLabel(
                            label: sourceLinkLabel,
                            compact: compact,
                          ),
                        ),
                      ),
              ),
            ],
          ],
        ),
        SizedBox(height: headerGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ClipAvatar(
              imageUrl: primaryAvatarUrl,
              fallbackLabel: primaryName,
              backgroundColor: platformColor.withValues(alpha: 0.14),
              foregroundColor: platformColor,
              size: compact ? 16 : 18,
            ),
            SizedBox(width: compact ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    primaryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: identityTextStyle?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (showAuthor) ...[
                    SizedBox(height: compact ? 3 : 4),
                    Row(
                      children: [
                        if (metadata.authorAvatarUrl.trim().isNotEmpty) ...[
                          _MiniAvatar(
                            imageUrl: metadata.authorAvatarUrl.trim(),
                            fallbackLabel: authorName,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            foregroundColor: colorScheme.onSurfaceVariant,
                            size: compact ? 14 : 16,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: identityTextStyle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 8 : 10),
        Text(
          titleText,
          maxLines: compact ? 3 : 4,
          overflow: TextOverflow.ellipsis,
          style:
              (compact
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.headlineSmall)
                  ?.copyWith(fontWeight: FontWeight.w800, height: 1.22),
        ),
        if (showLeadImage) ...[
          SizedBox(height: compact ? 10 : 14),
          _ClipLeadImage(
            imageUrl: metadata.leadImageUrl.trim(),
            compact: compact,
          ),
        ],
      ],
    );
  }
}

String memoClipDisplaySourceLabel(String sourceUrl) {
  final normalizedUrl = sourceUrl.trim();
  if (normalizedUrl.isEmpty) return '';
  final uri = Uri.tryParse(normalizedUrl);
  final host = (uri?.host ?? '').trim().toLowerCase();
  if (host.isEmpty) return normalizedUrl;
  return host.startsWith('www.') ? host.substring(4) : host;
}

class _PlatformMetaLabel extends StatelessWidget {
  const _PlatformMetaLabel({required this.platform, required this.compact});

  final MemoClipPlatform platform;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlatformLogoGlyph(platform: platform, compact: compact),
        SizedBox(width: compact ? 5 : 6),
        Text(
          _platformLabel(platform, locale),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PlatformLogoGlyph extends StatelessWidget {
  const _PlatformLogoGlyph({required this.platform, required this.compact});

  final MemoClipPlatform platform;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 16.0 : 18.0;
    if (platform == MemoClipPlatform.coolapk) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 4 : 5),
        child: Image.asset(
          _coolapkLogoAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    final color = _platformColor(platform);
    final label = switch (platform) {
      MemoClipPlatform.wechat => '\u5fae',
      MemoClipPlatform.xiaohongshu => '\u5c0f',
      MemoClipPlatform.bilibili => 'B',
      MemoClipPlatform.web => 'W',
      MemoClipPlatform.coolapk => '\u9177',
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _ClipAvatar extends StatelessWidget {
  const _ClipAvatar({
    required this.imageUrl,
    required this.fallbackLabel,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.size,
  });

  final String imageUrl;
  final String fallbackLabel;
  final Color backgroundColor;
  final Color foregroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl.trim();
    final fallbackText = _avatarFallbackLabel(fallbackLabel);
    if (normalizedUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          normalizedUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _fallbackAvatar(fallbackText),
        ),
      );
    }
    return _fallbackAvatar(fallbackText);
  }

  Widget _fallbackAvatar(String fallbackText) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        fallbackText,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({
    required this.imageUrl,
    required this.fallbackLabel,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.size,
  });

  final String imageUrl;
  final String fallbackLabel;
  final Color backgroundColor;
  final Color foregroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return _ClipAvatar(
      imageUrl: imageUrl,
      fallbackLabel: fallbackLabel,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      size: size,
    );
  }
}

class _SourceLinkLabel extends StatelessWidget {
  const _SourceLinkLabel({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.link_rounded, size: compact ? 12 : 13, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClipLeadImage extends StatelessWidget {
  const _ClipLeadImage({required this.imageUrl, required this.compact});

  final String imageUrl;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 14 : 16),
      child: AspectRatio(
        aspectRatio: compact ? 1.8 : 2.1,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? MemoFlowPalette.audioSurfaceDark
                  : MemoFlowPalette.audioSurfaceLight,
              alignment: Alignment.center,
              child: Icon(
                Icons.image_not_supported_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          },
        ),
      ),
    );
  }
}

Color _platformColor(MemoClipPlatform platform) {
  return switch (platform) {
    MemoClipPlatform.wechat => const Color(0xFF07C160),
    MemoClipPlatform.xiaohongshu => const Color(0xFFFF2442),
    MemoClipPlatform.bilibili => const Color(0xFF00A1D6),
    MemoClipPlatform.coolapk => const Color(0xFF00C853),
    MemoClipPlatform.web => const Color(0xFF64748B),
  };
}

String _platformLabel(MemoClipPlatform platform, Locale locale) {
  final isZh = locale.languageCode.toLowerCase().startsWith('zh');
  return switch (platform) {
    MemoClipPlatform.wechat =>
      isZh ? '\u5fae\u4fe1\u516c\u4f17\u53f7' : 'WeChat',
    MemoClipPlatform.xiaohongshu => isZh ? '\u5c0f\u7ea2\u4e66' : 'Xiaohongshu',
    MemoClipPlatform.bilibili => 'Bilibili',
    MemoClipPlatform.coolapk => isZh ? '\u9177\u5b89' : 'CoolApk',
    MemoClipPlatform.web => isZh ? '\u7f51\u9875' : 'Web',
  };
}

String _untitledLabel(Locale locale) {
  return locale.languageCode.toLowerCase().startsWith('zh')
      ? '\u65e0\u6807\u9898'
      : 'Untitled';
}

String _avatarFallbackLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return '?';
  return normalized.substring(0, 1).toUpperCase();
}

bool _looksLikeClipTimestampLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return false;
  return RegExp(
        r'^\d{4}[-/.]\d{1,2}[-/.]\d{1,2}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?$',
      ).hasMatch(normalized) ||
      RegExp(r'^\d{1,2}\s*月\s*\d{1,2}\s*日').hasMatch(normalized) ||
      RegExp(r'^\d{1,2}:\d{2}(?::\d{2})?$').hasMatch(normalized);
}
