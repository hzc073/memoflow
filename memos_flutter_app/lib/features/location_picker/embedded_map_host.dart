import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../data/location/location_provider_bundle.dart';
import '../../data/location/models/canonical_coordinate.dart';
import 'platform/mobile_embedded_map_host.dart';
import 'platform/windows_embedded_map_host.dart';
import 'location_picker_logger.dart';

enum EmbeddedMapEventType { ready, cameraIdle, tap, error }

class EmbeddedMapEvent {
  const EmbeddedMapEvent({
    required this.type,
    this.coordinate,
    this.zoom,
    this.message,
  });

  final EmbeddedMapEventType type;
  final CanonicalCoordinate? coordinate;
  final double? zoom;
  final String? message;
}

abstract class EmbeddedMapHostController {
  Future<void> initialize({
    required CanonicalCoordinate center,
    double zoom = 16,
  });

  Future<void> moveTo(CanonicalCoordinate center, {double? zoom});

  Stream<EmbeddedMapEvent> get events;

  Future<void> dispose();
}

class EmbeddedMapHostBridgeController implements EmbeddedMapHostController {
  EmbeddedMapHostBridgeController();

  final StreamController<EmbeddedMapEvent> _events =
      StreamController<EmbeddedMapEvent>.broadcast();
  Future<void> Function(CanonicalCoordinate center, double zoom)?
      _initializeCallback;
  Future<void> Function(CanonicalCoordinate center, double? zoom)? _moveToCallback;
  CanonicalCoordinate? _pendingCenter;
  double _pendingZoom = 16;
  CanonicalCoordinate? _pendingMoveCenter;
  double? _pendingMoveZoom;
  bool _disposed = false;

  @override
  Stream<EmbeddedMapEvent> get events => _events.stream;

  void attach({
    required Future<void> Function(CanonicalCoordinate center, double zoom)
        onInitialize,
    required Future<void> Function(CanonicalCoordinate center, double? zoom)
        onMoveTo,
  }) {
    _initializeCallback = onInitialize;
    _moveToCallback = onMoveTo;
    LocationPickerLogger.info(
      'bridge_attach',
      context: {
        'hasPendingCenter': _pendingCenter != null,
        'hasPendingMoveCenter': _pendingMoveCenter != null,
      },
    );
    final pendingCenter = _pendingCenter;
    if (pendingCenter != null) {
      LocationPickerLogger.info(
        'bridge_dispatch_pending_initialize',
        context: {
          'latitude': pendingCenter.latitude,
          'longitude': pendingCenter.longitude,
          'zoom': _pendingZoom,
        },
      );
      unawaited(onInitialize(pendingCenter, _pendingZoom));
    }
    final pendingMoveCenter = _pendingMoveCenter;
    if (pendingMoveCenter != null) {
      LocationPickerLogger.info(
        'bridge_dispatch_pending_move',
        context: {
          'latitude': pendingMoveCenter.latitude,
          'longitude': pendingMoveCenter.longitude,
          'zoom': _pendingMoveZoom,
        },
      );
      unawaited(onMoveTo(pendingMoveCenter, _pendingMoveZoom));
    }
  }

  void detach() {
    _initializeCallback = null;
    _moveToCallback = null;
  }

  void emit(EmbeddedMapEvent event) {
    if (_disposed || _events.isClosed) return;
    _events.add(event);
  }

  @override
  Future<void> initialize({
    required CanonicalCoordinate center,
    double zoom = 16,
  }) async {
    _pendingCenter = center;
    _pendingZoom = zoom;
    LocationPickerLogger.info(
      'bridge_initialize_requested',
      context: {
        'hasCallback': _initializeCallback != null,
        'latitude': center.latitude,
        'longitude': center.longitude,
        'zoom': zoom,
      },
    );
    final callback = _initializeCallback;
    if (callback != null) {
      await callback(center, zoom);
    }
  }

  @override
  Future<void> moveTo(CanonicalCoordinate center, {double? zoom}) async {
    _pendingMoveCenter = center;
    _pendingMoveZoom = zoom;
    LocationPickerLogger.debug(
      'bridge_move_requested',
      context: {
        'hasCallback': _moveToCallback != null,
        'latitude': center.latitude,
        'longitude': center.longitude,
        'zoom': zoom,
      },
    );
    final callback = _moveToCallback;
    if (callback != null) {
      await callback(center, zoom);
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    detach();
    await _events.close();
  }
}

class EmbeddedMapHost extends StatelessWidget {
  const EmbeddedMapHost({
    super.key,
    required this.controller,
    required this.bundle,
  });

  final EmbeddedMapHostBridgeController controller;
  final LocationProviderBundle bundle;

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows) {
      return WindowsEmbeddedMapHost(controller: controller, bundle: bundle);
    }
    return MobileEmbeddedMapHost(controller: controller, bundle: bundle);
  }
}
