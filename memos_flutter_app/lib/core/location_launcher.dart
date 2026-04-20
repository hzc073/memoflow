import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_localization.dart';
import 'log_sanitizer.dart';
import '../data/location/coordinate_transform.dart';
import '../data/location/models/canonical_coordinate.dart';
import '../data/logs/log_manager.dart';
import '../data/models/memo_location.dart';
import '../data/models/location_settings.dart';

String _defaultLocationLabel(BuildContext context) {
  return trByLanguageKey(
    language: context.appLanguage,
    key: 'legacy.location.current',
  );
}

Future<void> openMemoLocation(
  BuildContext context,
  MemoLocation location, {
  String? name,
  String? memoUid,
  LocationServiceProvider provider = LocationServiceProvider.amap,
}) async {
  final label = (name ?? '').trim().isNotEmpty
      ? name!.trim()
      : (location.hasPlaceholder
            ? location.placeholder.trim()
            : _defaultLocationLabel(context));
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
    'provider': provider.name,
    if (locationFp.isNotEmpty) 'loc_fp': locationFp,
  };

  final candidates = switch (provider) {
    LocationServiceProvider.amap => _amapCandidates(
      lat: lat,
      lng: lng,
      label: label,
    ),
    LocationServiceProvider.baidu => _baiduCandidates(
      lat: lat,
      lng: lng,
      label: label,
    ),
    LocationServiceProvider.google => _googleCandidates(
      lat: lat,
      lng: lng,
      label: label,
    ),
  };

  var launchError = false;
  for (final uri in candidates) {
    final masked = LogSanitizer.maskUrl(uri.toString());
    LogManager.instance.info(
      'Map launch attempt',
      context: <String, Object?>{...baseLogContext, 'url': masked},
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      LogManager.instance.info(
        'Map launch result',
        context: <String, Object?>{
          ...baseLogContext,
          'url': masked,
          'launched': launched,
        },
      );
      if (launched) return;
    } catch (error, stackTrace) {
      launchError = true;
      LogManager.instance.warn(
        'Map launch failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{...baseLogContext, 'url': masked},
      );
    }
  }
  if (launchError) {
    throw Exception('Unable to open map application');
  }
}

Future<void> openAmapLocation(
  BuildContext context,
  MemoLocation location, {
  String? name,
  String? memoUid,
}) {
  return openMemoLocation(
    context,
    location,
    name: name,
    memoUid: memoUid,
    provider: LocationServiceProvider.amap,
  );
}

List<Uri> _amapCandidates({
  required String lat,
  required String lng,
  required String label,
}) {
  final latitude = double.parse(lat);
  final longitude = double.parse(lng);
  return debugBuildAmapCandidates(
    latitude: latitude,
    longitude: longitude,
    label: label,
  );
}

@visibleForTesting
List<Uri> debugBuildAmapCandidates({
  required double latitude,
  required double longitude,
  required String label,
}) {
  return [
    debugBuildAmapWebUri(
      latitude: latitude,
      longitude: longitude,
      label: label,
    ),
    debugBuildAmapAppUri(
      latitude: latitude,
      longitude: longitude,
      label: label,
    ),
  ];
}

@visibleForTesting
Uri debugBuildAmapAppUri({
  required double latitude,
  required double longitude,
  required String label,
}) {
  final converted = wgs84ToGcj02(
    CanonicalCoordinate(latitude: latitude, longitude: longitude),
  );
  return Uri.parse(
    'androidamap://viewMap?sourceApplication=MemoFlow&lat=${converted.latitude.toStringAsFixed(6)}&lon=${converted.longitude.toStringAsFixed(6)}&dev=0&poiname=${Uri.encodeComponent(label)}',
  );
}

@visibleForTesting
Uri debugBuildAmapWebUri({
  required double latitude,
  required double longitude,
  required String label,
}) {
  return Uri.https('uri.amap.com', '/marker', <String, String>{
    'position':
        '${longitude.toStringAsFixed(6)},${latitude.toStringAsFixed(6)}',
    'name': label,
    'src': 'MemoFlow',
    'coordinate': 'wgs84',
    'callnative': '1',
  });
}

List<Uri> _baiduCandidates({
  required String lat,
  required String lng,
  required String label,
}) {
  return debugBuildBaiduCandidates(lat: lat, lng: lng, label: label);
}

@visibleForTesting
List<Uri> debugBuildBaiduCandidates({
  required String lat,
  required String lng,
  required String label,
}) {
  return [
    Uri.parse(
      'https://api.map.baidu.com/marker?location=$lat,$lng&title=${Uri.encodeComponent(label)}&content=${Uri.encodeComponent(label)}&output=html&coord_type=wgs84',
    ),
    Uri.parse(
      'baidumap://map/marker?location=$lat,$lng&title=${Uri.encodeComponent(label)}&content=${Uri.encodeComponent(label)}&coord_type=wgs84&src=MemoFlow',
    ),
  ];
}

List<Uri> _googleCandidates({
  required String lat,
  required String lng,
  required String label,
}) {
  return debugBuildGoogleCandidates(lat: lat, lng: lng, label: label);
}

@visibleForTesting
List<Uri> debugBuildGoogleCandidates({
  required String lat,
  required String lng,
  required String label,
}) {
  final appUri = Uri.parse(
    'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(label)})',
  );
  return [
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
    appUri,
  ];
}
