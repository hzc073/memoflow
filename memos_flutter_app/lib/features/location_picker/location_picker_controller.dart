import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/location/location_provider_bundle.dart';
import '../../data/location/device_location_service.dart';
import '../../data/location/models/canonical_coordinate.dart';
import '../../data/location/models/location_candidate.dart';
import '../../data/models/location_settings.dart';
import '../../data/models/memo_location.dart';
import 'embedded_map_host.dart';
import 'location_picker_logger.dart';

class LocationPickerState {
  const LocationPickerState({
    required this.providerLabel,
    required this.initialCenter,
    required this.currentCenter,
    required this.zoom,
    required this.query,
    required this.nearbyCandidates,
    required this.searchCandidates,
    required this.selectedCandidate,
    required this.reverseGeocodeLabel,
    required this.loading,
    required this.searching,
    required this.confirming,
    required this.mapReady,
    this.errorMessage,
  });

  factory LocationPickerState.initial({
    required String providerLabel,
    required CanonicalCoordinate center,
    double zoom = 16,
    String reverseGeocodeLabel = '',
  }) {
    return LocationPickerState(
      providerLabel: providerLabel,
      initialCenter: center,
      currentCenter: center,
      zoom: zoom,
      query: '',
      nearbyCandidates: const <LocationCandidate>[],
      searchCandidates: const <LocationCandidate>[],
      selectedCandidate: null,
      reverseGeocodeLabel: reverseGeocodeLabel,
      loading: true,
      searching: false,
      confirming: false,
      mapReady: false,
      errorMessage: null,
    );
  }

  final String providerLabel;
  final CanonicalCoordinate initialCenter;
  final CanonicalCoordinate currentCenter;
  final double zoom;
  final String query;
  final List<LocationCandidate> nearbyCandidates;
  final List<LocationCandidate> searchCandidates;
  final LocationCandidate? selectedCandidate;
  final String reverseGeocodeLabel;
  final bool loading;
  final bool searching;
  final bool confirming;
  final bool mapReady;
  final String? errorMessage;

  LocationPickerState copyWith({
    CanonicalCoordinate? currentCenter,
    double? zoom,
    String? query,
    List<LocationCandidate>? nearbyCandidates,
    List<LocationCandidate>? searchCandidates,
    LocationCandidate? selectedCandidate,
    bool clearSelectedCandidate = false,
    String? reverseGeocodeLabel,
    bool? loading,
    bool? searching,
    bool? confirming,
    bool? mapReady,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return LocationPickerState(
      providerLabel: providerLabel,
      initialCenter: initialCenter,
      currentCenter: currentCenter ?? this.currentCenter,
      zoom: zoom ?? this.zoom,
      query: query ?? this.query,
      nearbyCandidates: nearbyCandidates ?? this.nearbyCandidates,
      searchCandidates: searchCandidates ?? this.searchCandidates,
      selectedCandidate: clearSelectedCandidate
          ? null
          : (selectedCandidate ?? this.selectedCandidate),
      reverseGeocodeLabel: reverseGeocodeLabel ?? this.reverseGeocodeLabel,
      loading: loading ?? this.loading,
      searching: searching ?? this.searching,
      confirming: confirming ?? this.confirming,
      mapReady: mapReady ?? this.mapReady,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

class LocationPickerController extends ChangeNotifier {
  LocationPickerController({
    required this.bundle,
    required this.settings,
    required CanonicalCoordinate initialCenter,
    double initialZoom = 16,
    required this.mapHostController,
    MemoLocation? initialLocation,
    this.locateCurrentOnInitialize = false,
    DeviceLocationService? deviceLocationService,
  }) : _state = LocationPickerState.initial(
         providerLabel: bundle.displayName,
         center: initialCenter,
         zoom: initialZoom,
         reverseGeocodeLabel: initialLocation?.placeholder.trim() ?? '',
       ),
       _deviceLocationService =
           deviceLocationService ?? DeviceLocationService() {
    LocationPickerLogger.info(
      'controller_constructed',
      context: {
        'provider': bundle.provider.name,
        'providerLabel': bundle.displayName,
        'initialLatitude': initialCenter.latitude,
        'initialLongitude': initialCenter.longitude,
        'initialZoom': initialZoom,
        'hasInitialLocation': initialLocation != null,
      },
    );
    _mapEventsSubscription = mapHostController.events.listen(_handleMapEvent);
  }

  final LocationProviderBundle bundle;
  final LocationSettings settings;
  final EmbeddedMapHostBridgeController mapHostController;
  final bool locateCurrentOnInitialize;
  final DeviceLocationService _deviceLocationService;
  late final StreamSubscription<EmbeddedMapEvent> _mapEventsSubscription;
  LocationPickerState _state;
  Timer? _searchDebounce;
  Timer? _centerDebounce;
  int _searchRequestId = 0;
  int _refreshRequestId = 0;
  bool _preserveSelectionOnNextCameraIdle = false;
  bool _disposed = false;

  LocationPickerState get state => _state;

  List<LocationCandidate> get visibleCandidates {
    if (_state.query.trim().isNotEmpty) return _state.searchCandidates;
    final currentLabel = _state.reverseGeocodeLabel.trim();
    final manualCandidate = LocationCandidate(
      title: currentLabel.isNotEmpty
          ? currentLabel
          : formatCoordinate(_state.currentCenter),
      subtitle: currentLabel.isNotEmpty
          ? formatCoordinate(_state.currentCenter)
          : '',
      coordinate: _state.currentCenter,
      source: currentLabel.isNotEmpty
          ? LocationCandidateSource.reverseGeocodeFallback
          : LocationCandidateSource.manualCenter,
    );
    return <LocationCandidate>[manualCandidate, ..._state.nearbyCandidates];
  }

  Future<void> initialize() async {
    LocationPickerLogger.info(
      'initialize_start',
      context: {
        'provider': bundle.provider.name,
        'initialLatitude': _state.initialCenter.latitude,
        'initialLongitude': _state.initialCenter.longitude,
        'zoom': _state.zoom,
      },
    );
    await mapHostController.initialize(
      center: _state.initialCenter,
      zoom: _state.zoom,
    );
    LocationPickerLogger.info('map_host_initialize_completed');
    if (_disposed) return;
    if (locateCurrentOnInitialize) {
      await _locateInitialCenter();
      return;
    }
    await _refreshCurrentCenter(showLoading: true);
  }

  Future<void> _locateInitialCenter() async {
    const resolvedZoom = 16.0;
    _state = _state.copyWith(loading: true, clearErrorMessage: true);
    _notifyIfActive();
    try {
      LocationPickerLogger.info('initial_gps_lookup_start');
      final position = await _deviceLocationService.getCurrentPosition();
      if (_disposed) return;
      final coordinate = CanonicalCoordinate(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      LocationPickerLogger.info(
        'initial_gps_lookup_success',
        context: {
          'latitude': coordinate.latitude,
          'longitude': coordinate.longitude,
          'zoom': resolvedZoom,
        },
      );
      _state = _state.copyWith(
        currentCenter: coordinate,
        zoom: resolvedZoom,
        clearSelectedCandidate: true,
        clearErrorMessage: true,
      );
      _notifyIfActive();
      await mapHostController.moveTo(coordinate, zoom: resolvedZoom);
    } catch (error) {
      if (_disposed) return;
      LocationPickerLogger.warn(
        'initial_gps_lookup_failed_using_current_center',
        context: {'error': error.toString()},
      );
    }
    if (_disposed) return;
    await _refreshCurrentCenter(showLoading: true);
  }

  void onQueryChanged(String value) {
    _state = _state.copyWith(query: value, clearErrorMessage: true);
    _notifyIfActive();
    _searchDebounce?.cancel();
    final trimmed = value.trim();
    LocationPickerLogger.debug(
      'query_changed',
      context: {'query': trimmed, 'isEmpty': trimmed.isEmpty},
    );
    if (trimmed.isEmpty) {
      _state = _state.copyWith(
        searching: false,
        searchCandidates: const <LocationCandidate>[],
      );
      _notifyIfActive();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_performSearch(trimmed));
    });
  }

  Future<void> selectCandidate(LocationCandidate candidate) async {
    LocationPickerLogger.info(
      'candidate_selected',
      context: {
        'title': candidate.title,
        'subtitle': candidate.subtitle,
        'source': candidate.source.name,
        'latitude': candidate.coordinate.latitude,
        'longitude': candidate.coordinate.longitude,
        'distanceMeters': candidate.distanceMeters,
      },
    );
    _state = _state.copyWith(
      selectedCandidate: candidate,
      currentCenter: candidate.coordinate,
      clearErrorMessage: true,
    );
    _preserveSelectionOnNextCameraIdle = true;
    _notifyIfActive();
    await mapHostController.moveTo(candidate.coordinate, zoom: _state.zoom);
  }

  Future<MemoLocation> confirmSelection() async {
    _state = _state.copyWith(confirming: true, clearErrorMessage: true);
    _notifyIfActive();
    final selectedCandidate = _state.selectedCandidate;
    final coordinate = selectedCandidate?.coordinate ?? _state.currentCenter;
    final placeholder = selectedCandidate?.title.trim().isNotEmpty == true
        ? selectedCandidate!.title.trim()
        : _state.reverseGeocodeLabel.trim();
    final memoLocation = MemoLocation(
      placeholder: placeholder,
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
    );
    LocationPickerLogger.info(
      'confirm_selection',
      context: {
        'usedSelectedCandidate': selectedCandidate != null,
        'placeholder': memoLocation.placeholder,
        'latitude': memoLocation.latitude,
        'longitude': memoLocation.longitude,
      },
    );
    _state = _state.copyWith(confirming: false);
    _notifyIfActive();
    return memoLocation;
  }

  String formatCoordinate(CanonicalCoordinate coordinate) {
    return '${coordinate.latitude.toStringAsFixed(6)}, ${coordinate.longitude.toStringAsFixed(6)}';
  }

  bool isSelected(LocationCandidate candidate) {
    final selectedCandidate = _state.selectedCandidate;
    if (selectedCandidate == null) return false;
    return selectedCandidate.title == candidate.title &&
        selectedCandidate.coordinate == candidate.coordinate;
  }

  void _handleMapEvent(EmbeddedMapEvent event) {
    LocationPickerLogger.info(
      'map_event',
      context: {
        'type': event.type.name,
        'latitude': event.coordinate?.latitude,
        'longitude': event.coordinate?.longitude,
        'zoom': event.zoom,
        'message': event.message,
      },
    );
    switch (event.type) {
      case EmbeddedMapEventType.ready:
        _state = _state.copyWith(mapReady: true, clearErrorMessage: true);
        _notifyIfActive();
        break;
      case EmbeddedMapEventType.error:
        final errorMessage = (event.message ?? '').trim();
        LocationPickerLogger.warn(
          'map_event_error',
          context: {
            'message': errorMessage.isNotEmpty
                ? errorMessage
                : 'map_initialize_failed',
          },
        );
        _state = _state.copyWith(
          loading: false,
          searching: false,
          confirming: false,
          errorMessage: errorMessage.isNotEmpty
              ? errorMessage
              : 'map_initialize_failed',
        );
        _notifyIfActive();
        break;
      case EmbeddedMapEventType.tap:
        final coordinate = event.coordinate;
        if (coordinate == null) return;
        _state = _state.copyWith(
          currentCenter: coordinate,
          zoom: event.zoom ?? _state.zoom,
        );
        _notifyIfActive();
        unawaited(
          mapHostController.moveTo(coordinate, zoom: event.zoom ?? _state.zoom),
        );
        break;
      case EmbeddedMapEventType.cameraIdle:
        final coordinate = event.coordinate;
        if (coordinate == null) return;
        final preserveSelection =
            _preserveSelectionOnNextCameraIdle || _hasStickyExplicitSelection();
        final skipRefresh = _preserveSelectionOnNextCameraIdle;
        _preserveSelectionOnNextCameraIdle = false;
        _state = _state.copyWith(
          currentCenter: coordinate,
          zoom: event.zoom ?? _state.zoom,
          clearSelectedCandidate: !preserveSelection,
          clearErrorMessage: true,
        );
        _notifyIfActive();
        if (skipRefresh) {
          break;
        }
        _centerDebounce?.cancel();
        _centerDebounce = Timer(const Duration(milliseconds: 250), () {
          if (_disposed) return;
          if (_state.query.trim().isEmpty) {
            unawaited(_refreshCurrentCenter());
          } else {
            unawaited(_performSearch(_state.query.trim()));
          }
        });
        break;
    }
  }

  bool _hasStickyExplicitSelection() {
    final selectedCandidate = _state.selectedCandidate;
    if (selectedCandidate == null) return false;
    return switch (selectedCandidate.source) {
      LocationCandidateSource.nearby || LocationCandidateSource.keyword => true,
      LocationCandidateSource.reverseGeocodeFallback ||
      LocationCandidateSource.manualCenter => false,
    };
  }

  Future<void> _refreshCurrentCenter({bool showLoading = false}) async {
    final requestId = ++_refreshRequestId;
    LocationPickerLogger.info(
      'refresh_center_start',
      context: {
        'requestId': requestId,
        'showLoading': showLoading,
        'latitude': _state.currentCenter.latitude,
        'longitude': _state.currentCenter.longitude,
        'query': _state.query,
      },
    );
    _state = _state.copyWith(loading: showLoading, clearErrorMessage: true);
    _notifyIfActive();
    try {
      final results = await Future.wait<Object?>([
        bundle.adapter.reverseGeocode(
          coordinate: _state.currentCenter,
          settings: settings,
        ),
        bundle.adapter.searchNearby(
          coordinate: _state.currentCenter,
          settings: settings,
        ),
      ]);
      if (_disposed || requestId != _refreshRequestId) return;
      _state = _state.copyWith(
        loading: false,
        reverseGeocodeLabel: (results[0] as String?)?.trim() ?? '',
        nearbyCandidates:
            (results[1] as List<LocationCandidate>?) ??
            const <LocationCandidate>[],
        clearErrorMessage: true,
      );
      LocationPickerLogger.info(
        'refresh_center_success',
        context: {
          'requestId': requestId,
          'reverseGeocodeLabel': _state.reverseGeocodeLabel,
          'nearbyCount': _state.nearbyCandidates.length,
        },
      );
      _notifyIfActive();
    } catch (error) {
      if (_disposed || requestId != _refreshRequestId) return;
      LocationPickerLogger.warn(
        'refresh_center_failed',
        context: {'requestId': requestId, 'error': error.toString()},
      );
      _state = _state.copyWith(loading: false, errorMessage: error.toString());
      _notifyIfActive();
    }
  }

  Future<void> _performSearch(String query) async {
    final requestId = ++_searchRequestId;
    LocationPickerLogger.info(
      'search_start',
      context: {
        'requestId': requestId,
        'query': query,
        'latitude': _state.currentCenter.latitude,
        'longitude': _state.currentCenter.longitude,
      },
    );
    _state = _state.copyWith(searching: true, clearErrorMessage: true);
    _notifyIfActive();
    try {
      final results = await bundle.adapter.searchByKeyword(
        query: query,
        coordinate: _state.currentCenter,
        settings: settings,
      );
      if (_disposed || requestId != _searchRequestId) return;
      _state = _state.copyWith(
        searching: false,
        searchCandidates: results,
        clearErrorMessage: true,
      );
      LocationPickerLogger.info(
        'search_success',
        context: {
          'requestId': requestId,
          'query': query,
          'resultCount': results.length,
        },
      );
      _notifyIfActive();
    } catch (error) {
      if (_disposed || requestId != _searchRequestId) return;
      LocationPickerLogger.warn(
        'search_failed',
        context: {
          'requestId': requestId,
          'query': query,
          'error': error.toString(),
        },
      );
      _state = _state.copyWith(
        searching: false,
        errorMessage: error.toString(),
      );
      _notifyIfActive();
    }
  }

  void _notifyIfActive() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    LocationPickerLogger.info('controller_disposed');
    _disposed = true;
    _searchDebounce?.cancel();
    _centerDebounce?.cancel();
    unawaited(_mapEventsSubscription.cancel());
    unawaited(mapHostController.dispose());
    super.dispose();
  }
}
