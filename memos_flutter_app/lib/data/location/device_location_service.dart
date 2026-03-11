import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../logs/log_manager.dart';

class LocationException implements Exception {
  LocationException(this.code);
  final String code;

  @override
  String toString() => code;
}

class DeviceLocationService {
  Future<Position> getCurrentPosition() async {
    _logInfo('request_start');
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    _logInfo('service_checked', context: {'enabled': serviceEnabled});
    if (!serviceEnabled) {
      _logWarn('service_disabled');
      throw LocationException('service_disabled');
    }

    var permission = await Geolocator.checkPermission();
    _logInfo('permission_checked', context: {'permission': permission.name});
    if (permission == LocationPermission.denied) {
      _logInfo('permission_request_start');
      permission = await Geolocator.requestPermission();
      _logInfo('permission_request_result', context: {'permission': permission.name});
    }
    if (permission == LocationPermission.denied) {
      _logWarn('permission_denied');
      throw LocationException('permission_denied');
    }
    if (permission == LocationPermission.deniedForever) {
      _logWarn('permission_denied_forever');
      throw LocationException('permission_denied_forever');
    }

    Position? lastKnownPosition;
    try {
      lastKnownPosition = await Geolocator.getLastKnownPosition();
      _logInfo(
        'last_known_checked',
        context: {
          'available': lastKnownPosition != null,
          'latitude': lastKnownPosition?.latitude,
          'longitude': lastKnownPosition?.longitude,
          'accuracy': lastKnownPosition?.accuracy,
          'timestamp': lastKnownPosition?.timestamp.toIso8601String(),
          'isMocked': lastKnownPosition?.isMocked,
        },
      );
    } catch (error, stackTrace) {
      _logWarn(
        'last_known_failed',
        context: {'error': error.toString()},
        error: error,
        stackTrace: stackTrace,
      );
    }

    try {
      _logInfo('current_position_start', context: {'accuracy': 'high'});
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw LocationException('timeout'),
      );
      _logInfo(
        'current_position_success',
        context: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': position.timestamp.toIso8601String(),
          'isMocked': position.isMocked,
        },
      );
      return position;
    } on LocationException catch (error) {
      if (error.code == 'timeout' && lastKnownPosition != null) {
        _logWarn(
          'current_position_timeout_using_last_known',
          context: {
            'latitude': lastKnownPosition.latitude,
            'longitude': lastKnownPosition.longitude,
            'accuracy': lastKnownPosition.accuracy,
            'timestamp': lastKnownPosition.timestamp.toIso8601String(),
          },
        );
        return lastKnownPosition;
      }
      _logWarn('current_position_location_exception', context: {'code': error.code});
      rethrow;
    } catch (error, stackTrace) {
      if (lastKnownPosition != null) {
        _logWarn(
          'current_position_failed_using_last_known',
          context: {
            'error': error.toString(),
            'latitude': lastKnownPosition.latitude,
            'longitude': lastKnownPosition.longitude,
            'accuracy': lastKnownPosition.accuracy,
            'timestamp': lastKnownPosition.timestamp.toIso8601String(),
          },
          error: error,
          stackTrace: stackTrace,
        );
        return lastKnownPosition;
      }
      _logWarn(
        'current_position_failed',
        context: {'error': error.toString()},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<bool> openSystemLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  void _logInfo(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    LogManager.instance.info(
      'DeviceLocationService: $message',
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _logWarn(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    LogManager.instance.warn(
      'DeviceLocationService: $message',
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
