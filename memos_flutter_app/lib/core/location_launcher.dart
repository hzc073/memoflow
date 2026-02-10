import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_localization.dart';
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
}) async {
  final label = (name ?? '').trim().isNotEmpty
      ? name!.trim()
      : (location.hasPlaceholder ? location.placeholder.trim() : _defaultLocationLabel(context));
  final lat = location.latitude.toStringAsFixed(6);
  final lng = location.longitude.toStringAsFixed(6);

  final scheme = Platform.isIOS ? 'iosamap' : 'androidamap';
  final amapUri = Uri.parse(
    '$scheme://viewMap?sourceApplication=MemoFlow&lat=$lat&lon=$lng&dev=0&poiname=${Uri.encodeComponent(label)}',
  );

  try {
    final launched = await launchUrl(amapUri, mode: LaunchMode.externalApplication);
    if (launched) return;
  } catch (_) {}

  final fallback = Uri.parse(
    'https://uri.amap.com/marker?position=$lng,$lat&name=${Uri.encodeComponent(label)}',
  );
  await launchUrl(fallback, mode: LaunchMode.externalApplication);
}
