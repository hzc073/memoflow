import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/image_bed_url.dart';
import 'package:memos_flutter_app/data/models/image_bed_settings.dart';
import 'package:memos_flutter_app/data/repositories/image_bed_settings_repository.dart';
import 'package:memos_flutter_app/features/settings/image_bed_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/settings_ui.dart';
import 'package:memos_flutter_app/platform/widgets/platform_controls.dart';
import 'package:memos_flutter_app/state/settings/image_bed_settings_provider.dart';

import 'settings_test_harness.dart';

void main() {
  testWidgets('image bed settings uses seams and keeps key interactions', (
    tester,
  ) async {
    late _FakeImageBedSettingsController controller;

    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const ImageBedSettingsScreen(),
        overrides: [
          imageBedSettingsProvider.overrideWith((ref) {
            controller = _FakeImageBedSettingsController(
              ref,
              ImageBedSettings.defaults,
            );
            return controller;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsToggleCard), findsOneWidget);
    expect(find.byType(SettingsFormFieldRow), findsNWidgets(2));
    expect(find.byType(SettingsInlineTextFieldRow), findsNWidgets(2));
    expect(find.byType(SettingsNumericInlineFieldRow), findsOneWidget);
    expect(find.byType(SettingsStepperRow), findsOneWidget);
    expect(find.text('Image Bed'), findsWidgets);

    final enableSwitch = tester.widget<PlatformSwitch>(
      find.byType(PlatformSwitch).first,
    );
    enableSwitch.onChanged?.call(true);
    await tester.pump();

    expect(controller.state.enabled, isTrue);

    await tester.enterText(
      find.byType(TextField).first,
      'https://example.com/api/v1/',
    );
    await tester.pump();

    expect(controller.state.baseUrl, 'https://example.com');

    await tester.enterText(find.byType(TextField).at(1), ' user@example.com ');
    await tester.pump();

    expect(controller.state.email, 'user@example.com');

    final retryStepper = tester.widget<SettingsStepperRow>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SettingsStepperRow && widget.label == 'Retry Count',
      ),
    );
    retryStepper.onIncrease();
    await tester.pump();

    expect(
      controller.state.retryCount,
      ImageBedSettings.defaults.retryCount + 1,
    );
  });
}

class _FakeImageBedSettingsController extends ImageBedSettingsController {
  _FakeImageBedSettingsController(Ref ref, ImageBedSettings initial)
    : super(ref, _FakeImageBedSettingsRepository(initial)) {
    state = initial;
  }

  @override
  void setEnabled(bool value) => state = state.copyWith(enabled: value);

  @override
  void setProvider(ImageBedProvider provider) {
    state = state.copyWith(provider: provider, authToken: null);
  }

  @override
  void setBaseUrl(String value) {
    final raw = value.trim();
    final parsed = Uri.tryParse(raw);
    final normalized = raw.isEmpty || parsed == null
        ? raw
        : sanitizeImageBedBaseUrl(parsed).toString();
    state = state.copyWith(baseUrl: normalized, authToken: null);
  }

  @override
  void setEmail(String value) {
    state = state.copyWith(email: value.trim(), authToken: null);
  }

  @override
  void setPassword(String value) {
    state = state.copyWith(password: value, authToken: null);
  }

  @override
  void setStrategyId(String? value) {
    final trimmed = (value ?? '').trim();
    state = state.copyWith(
      strategyId: trimmed.isEmpty ? null : trimmed,
      authToken: null,
    );
  }

  @override
  void setRetryCount(int value) => state = state.copyWith(retryCount: value);
}

class _FakeImageBedSettingsRepository implements ImageBedSettingsRepository {
  _FakeImageBedSettingsRepository(this._settings);

  ImageBedSettings _settings;

  @override
  String get accountKey => 'test';

  @override
  Future<ImageBedSettings> read() async => _settings;

  @override
  Future<void> write(ImageBedSettings settings) async {
    _settings = settings;
  }

  @override
  Future<void> clear() async {
    _settings = ImageBedSettings.defaults;
  }
}
