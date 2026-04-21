import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/image_error_logger.dart';
import '../../../core/image_formats.dart';
import '../image_preview_item.dart';

class ImagePreviewTile extends StatelessWidget {
  const ImagePreviewTile({
    super.key,
    required this.item,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.backgroundColor,
    required this.borderColor,
    required this.placeholderColor,
    this.iconColor,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    this.onTap,
    this.logScope = 'image_preview_tile',
  });

  final ImagePreviewItem item;
  final double width;
  final double height;
  final double borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final Color placeholderColor;
  final Color? iconColor;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final VoidCallback? onTap;
  final String logScope;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: _buildContent(),
      ),
    );
    if (onTap == null) {
      return tile;
    }
    return GestureDetector(onTap: onTap, child: tile);
  }

  Widget _buildContent() {
    final file = item.localFile;
    if (file != null) {
      final isSvg = shouldUseSvgRenderer(url: file.path, mimeType: item.mimeType);
      if (isSvg) {
        return SvgPicture.file(
          file,
          fit: fit,
          placeholderBuilder: (context) => _placeholder(Icons.image_outlined),
          errorBuilder: (context, error, stackTrace) {
            logImageLoadError(
              scope: '${logScope}_local_svg',
              source: file.path,
              error: error,
              stackTrace: stackTrace,
              extraContext: _logContext(),
            );
            return _placeholder(Icons.broken_image_outlined);
          },
        );
      }
      return Image.file(
        file,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (context, error, stackTrace) {
          logImageLoadError(
            scope: '${logScope}_local',
            source: file.path,
            error: error,
            stackTrace: stackTrace,
            extraContext: _logContext(),
          );
          return _placeholder(Icons.broken_image_outlined);
        },
      );
    }

    final url = item.resolvedTileUrl;
    if (url == null || url.isEmpty) {
      return _placeholder(Icons.image_outlined);
    }

    final isSvg = shouldUseSvgRenderer(url: url, mimeType: item.mimeType);
    if (isSvg) {
      return SvgPicture.network(
        url,
        headers: item.headers,
        fit: fit,
        placeholderBuilder: (context) => _placeholder(Icons.image_outlined),
        errorBuilder: (context, error, stackTrace) {
          logImageLoadError(
            scope: '${logScope}_network_svg',
            source: url,
            error: error,
            stackTrace: stackTrace,
            extraContext: _logContext(),
          );
          return _placeholder(Icons.broken_image_outlined);
        },
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: item.headers,
      fit: fit,
      placeholder: (context, _) => _placeholder(Icons.image_outlined),
      errorWidget: (context, _, error) {
        logImageLoadError(
          scope: '${logScope}_network',
          source: url,
          error: error,
          extraContext: _logContext(),
        );
        return _placeholder(Icons.broken_image_outlined);
      },
    );
  }

  Widget _placeholder(IconData icon) {
    return Container(
      color: placeholderColor,
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 20,
        color: iconColor ?? Colors.white.withValues(alpha: 0.78),
      ),
    );
  }

  Map<String, Object?> _logContext() {
    return <String, Object?>{
      'itemId': item.id,
      'mimeType': item.mimeType,
      'hasAuthHeader':
          item.headers?['Authorization']?.trim().isNotEmpty ?? false,
    };
  }
}
