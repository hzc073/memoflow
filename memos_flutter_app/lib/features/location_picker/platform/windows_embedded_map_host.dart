import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../core/log_sanitizer.dart';
import '../../../data/logs/log_manager.dart';
import '../../../data/location/location_provider_bundle.dart';
import '../../../data/location/models/canonical_coordinate.dart';
import '../embedded_map_host.dart';
import '../location_picker_logger.dart';

class WindowsEmbeddedMapHost extends StatefulWidget {
  const WindowsEmbeddedMapHost({
    super.key,
    required this.controller,
    required this.bundle,
  });

  final EmbeddedMapHostBridgeController controller;
  final LocationProviderBundle bundle;

  @override
  State<WindowsEmbeddedMapHost> createState() => _WindowsEmbeddedMapHostState();
}

class _WindowsEmbeddedMapHostState extends State<WindowsEmbeddedMapHost> {
  static const _virtualHostName = 'location-picker.memoflow.local';

  final WebviewController _webViewController = WebviewController();
  StreamSubscription<dynamic>? _messageSubscription;
  StreamSubscription<LoadingState>? _loadingStateSubscription;
  StreamSubscription<WebErrorStatus>? _loadErrorSubscription;
  bool _loaded = false;
  (CanonicalCoordinate, double?)? _pendingMove;
  bool _initialized = false;
  String? _mappedFolderPath;
  bool _buildLogged = false;

  @override
  void initState() {
    super.initState();
    LocationPickerLogger.info(
      'windows_map_host_init_state',
      context: {'provider': widget.bundle.provider.name},
    );
    unawaited(_setup());
  }

  Future<void> _setup() async {
    try {
      _logInfo(
        'setup_start',
        context: {'provider': widget.bundle.provider.name},
      );
      _logDebug('webview_initialize_start');
      await _webViewController.initialize();
      _logDebug('webview_initialize_done');
      await _webViewController.setBackgroundColor(Colors.transparent);
      _logDebug('set_background_done');
      await _webViewController.setPopupWindowPolicy(
        WebviewPopupWindowPolicy.deny,
      );
      _logDebug('popup_policy_done');
      await _webViewController.addScriptToExecuteOnDocumentCreated(
        _diagnosticBootstrapScript,
      );
      _logDebug('diagnostic_script_done');
      _messageSubscription = _webViewController.webMessage.listen(
        (event) {
          if (event is Map) {
            _emitDecoded(Map<String, dynamic>.from(event));
            return;
          }
          if (event is String) {
            try {
              final decoded = jsonDecode(event);
              if (decoded is Map) {
                _emitDecoded(Map<String, dynamic>.from(decoded));
              }
            } catch (_) {}
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _logWarn(
            'bridge_message_error',
            error: error,
            stackTrace: stackTrace,
          );
        },
      );
      _loadingStateSubscription = _webViewController.loadingState.listen((
        state,
      ) {
        _logDebug('loading_state', context: {'state': state.name});
        if (state == LoadingState.navigationCompleted) {
          _loaded = true;
          final pendingMove = _pendingMove;
          if (pendingMove != null) {
            _pendingMove = null;
            unawaited(_runMove(pendingMove.$1, pendingMove.$2));
          }
        }
      });
      _loadErrorSubscription = _webViewController.onLoadError.listen((status) {
        final message = 'Windows map navigation failed: ${status.name}';
        _logWarn('load_error', context: {'status': status.name});
        widget.controller.emit(
          EmbeddedMapEvent(type: EmbeddedMapEventType.error, message: message),
        );
      });
      _logDebug('listeners_bound');
      _initialized = true;
      widget.controller.attach(
        onInitialize: _initializeHost,
        onMoveTo: _moveTo,
      );
      _logInfo('bridge_attached');
      setState(() {});
    } on PlatformException catch (error) {
      _logWarn(
        'setup_platform_exception',
        context: {
          'code': error.code,
          if ((error.message ?? '').trim().isNotEmpty)
            'messageRedacted': LogSanitizer.redactSemanticText(
              error.message!,
              kind: 'message',
            ),
        },
        error: error,
      );
      widget.controller.emit(
        EmbeddedMapEvent(
          type: EmbeddedMapEventType.error,
          message: error.message ?? error.code,
        ),
      );
    } catch (error, stackTrace) {
      _logWarn(
        'setup_unexpected_exception',
        context: {
          'errorRedacted': LogSanitizer.redactSemanticText(
            error.toString(),
            kind: 'message',
          ),
        },
        error: error,
        stackTrace: stackTrace,
      );
      widget.controller.emit(
        EmbeddedMapEvent(
          type: EmbeddedMapEventType.error,
          message: error.toString(),
        ),
      );
    }
  }

  @override
  void dispose() {
    widget.controller.detach();
    unawaited(_messageSubscription?.cancel());
    unawaited(_loadingStateSubscription?.cancel());
    unawaited(_loadErrorSubscription?.cancel());
    if (_mappedFolderPath != null) {
      unawaited(
        _webViewController.removeVirtualHostNameMapping(_virtualHostName),
      );
    }
    unawaited(_webViewController.dispose());
    super.dispose();
  }

  Future<void> _initializeHost(CanonicalCoordinate center, double zoom) async {
    if (!_initialized) return;
    _logInfo(
      'initialize_host_start',
      context: {
        'provider': widget.bundle.provider.name,
        'latitude': center.latitude,
        'longitude': center.longitude,
        'zoom': zoom,
      },
    );
    try {
      _loaded = false;
      _logDebug('build_html_start');
      final html = await _buildHtml(center: center, zoom: zoom);
      _logDebug('build_html_done', context: {'length': html.length});
      _logDebug('prepare_mapped_html_start');
      final pageUrl = await _prepareMappedHtml(html);
      _logDebug('prepare_mapped_html_done', context: {'url': pageUrl});
      _logInfo(
        'initialize_host',
        context: {'provider': widget.bundle.provider.name, 'url': pageUrl},
      );
      _logDebug('load_url_start');
      await _webViewController.loadUrl(pageUrl);
      _logDebug('load_url_done');
    } on PlatformException catch (error) {
      _logWarn(
        'initialize_host_platform_exception',
        context: {
          'code': error.code,
          if ((error.message ?? '').trim().isNotEmpty)
            'messageRedacted': LogSanitizer.redactSemanticText(
              error.message!,
              kind: 'message',
            ),
        },
        error: error,
      );
      widget.controller.emit(
        EmbeddedMapEvent(
          type: EmbeddedMapEventType.error,
          message: error.message ?? error.code,
        ),
      );
    } catch (error, stackTrace) {
      _logWarn(
        'initialize_host_unexpected_exception',
        context: {
          'errorRedacted': LogSanitizer.redactSemanticText(
            error.toString(),
            kind: 'message',
          ),
        },
        error: error,
        stackTrace: stackTrace,
      );
      widget.controller.emit(
        EmbeddedMapEvent(
          type: EmbeddedMapEventType.error,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> _moveTo(CanonicalCoordinate center, double? zoom) async {
    _logDebug(
      'move_to_requested',
      context: {
        'loaded': _loaded,
        'initialized': _initialized,
        'latitude': center.latitude,
        'longitude': center.longitude,
        'zoom': zoom,
      },
    );
    if (!_initialized || !_loaded) {
      _pendingMove = (center, zoom);
      _logDebug('move_to_buffered');
      return;
    }
    await _runMove(center, zoom);
  }

  Future<void> _runMove(CanonicalCoordinate center, double? zoom) async {
    final providerCoordinate = widget.bundle.adapter.toProviderCoordinate(
      center,
    );
    final zoomValue = zoom == null ? 'undefined' : zoom.toStringAsFixed(2);
    final script =
        'window.memoflowMap && window.memoflowMap.moveTo(${providerCoordinate.latitude.toStringAsFixed(8)}, ${providerCoordinate.longitude.toStringAsFixed(8)}, $zoomValue);';
    await _webViewController.executeScript(script);
  }

  Future<String> _buildHtml({
    required CanonicalCoordinate center,
    required double zoom,
  }) async {
    final assetPath =
        'assets/location_picker/${widget.bundle.provider.name}_host.html';
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

  Future<String> _prepareMappedHtml(String html) async {
    final tempDirectory = await getTemporaryDirectory();
    final hostDirectory = Directory(
      p.join(tempDirectory.path, 'memoflow_location_picker_host'),
    );
    await hostDirectory.create(recursive: true);

    final fileName = '${widget.bundle.provider.name}_host.html';
    final htmlFile = File(p.join(hostDirectory.path, fileName));
    await htmlFile.writeAsString(html, flush: true);

    if (_mappedFolderPath != hostDirectory.path) {
      if (_mappedFolderPath != null) {
        await _webViewController.removeVirtualHostNameMapping(_virtualHostName);
      }
      await _webViewController.addVirtualHostNameMapping(
        _virtualHostName,
        hostDirectory.path,
        WebviewHostResourceAccessKind.allow,
      );
      _mappedFolderPath = hostDirectory.path;
    }

    final cacheBust = DateTime.now().microsecondsSinceEpoch.toString();
    return Uri.https(_virtualHostName, '/$fileName', {
      'v': cacheBust,
    }).toString();
  }

  void _emitDecoded(Map<String, dynamic> payload) {
    final type = payload['type']?.toString();
    if (type == 'console') {
      _logDebug(
        'js_console',
        context: {
          'messageRedacted': LogSanitizer.redactSemanticText(
            payload['message']?.toString() ?? '',
            kind: 'message',
          ),
        },
      );
      return;
    }
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
        _logWarn(
          'map_error',
          context: {
            'messageRedacted': LogSanitizer.redactSemanticText(
              payload['message']?.toString() ?? '',
              kind: 'message',
            ),
          },
        );
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
    if (!_buildLogged) {
      _buildLogged = true;
      LocationPickerLogger.info(
        'windows_map_host_build',
        context: {
          'provider': widget.bundle.provider.name,
          'initialized': _initialized,
          'controllerInitialized': _webViewController.value.isInitialized,
        },
      );
    }
    if (!_initialized || !_webViewController.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Webview(_webViewController);
  }

  void _logDebug(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    LogManager.instance.debug(
      'LocationPickerMapHost: $message',
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _logInfo(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    LogManager.instance.info(
      'LocationPickerMapHost: $message',
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
      'LocationPickerMapHost: $message',
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

const String _diagnosticBootstrapScript = r'''
(function() {
  function serialize(value) {
    if (typeof value === 'string') {
      return value;
    }
    try {
      return JSON.stringify(value);
    } catch (_) {
      return String(value);
    }
  }

  function post(payload) {
    try {
      if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage(JSON.stringify(payload));
      }
    } catch (_) {}
  }

  ['log', 'warn', 'error'].forEach(function(level) {
    var original = console[level];
    console[level] = function() {
      var message = Array.prototype.slice.call(arguments).map(serialize).join(' ');
      post({ type: 'console', message: level + ': ' + message });
      if (original) {
        return original.apply(console, arguments);
      }
    };
  });

  window.addEventListener('unhandledrejection', function(event) {
    post({
      type: 'error',
      message: 'Unhandled promise rejection: ' + serialize(event && event.reason)
    });
  });
})();
''';
