import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/collection_reader.dart';

void main() {
  test('serializes and restores saved style cards', () {
    final preferences = CollectionReaderPreferences.defaults.copyWith(
      savedStyleCards: <CollectionReaderStyleCard>[
        CollectionReaderStyleCard(
          id: 'style-1',
          name: 'Warm paper',
          themePreset: CollectionReaderThemePreset.paper,
          backgroundConfig: CollectionReaderBackgroundConfig.defaults.copyWith(
            type: CollectionReaderBackgroundType.solidColor,
            solidColor: const Color(0xFFF8E7CF),
            alpha: 0.92,
          ),
        ),
      ],
    );

    final restored = CollectionReaderPreferences.fromJson(
      preferences.toJson().cast<String, dynamic>(),
    );

    expect(restored.savedStyleCards, hasLength(1));
    final card = restored.savedStyleCards.single;
    expect(card.id, 'style-1');
    expect(card.name, 'Warm paper');
    expect(card.themePreset, CollectionReaderThemePreset.paper);
    expect(
      card.backgroundConfig.type,
      CollectionReaderBackgroundType.solidColor,
    );
    expect(card.backgroundConfig.solidColor, const Color(0xFFF8E7CF));
    expect(card.backgroundConfig.alpha, closeTo(0.92, 0.0001));
  });

  test('defaults saved style cards for legacy json', () {
    final legacyJson = CollectionReaderPreferences.defaults.toJson()
      ..remove('savedStyleCards');

    final restored = CollectionReaderPreferences.fromJson(
      legacyJson.cast<String, dynamic>(),
    );

    expect(restored.savedStyleCards, isEmpty);
  });

  test('serializes and restores reader content width mode', () {
    final preferences = CollectionReaderPreferences.defaults.copyWith(
      displayConfig: CollectionReaderDisplayConfig.defaults.copyWith(
        contentWidthMode: CollectionReaderContentWidthMode.wide,
      ),
    );

    final restored = CollectionReaderPreferences.fromJson(
      preferences.toJson().cast<String, dynamic>(),
    );

    expect(
      restored.displayConfig.contentWidthMode,
      CollectionReaderContentWidthMode.wide,
    );
  });

  test('defaults content width mode for legacy display config json', () {
    final legacyJson = CollectionReaderPreferences.defaults.toJson();
    final displayConfig = legacyJson['displayConfig']! as Map<String, Object?>;
    displayConfig.remove('contentWidthMode');

    final restored = CollectionReaderPreferences.fromJson(
      legacyJson.cast<String, dynamic>(),
    );

    expect(
      restored.displayConfig.contentWidthMode,
      CollectionReaderContentWidthMode.standard,
    );
  });
}
