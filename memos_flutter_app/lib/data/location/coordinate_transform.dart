import 'dart:math' as math;

import 'models/canonical_coordinate.dart';

const _pi = math.pi;
const _earthRadius = 6378245.0;
const _ee = 0.00669342162296594323;

bool isInChina({required double latitude, required double longitude}) {
  return longitude >= 72.004 &&
      longitude <= 137.8347 &&
      latitude >= 0.8293 &&
      latitude <= 55.8271;
}

CanonicalCoordinate wgs84ToGcj02(CanonicalCoordinate coordinate) {
  if (!isInChina(
    latitude: coordinate.latitude,
    longitude: coordinate.longitude,
  )) {
    return coordinate;
  }

  final delta = _delta(
    latitude: coordinate.latitude,
    longitude: coordinate.longitude,
  );
  return CanonicalCoordinate(
    latitude: coordinate.latitude + delta.latitude,
    longitude: coordinate.longitude + delta.longitude,
  );
}

CanonicalCoordinate gcj02ToWgs84(CanonicalCoordinate coordinate) {
  if (!isInChina(
    latitude: coordinate.latitude,
    longitude: coordinate.longitude,
  )) {
    return coordinate;
  }

  final g2 = wgs84ToGcj02(coordinate);
  return CanonicalCoordinate(
    latitude: coordinate.latitude * 2 - g2.latitude,
    longitude: coordinate.longitude * 2 - g2.longitude,
  );
}

CanonicalCoordinate gcj02ToBd09(CanonicalCoordinate coordinate) {
  if (!isInChina(
    latitude: coordinate.latitude,
    longitude: coordinate.longitude,
  )) {
    return coordinate;
  }

  final x = coordinate.longitude;
  final y = coordinate.latitude;
  final z =
      math.sqrt(x * x + y * y) + 0.00002 * math.sin(y * _pi * 3000.0 / 180.0);
  final theta =
      math.atan2(y, x) + 0.000003 * math.cos(x * _pi * 3000.0 / 180.0);
  return CanonicalCoordinate(
    latitude: z * math.sin(theta) + 0.006,
    longitude: z * math.cos(theta) + 0.0065,
  );
}

CanonicalCoordinate bd09ToGcj02(CanonicalCoordinate coordinate) {
  if (!isInChina(
    latitude: coordinate.latitude,
    longitude: coordinate.longitude,
  )) {
    return coordinate;
  }

  final x = coordinate.longitude - 0.0065;
  final y = coordinate.latitude - 0.006;
  final z =
      math.sqrt(x * x + y * y) - 0.00002 * math.sin(y * _pi * 3000.0 / 180.0);
  final theta =
      math.atan2(y, x) - 0.000003 * math.cos(x * _pi * 3000.0 / 180.0);
  return CanonicalCoordinate(
    latitude: z * math.sin(theta),
    longitude: z * math.cos(theta),
  );
}

CanonicalCoordinate wgs84ToBd09(CanonicalCoordinate coordinate) {
  return gcj02ToBd09(wgs84ToGcj02(coordinate));
}

CanonicalCoordinate bd09ToWgs84(CanonicalCoordinate coordinate) {
  return gcj02ToWgs84(bd09ToGcj02(coordinate));
}

CanonicalCoordinate _delta({
  required double latitude,
  required double longitude,
}) {
  var dLat = _transformLat(longitude - 105.0, latitude - 35.0);
  var dLng = _transformLng(longitude - 105.0, latitude - 35.0);
  final radLat = latitude / 180.0 * _pi;
  var magic = math.sin(radLat);
  magic = 1 - _ee * magic * magic;
  final sqrtMagic = math.sqrt(magic);
  dLat =
      (dLat * 180.0) /
      (((_earthRadius * (1 - _ee)) / (magic * sqrtMagic)) * _pi);
  dLng = (dLng * 180.0) / ((_earthRadius / sqrtMagic) * math.cos(radLat) * _pi);
  return CanonicalCoordinate(latitude: dLat, longitude: dLng);
}

double _transformLat(double x, double y) {
  var ret =
      -100.0 +
      2.0 * x +
      3.0 * y +
      0.2 * y * y +
      0.1 * x * y +
      0.2 * math.sqrt(x.abs());
  ret +=
      (20.0 * math.sin(6.0 * x * _pi) + 20.0 * math.sin(2.0 * x * _pi)) *
      2.0 /
      3.0;
  ret +=
      (20.0 * math.sin(y * _pi) + 40.0 * math.sin(y / 3.0 * _pi)) * 2.0 / 3.0;
  ret +=
      (160.0 * math.sin(y / 12.0 * _pi) + 320 * math.sin(y * _pi / 30.0)) *
      2.0 /
      3.0;
  return ret;
}

double _transformLng(double x, double y) {
  var ret =
      300.0 +
      x +
      2.0 * y +
      0.1 * x * x +
      0.1 * x * y +
      0.1 * math.sqrt(x.abs());
  ret +=
      (20.0 * math.sin(6.0 * x * _pi) + 20.0 * math.sin(2.0 * x * _pi)) *
      2.0 /
      3.0;
  ret +=
      (20.0 * math.sin(x * _pi) + 40.0 * math.sin(x / 3.0 * _pi)) * 2.0 / 3.0;
  ret +=
      (150.0 * math.sin(x / 12.0 * _pi) + 300.0 * math.sin(x / 30.0 * _pi)) *
      2.0 /
      3.0;
  return ret;
}

double distanceBetween(CanonicalCoordinate a, CanonicalCoordinate b) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _degreesToRadians(b.latitude - a.latitude);
  final dLng = _degreesToRadians(b.longitude - a.longitude);
  final lat1 = _degreesToRadians(a.latitude);
  final lat2 = _degreesToRadians(b.latitude);
  final hav =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(lat1) * math.cos(lat2);
  final c = 2 * math.atan2(math.sqrt(hav), math.sqrt(1 - hav));
  return earthRadiusMeters * c;
}

double _degreesToRadians(double value) => value * _pi / 180.0;
