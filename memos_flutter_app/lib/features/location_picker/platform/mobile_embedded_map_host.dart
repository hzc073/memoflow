import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../data/location/location_provider_bundle.dart';
import '../../../data/location/models/canonical_coordinate.dart';
import '../embedded_map_host.dart';

class MobileEmbeddedMapHost extends StatefulWidget {
  const MobileEmbeddedMapHost({
    super.key,
    required this.controller,
    required this.bundle,
  });

  final EmbeddedMapHostBridgeController controller;
  final LocationProviderBundle bundle;

  @override
  State<MobileEmbeddedMapHost> createState() => _MobileEmbeddedMapHostState();
}

class _MobileEmbeddedMapHostState extends State<MobileEmbeddedMapHost> {
  static const _channelName = 'MemoflowHost';

  late final WebViewController _webViewController;
  bool _loaded = false;
  (CanonicalCoordinate, double?)? _pendingMove;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _loaded = true;
            final pendingMove = _pendingMove;
            if (pendingMove != null) {
              _pendingMove = null;
              unawaited(_runMove(pendingMove.$1, pendingMove.$2));
            }
          },
          onWebResourceError: (error) {
            widget.controller.emit(
              EmbeddedMapEvent(
                type: EmbeddedMapEventType.error,
                message: error.description,
              ),
            );
          },
        ),
      )
      ..addJavaScriptChannel(
        _channelName,
        onMessageReceived: (message) => _handleBridgeMessage(message.message),
      );
    widget.controller.attach(onInitialize: _initializeHost, onMoveTo: _moveTo);
  }

  @override
  void dispose() {
    widget.controller.detach();
    super.dispose();
  }

  Future<void> _initializeHost(CanonicalCoordinate center, double zoom) async {
    _loaded = false;
    final html = await _buildHtml(center: center, zoom: zoom);
    await _webViewController.loadHtmlString(html);
  }

  Future<void> _moveTo(CanonicalCoordinate center, double? zoom) async {
    if (!_loaded) {
      _pendingMove = (center, zoom);
      return;
    }
    await _runMove(center, zoom);
  }

  Future<void> _runMove(CanonicalCoordinate center, double? zoom) {
    final providerCoordinate = widget.bundle.adapter.toProviderCoordinate(
      center,
    );
    final zoomValue = zoom == null ? 'undefined' : zoom.toStringAsFixed(2);
    final script =
        'window.memoflowMap && window.memoflowMap.moveTo(${providerCoordinate.latitude.toStringAsFixed(8)}, ${providerCoordinate.longitude.toStringAsFixed(8)}, $zoomValue);';
    return _webViewController.runJavaScript(script);
  }

  Future<String> _buildHtml({
    required CanonicalCoordinate center,
    required double zoom,
  }) async {
    final assetPath = switch (widget.bundle.provider) {
      _ => 'assets/location_picker/${widget.bundle.provider.name}_host.html',
    };
    final template = await rootBundle.loadString(assetPath);
    final providerCoordinate = widget.bundle.adapter.toProviderCoordinate(
      center,
    );
    return template
        .replaceAll('__API_KEY__', widget.bundle.apiKey)
        .replaceAll('__SECURITY_KEY__', widget.bundle.securityKey)
        .replaceAll('__LAT__', providerCoordinate.latitude.toStringAsFixed(8))
        .replaceAll('__LNG__', providerCoordinate.longitude.toStringAsFixed(8))
        .replaceAll('__ZOOM__', zoom.toStringAsFixed(2));
  }

  void _handleBridgeMessage(String message) {
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map) return;
      _emitDecoded(decoded.cast<String, dynamic>());
    } catch (_) {}
  }

  void _emitDecoded(Map<String, dynamic> payload) {
    final type = payload['type']?.toString();
    final lat = (payload['lat'] as num?)?.toDouble();
    final lng = (payload['lng'] as num?)?.toDouble();
    final zoom = (payload['zoom'] as num?)?.toDouble();
    final coordinate = lat != null && lng != null
        ? widget.bundle.adapter.fromProviderCoordinate(
            ProviderCoordinate(
              latitude: lat,
              longitude: lng,
              system: widget.bundle.adapter
                  .toProviderCoordinate(
                    const CanonicalCoordinate(latitude: 0, longitude: 0),
                  )
                  .system,
            ),
          )
        : null;
    switch (type) {
      case 'ready':
        widget.controller.emit(
          EmbeddedMapEvent(
            type: EmbeddedMapEventType.ready,
            coordinate: coordinate,
            zoom: zoom,
          ),
        );
        break;
      case 'cameraIdle':
        widget.controller.emit(
          EmbeddedMapEvent(
            type: EmbeddedMapEventType.cameraIdle,
            coordinate: coordinate,
            zoom: zoom,
          ),
        );
        break;
      case 'tap':
        widget.controller.emit(
          EmbeddedMapEvent(
            type: EmbeddedMapEventType.tap,
            coordinate: coordinate,
            zoom: zoom,
          ),
        );
        break;
      case 'error':
        widget.controller.emit(
          EmbeddedMapEvent(
            type: EmbeddedMapEventType.error,
            message: payload['message']?.toString(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _webViewController);
  }
}
