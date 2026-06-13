import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/access_boundary/access_boundary.dart';
import 'package:memos_flutter_app/access_boundary/access_decision.dart';
import 'package:memos_flutter_app/access_boundary/app_capability.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/data/models/device_preferences.dart';
import 'package:memos_flutter_app/features/settings/settings_ui.dart';
import 'package:memos_flutter_app/features/settings/support_memoflow_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/module_boundary/settings_entry_contribution.dart';
import 'package:memos_flutter_app/module_boundary/support_memo_flow_contribution.dart';
import 'package:memos_flutter_app/platform/platform_target.dart';
import 'package:memos_flutter_app/private_hooks/private_extension_bundle.dart';
import 'package:memos_flutter_app/private_hooks/private_extension_bundle_provider.dart';
import 'package:memos_flutter_app/state/settings/device_preferences_provider.dart';
import 'package:memos_flutter_app/state/settings/preferences_migration_service.dart';
import 'package:memos_flutter_app/core/storage_read.dart';

void main() {
  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
    debugPlatformTargetOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugPlatformTargetOverride = null;
  });

  testWidgets('mobile public support page opens appreciation link without QR', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(SupportMemoFlowScreen), findsOneWidget);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Support MemoFlow'), findsWidgets);
    expect(find.text('Why support'), findsOneWidget);
    expect(find.text('Public-good note'), findsOneWidget);
    expect(find.text('Support the developer'), findsOneWidget);
    expect(find.text('View foundation website'), findsOneWidget);
    expect(find.text('View public-good records'), findsOneWidget);
    expect(find.text('Open support link'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('supportMemoFlow.supportQr')),
      findsNothing,
    );
    expect(supportMemoFlowExternalSupportUrl, contains('qr.alipay.com'));
    expect(supportMemoFlowCharityUrl, contains('hhax.org'));
  });

  testWidgets('desktop public support page shows QR instead of link action', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.windows;

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(SupportMemoFlowScreen), findsOneWidget);
    expect(find.text('Support the developer'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('supportMemoFlow.publicAppreciationSection'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('supportMemoFlow.supportQr')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('supportMemoFlow.openSupportLink')),
      findsNothing,
    );
    expect(find.text('Open support link'), findsNothing);
    expect(
      find.text('Scan with Alipay on your phone to support MemoFlow.'),
      findsOneWidget,
    );
    expect(find.text('View foundation website'), findsOneWidget);
  });

  testWidgets('private support contribution replaces public fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        bundle: _SupportContributionBundle(
          contribution: const SupportMemoFlowContribution(
            id: 'private-support',
            order: 100,
            builder: _buildPrivateSupportProbe,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('privateSupportProbe')), findsOne);
    expect(find.text('Private Apple support contribution'), findsOneWidget);
    expect(find.text('Support the developer'), findsNothing);
    expect(find.text('Open support link'), findsNothing);
    expect(find.text('Why support'), findsNothing);
  });
}

Widget _buildApp({PrivateExtensionBundle? bundle}) {
  return ProviderScope(
    overrides: [
      devicePreferencesProvider.overrideWith(
        (ref) => _TestDevicePreferencesController(ref),
      ),
      if (bundle != null)
        privateExtensionBundleProvider.overrideWithValue(bundle),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        locale: AppLocale.en.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const SupportMemoFlowScreen(),
      ),
    ),
  );
}

Widget _buildPrivateSupportProbe(BuildContext context) {
  return const SettingsSection(
    key: ValueKey<String>('privateSupportProbe'),
    children: [
      SettingsInfoRow(description: 'Private Apple support contribution'),
    ],
  );
}

class _SupportContributionBundle
    implements PrivateExtensionBundle, SupportMemoFlowExtension {
  const _SupportContributionBundle({required this.contribution});

  final SupportMemoFlowContribution contribution;

  @override
  AccessBoundary get diagnosticsAccessBoundary =>
      const _DisabledAccessBoundary();

  @override
  Future<void> onAppReady(WidgetRef ref) async {}

  @override
  List<SettingsEntryContribution> settingsEntries(
    BuildContext context,
    WidgetRef ref,
  ) {
    return const <SettingsEntryContribution>[];
  }

  @override
  List<SupportMemoFlowContribution> supportMemoFlowContributions(
    BuildContext context,
    WidgetRef ref,
  ) {
    return <SupportMemoFlowContribution>[contribution];
  }
}

class _DisabledAccessBoundary implements AccessBoundary {
  const _DisabledAccessBoundary();

  @override
  AccessDecision decisionFor(AppCapability capability) {
    return const AccessDecision.disabled('test');
  }
}

class _TestDevicePreferencesController extends DevicePreferencesController {
  _TestDevicePreferencesController(Ref ref)
    : super(ref, _TestDevicePreferencesRepository());
}

class _TestDevicePreferencesRepository extends DevicePreferencesRepository {
  _TestDevicePreferencesRepository()
    : _prefs = DevicePreferences.defaultsForLanguage(
        AppLanguage.en,
      ).copyWith(hapticsEnabled: false),
      super(PreferencesMigrationService(const FlutterSecureStorage()));

  DevicePreferences _prefs;

  @override
  Future<StorageReadResult<DevicePreferences>> readWithStatus() async {
    return StorageReadResult.success(_prefs);
  }

  @override
  Future<DevicePreferences> read() async {
    return _prefs;
  }

  @override
  Future<void> write(DevicePreferences prefs) async {
    _prefs = prefs;
  }
}
