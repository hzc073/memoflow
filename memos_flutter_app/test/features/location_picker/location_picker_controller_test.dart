import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/location/location_provider_adapter.dart';
import 'package:memos_flutter_app/data/location/location_provider_bundle.dart';
import 'package:memos_flutter_app/data/location/models/canonical_coordinate.dart';
import 'package:memos_flutter_app/data/location/models/location_candidate.dart';
import 'package:memos_flutter_app/data/models/location_settings.dart';
import 'package:memos_flutter_app/data/models/memo_location.dart';
import 'package:memos_flutter_app/features/location_picker/embedded_map_host.dart';
import 'package:memos_flutter_app/features/location_picker/location_picker_controller.dart';

void main() {
  const settings = LocationSettings(
    enabled: true,
    provider: LocationServiceProvider.google,
    amapWebKey: '',
    amapSecurityKey: '',
    baiduWebKey: '',
    googleApiKey: 'google-key',
    precision: LocationPrecision.city,
  );
  const initialCenter = CanonicalCoordinate(
    latitude: 30.592849,
    longitude: 114.305539,
  );

  group('LocationPickerController', () {
    late _FakeLocationProviderAdapter adapter;
    late EmbeddedMapHostBridgeController mapHostController;
    late LocationPickerController controller;

    setUp(() {
      adapter = _FakeLocationProviderAdapter(
        reverseGeocodeResult: 'Wuhan Tower',
        nearbyResults: const <LocationCandidate>[
          LocationCandidate(
            title: 'Yellow Crane Tower',
            subtitle: 'Wuchang, Wuhan',
            coordinate: CanonicalCoordinate(
              latitude: 30.544919,
              longitude: 114.306255,
            ),
            source: LocationCandidateSource.nearby,
          ),
        ],
      );
      mapHostController = EmbeddedMapHostBridgeController();
      controller = LocationPickerController(
        bundle: LocationProviderBundle(
          provider: LocationServiceProvider.google,
          adapter: adapter,
          displayName: 'Fake Maps',
          apiKey: 'google-key',
        ),
        settings: settings,
        initialCenter: initialCenter,
        mapHostController: mapHostController,
        initialLocation: MemoLocation(
          placeholder: 'Existing Place',
          latitude: initialCenter.latitude,
          longitude: initialCenter.longitude,
        ),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('initializes with reverse geocode and nearby candidates', () async {
      await controller.initialize();

      expect(controller.state.initialCenter, initialCenter);
      expect(controller.state.currentCenter, initialCenter);
      expect(controller.state.reverseGeocodeLabel, 'Wuhan Tower');
      expect(controller.visibleCandidates.first.title, 'Wuhan Tower');
      expect(controller.visibleCandidates[1].title, 'Yellow Crane Tower');
      expect(adapter.reverseRequests, [initialCenter]);
      expect(adapter.nearbyRequests, [initialCenter]);
    });

    test('applies only the latest debounced search result', () async {
      await controller.initialize();

      controller.onQueryChanged('first');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      controller.onQueryChanged('second');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      adapter.completeSearch('first', const <LocationCandidate>[
        LocationCandidate(
          title: 'First Result',
          coordinate: CanonicalCoordinate(latitude: 1, longitude: 1),
          source: LocationCandidateSource.keyword,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.searchCandidates, isEmpty);

      adapter.completeSearch('second', const <LocationCandidate>[
        LocationCandidate(
          title: 'Second Result',
          coordinate: CanonicalCoordinate(latitude: 2, longitude: 2),
          source: LocationCandidateSource.keyword,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(adapter.searchQueries, ['first', 'second']);
      expect(controller.state.searchCandidates, hasLength(1));
      expect(controller.state.searchCandidates.single.title, 'Second Result');
    });

    test('camera idle keeps explicit poi selection and refreshes center data', () async {
      await controller.initialize();
      await controller.selectCandidate(controller.visibleCandidates[1]);
      expect(controller.state.selectedCandidate?.title, 'Yellow Crane Tower');

      mapHostController.emit(
        const EmbeddedMapEvent(
          type: EmbeddedMapEventType.cameraIdle,
          coordinate: CanonicalCoordinate(
            latitude: 30.544919,
            longitude: 114.306255,
          ),
          zoom: 16,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));

      const updatedCenter = CanonicalCoordinate(
        latitude: 30.5931,
        longitude: 114.3059,
      );
      adapter.reverseGeocodeResult = 'Updated Address';
      adapter.nearbyResults = const <LocationCandidate>[
        LocationCandidate(
          title: 'Updated Nearby',
          coordinate: updatedCenter,
          source: LocationCandidateSource.nearby,
        ),
      ];

      mapHostController.emit(
        const EmbeddedMapEvent(
          type: EmbeddedMapEventType.cameraIdle,
          coordinate: updatedCenter,
          zoom: 17,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(controller.state.selectedCandidate?.title, 'Yellow Crane Tower');
      expect(controller.state.currentCenter, updatedCenter);
      expect(controller.state.reverseGeocodeLabel, 'Updated Address');
      expect(adapter.nearbyRequests.last, updatedCenter);

      final result = await controller.confirmSelection();
      expect(result.placeholder, 'Yellow Crane Tower');
      expect(result.latitude, 30.544919);
      expect(result.longitude, 114.306255);
    });

    test(
      'programmatic camera idle keeps selected real candidate',
      () async {
        await controller.initialize();
        final picked = controller.visibleCandidates[1];

        await controller.selectCandidate(picked);
        expect(controller.state.selectedCandidate?.title, 'Yellow Crane Tower');
        expect(controller.state.reverseGeocodeLabel, 'Wuhan Tower');

        adapter.reverseGeocodeResult = 'Wuhan City?Wuchang District';
        mapHostController.emit(
          const EmbeddedMapEvent(
            type: EmbeddedMapEventType.cameraIdle,
            coordinate: CanonicalCoordinate(
              latitude: 30.544931,
              longitude: 114.306247,
            ),
            zoom: 16,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(controller.state.selectedCandidate?.title, 'Yellow Crane Tower');
        expect(controller.state.reverseGeocodeLabel, 'Wuhan Tower');
        expect(adapter.nearbyRequests, [initialCenter]);

        final result = await controller.confirmSelection();
        expect(result.placeholder, 'Yellow Crane Tower');
        expect(result.latitude, 30.544919);
        expect(result.longitude, 114.306255);
      },
    );

    test('programmatic move keeps nearby list order stable after selection', () async {
      adapter.nearbyResults = const <LocationCandidate>[
        LocationCandidate(
          title: 'First Nearby',
          coordinate: CanonicalCoordinate(latitude: 30.5441, longitude: 114.3061),
          source: LocationCandidateSource.nearby,
        ),
        LocationCandidate(
          title: 'Second Nearby',
          coordinate: CanonicalCoordinate(latitude: 30.5442, longitude: 114.3062),
          source: LocationCandidateSource.nearby,
        ),
        LocationCandidate(
          title: 'Third Nearby',
          coordinate: CanonicalCoordinate(latitude: 30.5443, longitude: 114.3063),
          source: LocationCandidateSource.nearby,
        ),
        LocationCandidate(
          title: 'Fourth Nearby',
          coordinate: CanonicalCoordinate(latitude: 30.5444, longitude: 114.3064),
          source: LocationCandidateSource.nearby,
        ),
      ];

      await controller.initialize();
      final beforeTitles = controller.visibleCandidates
          .map((candidate) => candidate.title)
          .toList(growable: false);
      final picked = controller.visibleCandidates[4];

      await controller.selectCandidate(picked);
      mapHostController.emit(
        const EmbeddedMapEvent(
          type: EmbeddedMapEventType.cameraIdle,
          coordinate: CanonicalCoordinate(
            latitude: 30.54441,
            longitude: 114.30639,
          ),
          zoom: 16,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final afterTitles = controller.visibleCandidates
          .map((candidate) => candidate.title)
          .toList(growable: false);

      expect(beforeTitles, afterTitles);
      expect(controller.state.selectedCandidate?.title, 'Fourth Nearby');
      expect(adapter.nearbyRequests, [initialCenter]);
    });

    test(
      'confirmSelection prefers selected candidate title and coordinate',
      () async {
        await controller.initialize();

        const picked = LocationCandidate(
          title: 'Picked POI',
          subtitle: 'Picked subtitle',
          coordinate: CanonicalCoordinate(latitude: 31.2, longitude: 121.5),
          source: LocationCandidateSource.keyword,
        );

        await controller.selectCandidate(picked);
        final result = await controller.confirmSelection();

        expect(result.placeholder, 'Picked POI');
        expect(result.latitude, 31.2);
        expect(result.longitude, 121.5);
      },
    );

    test('confirmSelection falls back to reverse geocode label', () async {
      await controller.initialize();

      final result = await controller.confirmSelection();

      expect(result.placeholder, 'Wuhan Tower');
      expect(result.latitude, initialCenter.latitude);
      expect(result.longitude, initialCenter.longitude);
    });
  });
}

class _FakeLocationProviderAdapter implements LocationProviderAdapter {
  _FakeLocationProviderAdapter({
    required this.reverseGeocodeResult,
    required this.nearbyResults,
  });

  String? reverseGeocodeResult;
  List<LocationCandidate> nearbyResults;
  final List<CanonicalCoordinate> reverseRequests = <CanonicalCoordinate>[];
  final List<CanonicalCoordinate> nearbyRequests = <CanonicalCoordinate>[];
  final List<String> searchQueries = <String>[];
  final Map<String, Completer<List<LocationCandidate>>> _searchCompleters =
      <String, Completer<List<LocationCandidate>>>{};

  void completeSearch(String query, List<LocationCandidate> results) {
    final completer = _searchCompleters.putIfAbsent(
      query,
      Completer<List<LocationCandidate>>.new,
    );
    completer.complete(results);
  }

  @override
  CanonicalCoordinate fromProviderCoordinate(ProviderCoordinate coordinate) {
    return CanonicalCoordinate(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
    );
  }

  @override
  Future<String?> reverseGeocode({
    required CanonicalCoordinate coordinate,
    required LocationSettings settings,
  }) async {
    reverseRequests.add(coordinate);
    return reverseGeocodeResult;
  }

  @override
  Future<List<LocationCandidate>> searchByKeyword({
    required String query,
    required CanonicalCoordinate coordinate,
    required LocationSettings settings,
    int radiusMeters = 1000,
    int limit = 10,
  }) {
    searchQueries.add(query);
    return _searchCompleters
        .putIfAbsent(query, Completer<List<LocationCandidate>>.new)
        .future;
  }

  @override
  Future<List<LocationCandidate>> searchNearby({
    required CanonicalCoordinate coordinate,
    required LocationSettings settings,
    int radiusMeters = 1000,
    int limit = 10,
  }) async {
    nearbyRequests.add(coordinate);
    return nearbyResults;
  }

  @override
  ProviderCoordinate toProviderCoordinate(CanonicalCoordinate coordinate) {
    return ProviderCoordinate(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
      system: ProviderCoordinateSystem.wgs84,
    );
  }
}
