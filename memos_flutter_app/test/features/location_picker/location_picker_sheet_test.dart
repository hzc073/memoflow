import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/location/location_provider_adapter.dart';
import 'package:memos_flutter_app/data/location/location_provider_bundle.dart';
import 'package:memos_flutter_app/data/location/models/canonical_coordinate.dart';
import 'package:memos_flutter_app/data/location/models/location_candidate.dart';
import 'package:memos_flutter_app/data/models/location_settings.dart';
import 'package:memos_flutter_app/features/location_picker/embedded_map_host.dart';
import 'package:memos_flutter_app/features/location_picker/location_picker_controller.dart';
import 'package:memos_flutter_app/features/location_picker/location_picker_dialog.dart';
import 'package:memos_flutter_app/features/location_picker/location_picker_sheet.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';

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
  const center = CanonicalCoordinate(
    latitude: 30.592849,
    longitude: 114.305539,
  );

  late _ImmediateLocationProviderAdapter adapter;
  late EmbeddedMapHostBridgeController mapHostController;
  late LocationPickerController controller;
  late LocationProviderBundle bundle;

  setUp(() async {
    adapter = _ImmediateLocationProviderAdapter();
    mapHostController = EmbeddedMapHostBridgeController();
    bundle = LocationProviderBundle(
      provider: LocationServiceProvider.google,
      adapter: adapter,
      displayName: 'Fake Maps',
      apiKey: 'google-key',
    );
    controller = LocationPickerController(
      bundle: bundle,
      settings: settings,
      initialCenter: center,
      mapHostController: mapHostController,
    );
    await controller.initialize();
  });

  tearDown(() {
    controller.dispose();
  });

  Widget buildTestApp(Widget child, {AppLocale locale = AppLocale.en}) {
    LocaleSettings.setLocale(locale);
    return TranslationProvider(
      child: MaterialApp(
        locale: locale.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('sheet renders key layout and allows selecting a candidate', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        LocationPickerPanel(
          controller: controller,
          mapHostController: mapHostController,
          bundle: bundle,
          mapHostChild: const ColoredBox(
            key: Key('fake-map-host'),
            color: Colors.blueGrey,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('fake-map-host')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Fake Maps'), findsOneWidget);
    expect(find.textContaining('Latitude 30.592849'), findsOneWidget);
    expect(find.text('Current Address'), findsOneWidget);
    expect(find.text('Yellow Crane Tower'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);

    await tester.tap(find.text('Yellow Crane Tower'));
    await tester.pump();

    expect(controller.state.selectedCandidate?.title, 'Yellow Crane Tower');
  });

  testWidgets('sheet chrome follows zh-Hans locale', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        LocationPickerPanel(
          controller: controller,
          mapHostController: mapHostController,
          bundle: bundle,
          mapHostChild: const ColoredBox(
            key: Key('zh-fake-map-host'),
            color: Colors.blueGrey,
          ),
        ),
        locale: AppLocale.zhHans,
      ),
    );
    await tester.pump();

    expect(find.text('搜索附近地点'), findsOneWidget);
    expect(find.textContaining('纬度 30.592849'), findsOneWidget);
    expect(find.textContaining('经度 114.305539'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('确认'), findsOneWidget);
  });

  testWidgets('dialog renders with injected fake map host', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        LocationPickerDialog(
          controller: controller,
          mapHostController: mapHostController,
          bundle: bundle,
          mapHostChild: const SizedBox(key: Key('dialog-fake-map')),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byKey(const Key('dialog-fake-map')), findsOneWidget);
    expect(find.text('Fake Maps'), findsOneWidget);
  });
}

class _ImmediateLocationProviderAdapter implements LocationProviderAdapter {
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
    return 'Current Address';
  }

  @override
  Future<List<LocationCandidate>> searchByKeyword({
    required String query,
    required CanonicalCoordinate coordinate,
    required LocationSettings settings,
    int radiusMeters = 1000,
    int limit = 10,
  }) async {
    return const <LocationCandidate>[];
  }

  @override
  Future<List<LocationCandidate>> searchNearby({
    required CanonicalCoordinate coordinate,
    required LocationSettings settings,
    int radiusMeters = 1000,
    int limit = 10,
  }) async {
    return const <LocationCandidate>[
      LocationCandidate(
        title: 'Yellow Crane Tower',
        subtitle: 'Wuhan',
        coordinate: CanonicalCoordinate(
          latitude: 30.544919,
          longitude: 114.306255,
        ),
        source: LocationCandidateSource.nearby,
      ),
    ];
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
