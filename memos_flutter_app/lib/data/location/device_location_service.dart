import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  LocationException(this.code);
  final String code;

  @override
  String toString() => code;
}

class DeviceLocationService {
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('service_disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationException('permission_denied');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException('permission_denied_forever');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw LocationException('timeout'),
    );
  }

  Future<bool> openSystemLocationSettings() {
    return Geolocator.openLocationSettings();
  }
}
