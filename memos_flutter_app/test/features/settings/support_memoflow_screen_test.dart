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
import 'package:memos_flutter_app/features/settings/support_memoflow_policy.dart';
import 'package:memos_flutter_app/features/settings/support_memoflow_screen.dart';
import 'package:memos_flutter_app/i18n/strings.g.dart';
import 'package:memos_flutter_app/module_boundary/settings_entry_contribution.dart';
import 'package:memos_flutter_app/module_boundary/support_memo_flow_contribution.dart';
import 'package:memos_flutter_app/platform/platform_experience.dart';
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

  test('public support policy maps platform CTAs', () {
    final android = SupportMemoFlowPublicPolicy.forExperience(
      platformExperienceForTarget(PlatformTarget.android),
    );
    expect(android.showExternalLinkAction, isTrue);
    expect(android.showDesktopQr, isFalse);
    expect(android.showAppleExplanation, isFalse);

    final web = SupportMemoFlowPublicPolicy.forExperience(
      platformExperienceForTarget(PlatformTarget.web),
    );
    expect(web.showExternalLinkAction, isTrue);
    expect(web.showDesktopQr, isFalse);
    expect(web.showAppleExplanation, isFalse);

    final windows = SupportMemoFlowPublicPolicy.forExperience(
      platformExperienceForTarget(PlatformTarget.windows),
    );
    expect(windows.showExternalLinkAction, isFalse);
    expect(windows.showDesktopQr, isTrue);
    expect(windows.showAppleExplanation, isFalse);

    final linux = SupportMemoFlowPublicPolicy.forExperience(
      platformExperienceForTarget(PlatformTarget.linux),
    );
    expect(linux.showExternalLinkAction, isFalse);
    expect(linux.showDesktopQr, isTrue);
    expect(linux.showAppleExplanation, isFalse);

    final macOS = SupportMemoFlowPublicPolicy.forExperience(
      platformExperienceForTarget(PlatformTarget.macOS),
    );
    expect(macOS.showExternalLinkAction, isFalse);
    expect(macOS.showDesktopQr, isFalse);
    expect(macOS.showAppleExplanation, isTrue);
  });

  testWidgets('mobile public support page opens appreciation link without QR', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(SupportMemoFlowScreen), findsOneWidget);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Support MemoFlow'), findsWidgets);
    expect(find.text('What your support brings'), findsOneWidget);
    expect(find.text('Public-good note'), findsNothing);
    expect(find.text('Thanks for supporting MemoFlow'), findsOneWidget);
    expect(find.text('View foundation website'), findsNothing);
    expect(find.text('View public-good records'), findsNothing);
    expect(find.text('Open support link'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('supportMemoFlow.supportQr')),
      findsNothing,
    );
    expect(supportMemoFlowExternalSupportUrl, contains('qr.alipay.com'));
    expect(supportMemoFlowCharityUrl, contains('hhax.org'));
  });

  testWidgets('iPhone public support page renders without Material errors', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    debugPlatformTargetOverride = TargetPlatform.iOS;

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SupportMemoFlowScreen), findsOneWidget);
    expect(find.text('View foundation website'), findsNothing);
    expect(find.text('View public-good records'), findsNothing);
    expect(find.text('Open support link'), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>('supportMemoFlow.appleSupportExplanation'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('supportMemoFlow.supportQr')),
      findsNothing,
    );
  });

  testWidgets('iPad public support page hides external support action', (
    tester,
  ) async {
    await _setViewport(tester, const Size(834, 1194));
    debugPlatformTargetOverride = TargetPlatform.iOS;

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(SupportMemoFlowScreen), findsOneWidget);
    expect(find.text('Open support link'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('supportMemoFlow.supportQr')),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('supportMemoFlow.appleSupportExplanation'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('macOS public support page hides external support QR', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.macOS;

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(SupportMemoFlowScreen), findsOneWidget);
    expect(find.text('Open support link'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('supportMemoFlow.supportQr')),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('supportMemoFlow.appleSupportExplanation'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('desktop public support page shows QR instead of link action', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.windows;

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(SupportMemoFlowScreen), findsOneWidget);
    expect(find.text('Thanks for supporting MemoFlow'), findsOneWidget);
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
    expect(find.text('View foundation website'), findsNothing);
    expect(find.text('View public-good records'), findsNothing);
  });

  testWidgets('Linux public support page shows QR instead of link action', (
    tester,
  ) async {
    debugPlatformTargetOverride = TargetPlatform.linux;

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(SupportMemoFlowScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('supportMemoFlow.supportQr')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('supportMemoFlow.openSupportLink')),
      findsNothing,
    );
    expect(find.text('Open support link'), findsNothing);
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
    expect(
      find.text('Keep maintenance and platform polish moving forward.'),
      findsOneWidget,
    );
    expect(find.text('Thanks for supporting MemoFlow'), findsNothing);
    expect(find.text('Open support link'), findsNothing);
    expect(find.text('What your support brings'), findsNothing);
  });

  testWidgets(
    'public appreciation page opens without private contribution loop',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          screen: const SupportMemoFlowScreen.publicAppreciation(),
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

      expect(
        find.byKey(const ValueKey<String>('privateSupportProbe')),
        findsNothing,
      );
      expect(find.text('What your support brings'), findsOneWidget);
      expect(find.text('Thanks for supporting MemoFlow'), findsOneWidget);
      expect(find.text('Open support link'), findsOneWidget);
    },
  );
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _buildApp({
  Widget screen = const SupportMemoFlowScreen(),
  PrivateExtensionBundle? bundle,
}) {
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
        home: screen,
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
