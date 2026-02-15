import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_localization.dart';
import 'log_sanitizer.dart';
import '../data/logs/log_manager.dart';
import '../data/models/memo_location.dart';

String _defaultLocationLabel(BuildContext context) {
  return trByLanguageKey(
    language: context.appLanguage,
    key: 'legacy.location.current',
  );
}

Future<void> openAmapLocation(
  BuildContext context,
  MemoLocation location, {
  String? name,
  String? memoUid,
}) async {
  final label = (name ?? '').trim().isNotEmpty
      ? name!.trim()
      : (location.hasPlaceholder ? location.placeholder.trim() : _defaultLocationLabel(context));
  final lat = location.latitude.toStringAsFixed(6);
  final lng = location.longitude.toStringAsFixed(6);
  final memo = (memoUid ?? '').trim();
  final locationFp = LogSanitizer.locationFingerprint(
    latitude: location.latitude,
    longitude: location.longitude,
    locationName: label,
  );
  final baseLogContext = <String, Object?>{
    if (memo.isNotEmpty) 'memo': memo,
    'has_location': true,
    if (locationFp.isNotEmpty) 'loc_fp': locationFp,
  };

  final scheme = Platform.isIOS ? 'iosamap' : 'androidamap';
  final amapUri = Uri.parse(
    '$scheme://viewMap?sourceApplication=MemoFlow&lat=$lat&lon=$lng&dev=0&poiname=${Uri.encodeComponent(label)}',
  );
  final maskedAmapUrl = LogSanitizer.maskUrl(amapUri.toString());
  LogManager.instance.info(
    'Map launch attempt scheme',
    context: <String, Object?>{...baseLogContext, 'url': maskedAmapUrl},
  );

  try {
    final launched = await launchUrl(amapUri, mode: LaunchMode.externalApplication);
    LogManager.instance.info(
      'Map launch result scheme',
      context: <String, Object?>{
        ...baseLogContext,
        'url': maskedAmapUrl,
        'launched': launched,
      },
    );
    if (launched) return;
  } catch (error, stackTrace) {
    LogManager.instance.warn(
      'Map launch failed scheme',
      error: error,
      stackTrace: stackTrace,
      context: <String, Object?>{...baseLogContext, 'url': maskedAmapUrl},
    );
  }

  final fallback = Uri.parse(
    'https://uri.amap.com/marker?position=$lng,$lat&name=${Uri.encodeComponent(label)}',
  );
  final maskedFallbackUrl = LogSanitizer.maskUrl(fallback.toString());
  LogManager.instance.info(
    'Map launch attempt web',
    context: <String, Object?>{...baseLogContext, 'url': maskedFallbackUrl},
  );
  try {
    final launched = await launchUrl(
      fallback,
      mode: LaunchMode.externalApplication,
    );
    LogManager.instance.info(
      'Map launch result web',
      context: <String, Object?>{
        ...baseLogContext,
        'url': maskedFallbackUrl,
        'launched': launched,
      },
    );
  } catch (error, stackTrace) {
    LogManager.instance.error(
      'Map launch failed web',
      error: error,
      stackTrace: stackTrace,
      context: <String, Object?>{...baseLogContext, 'url': maskedFallbackUrl},
    );
    rethrow;
  }
}
