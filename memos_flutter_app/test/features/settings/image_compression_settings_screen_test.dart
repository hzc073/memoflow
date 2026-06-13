import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/image_compression_settings.dart';
import 'package:memos_flutter_app/data/repositories/image_compression_settings_repository.dart';
import 'package:memos_flutter_app/features/settings/image_compression_settings_screen.dart';
import 'package:memos_flutter_app/features/settings/settings_ui.dart';
import 'package:memos_flutter_app/state/settings/image_compression_settings_provider.dart';

import 'settings_test_harness.dart';

void main() {
  testWidgets('image compression settings keeps core controls on seams', (
    tester,
  ) async {
    late _FakeImageCompressionSettingsController controller;
    final initial = ImageCompressionSettings.defaults.copyWith(
      lossless: true,
      outputFormat: ImageCompressionOutputFormat.jpeg,
      resize: ImageCompressionSettings.defaults.resize.copyWith(
        enabled: true,
        mode: ImageCompressionResizeMode.longEdge,
      ),
    );

    await tester.pumpWidget(
      buildSettingsTestApp(
        home: const ImageCompressionSettingsScreen(),
        overrides: [
          imageCompressionSettingsProvider.overrideWith((ref) {
            controller = _FakeImageCompressionSettingsController(ref, initial);
            return controller;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsToggleCard), findsOneWidget);
    expect(find.byType(SettingsMenuRow<ImageCompressionMode>), findsOneWidget);
    expect(
      find.byType(SettingsMenuRow<ImageCompressionOutputFormat>),
      findsOneWidget,
    );
    expect(find.text('Image Compression'), findsWidgets);
    expect(
      find.text(
        'Converting to a new format or resizing can degrade quality even when lossless is enabled.',
      ),
      findsOneWidget,
    );
    expect(find.text('80Percentage'), findsNothing);
    expect(find.text('80%'), findsWidgets);

    final enableRow = tester.widget<SettingsToggleRow>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SettingsToggleRow &&
            widget.label == 'Enable image compression',
      ),
    );
    enableRow.onChanged?.call(false);
    await tester.pump();

    expect(controller.state.enabled, isFalse);

    final modeMenu = tester.widget<SettingsMenuRow<ImageCompressionMode>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SettingsMenuRow<ImageCompressionMode> &&
            widget.label == 'Compression mode',
      ),
    );
    modeMenu.onChanged(ImageCompressionMode.size);
    await tester.pump();

    expect(controller.state.mode, ImageCompressionMode.size);

    final outputMenu = tester
        .widget<SettingsMenuRow<ImageCompressionOutputFormat>>(
          find.byWidgetPredicate(
            (widget) =>
                widget is SettingsMenuRow<ImageCompressionOutputFormat> &&
                widget.label == 'Output format',
          ),
        );
    outputMenu.onChanged(ImageCompressionOutputFormat.webp);
    await tester.pump();

    expect(controller.state.outputFormat, ImageCompressionOutputFormat.webp);

    final edge = controller.state.resize.edge;
    final edgeStepper = tester.widget<SettingsStepperRow>(
      find.byWidgetPredicate(
        (widget) => widget is SettingsStepperRow && widget.label == 'Edge',
      ),
    );
    edgeStepper.onIncrease();
    await tester.pump();

    expect(controller.state.resize.edge, edge + 160);

    final resizeRow = tester.widget<SettingsToggleRow>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SettingsToggleRow && widget.label == 'Enable resize',
      ),
    );
    resizeRow.onChanged?.call(false);
    await tester.pump();

    expect(controller.state.resize.enabled, isFalse);
  });
}

class _FakeImageCompressionSettingsController
    extends ImageCompressionSettingsController {
  _FakeImageCompressionSettingsController(
    Ref ref,
    ImageCompressionSettings initial,
  ) : super(ref, _FakeImageCompressionSettingsRepository(initial)) {
    state = initial;
  }

  @override
  void setEnabled(bool value) => state = state.copyWith(enabled: value);

  @override
  void setMode(ImageCompressionMode value) {
    state = state.copyWith(mode: value);
  }

  @override
  void setOutputFormat(ImageCompressionOutputFormat value) {
    state = state.copyWith(outputFormat: value);
  }

  @override
  void setLossless(bool value) => state = state.copyWith(lossless: value);

  @override
  void setResizeEnabled(bool value) {
    state = state.copyWith(resize: state.resize.copyWith(enabled: value));
  }

  @override
  void setResizeEdge(int value) {
    state = state.copyWith(resize: state.resize.copyWith(edge: value));
  }
}

class _FakeImageCompressionSettingsRepository
    implements ImageCompressionSettingsRepository {
  _FakeImageCompressionSettingsRepository(this._settings);

  ImageCompressionSettings _settings;

  @override
  String get accountKey => 'test';

  @override
  Future<ImageCompressionSettings> read() async => _settings;

  @override
  Future<void> write(ImageCompressionSettings settings) async {
    _settings = settings;
  }

  @override
  Future<void> clear() async {
    _settings = ImageCompressionSettings.defaults;
  }
}
