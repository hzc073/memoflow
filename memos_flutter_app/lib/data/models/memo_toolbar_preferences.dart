import 'package:flutter/foundation.dart';

enum MemoToolbarRow { top, bottom }

enum MemoToolbarActionId {
  bold,
  italic,
  strikethrough,
  inlineCode,
  list,
  orderedList,
  taskList,
  quote,
  heading1,
  heading2,
  heading3,
  underline,
  highlight,
  divider,
  codeBlock,
  inlineMath,
  blockMath,
  table,
  cutParagraph,
  undo,
  redo,
  tag,
  template,
  attachment,
  gallery,
  todo,
  link,
  camera,
  location,
  draftBox,
}

const kMemoToolbarDefaultCustomIconKey = 'hammer';

const kMemoToolbarLegacyBuiltinActions = <MemoToolbarActionId>{
  MemoToolbarActionId.bold,
  MemoToolbarActionId.list,
  MemoToolbarActionId.underline,
  MemoToolbarActionId.undo,
  MemoToolbarActionId.redo,
  MemoToolbarActionId.tag,
  MemoToolbarActionId.template,
  MemoToolbarActionId.attachment,
  MemoToolbarActionId.gallery,
  MemoToolbarActionId.todo,
  MemoToolbarActionId.link,
  MemoToolbarActionId.camera,
  MemoToolbarActionId.location,
};

const kMemoToolbarMigratedHiddenActions = <MemoToolbarActionId>{
  MemoToolbarActionId.italic,
  MemoToolbarActionId.strikethrough,
  MemoToolbarActionId.inlineCode,
  MemoToolbarActionId.orderedList,
  MemoToolbarActionId.taskList,
  MemoToolbarActionId.quote,
  MemoToolbarActionId.heading1,
  MemoToolbarActionId.heading2,
  MemoToolbarActionId.heading3,
  MemoToolbarActionId.highlight,
  MemoToolbarActionId.divider,
  MemoToolbarActionId.codeBlock,
  MemoToolbarActionId.inlineMath,
  MemoToolbarActionId.blockMath,
  MemoToolbarActionId.table,
  MemoToolbarActionId.cutParagraph,
};

const kMemoToolbarLegacyCustomIconKeyById = <String, String>{
  'heading1': 'hammer',
  'heading2': 'puzzlePiece',
  'heading3': 'sparkle',
  'quote': 'lightning',
  'inlineCode': 'code',
  'codeBlock': 'terminal',
  'task': 'gearSix',
  'divider': 'slidersHorizontal',
  'table': 'squaresFour',
  'note': 'star',
};

@immutable
class MemoToolbarItemId {
  const MemoToolbarItemId._(this.storageValue);

  static const builtinPrefix = 'builtin:';
  static const customPrefix = 'custom:';

  factory MemoToolbarItemId.builtin(MemoToolbarActionId action) {
    return MemoToolbarItemId._('$builtinPrefix${action.name}');
  }

  factory MemoToolbarItemId.custom(String id) {
    return MemoToolbarItemId._('$customPrefix$id');
  }

  static MemoToolbarItemId? tryParse(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith(builtinPrefix)) {
      final actionName = trimmed.substring(builtinPrefix.length);
      for (final action in MemoToolbarActionId.values) {
        if (action.name == actionName) {
          return MemoToolbarItemId.builtin(action);
        }
      }
      return null;
    }

    if (trimmed.startsWith(customPrefix)) {
      final id = trimmed.substring(customPrefix.length).trim();
      if (id.isEmpty) return null;
      return MemoToolbarItemId.custom(id);
    }

    for (final action in MemoToolbarActionId.values) {
      if (action.name == trimmed) {
        return MemoToolbarItemId.builtin(action);
      }
    }
    return null;
  }

  final String storageValue;

  MemoToolbarActionId? get builtinAction {
    if (!storageValue.startsWith(builtinPrefix)) return null;
    final actionName = storageValue.substring(builtinPrefix.length);
    for (final action in MemoToolbarActionId.values) {
      if (action.name == actionName) return action;
    }
    return null;
  }

  String? get customId {
    if (!storageValue.startsWith(customPrefix)) return null;
    final id = storageValue.substring(customPrefix.length).trim();
    return id.isEmpty ? null : id;
  }

  bool get isBuiltin => builtinAction != null;

  bool get isCustom => customId != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemoToolbarItemId && other.storageValue == storageValue;
  }

  @override
  int get hashCode => storageValue.hashCode;

  @override
  String toString() => storageValue;
}

@immutable
class MemoToolbarCustomButton {
  const MemoToolbarCustomButton({
    required this.id,
    required this.label,
    required this.iconKey,
    required this.insertContent,
  });

  static MemoToolbarCustomButton? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = (json['id'] as String? ?? '').trim();
    final label = (json['label'] as String? ?? '').trim();
    final insertContent = (json['insertContent'] as String? ?? '');
    final iconKey =
        ((json['iconKey'] as String?) ??
                kMemoToolbarLegacyCustomIconKeyById[(json['iconId']
                            as String? ??
                        '')
                    .trim()] ??
                kMemoToolbarDefaultCustomIconKey)
            .trim();
    if (id.isEmpty || label.isEmpty || insertContent.isEmpty) {
      return null;
    }

    if (iconKey.isEmpty) return null;

    return MemoToolbarCustomButton(
      id: id,
      label: label,
      iconKey: iconKey,
      insertContent: insertContent,
    );
  }

  factory MemoToolbarCustomButton.create({
    required String label,
    required String iconKey,
    required String insertContent,
  }) {
    return MemoToolbarCustomButton(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: label.trim(),
      iconKey: iconKey.trim(),
      insertContent: insertContent,
    );
  }

  final String id;
  final String label;
  final String iconKey;
  final String insertContent;

  MemoToolbarItemId get itemId => MemoToolbarItemId.custom(id);

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'iconKey': iconKey,
    'insertContent': insertContent,
  };

  MemoToolbarCustomButton copyWith({
    String? id,
    String? label,
    String? iconKey,
    String? insertContent,
  }) {
    return MemoToolbarCustomButton(
      id: id ?? this.id,
      label: label ?? this.label,
      iconKey: iconKey ?? this.iconKey,
      insertContent: insertContent ?? this.insertContent,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemoToolbarCustomButton &&
        other.id == id &&
        other.label == label &&
        other.iconKey == iconKey &&
        other.insertContent == insertContent;
  }

  @override
  int get hashCode => Object.hash(id, label, iconKey, insertContent);
}

const kMemoToolbarDefaultTopRow = <MemoToolbarActionId>[
  MemoToolbarActionId.bold,
  MemoToolbarActionId.italic,
  MemoToolbarActionId.strikethrough,
  MemoToolbarActionId.inlineCode,
  MemoToolbarActionId.list,
  MemoToolbarActionId.orderedList,
  MemoToolbarActionId.taskList,
  MemoToolbarActionId.quote,
  MemoToolbarActionId.underline,
  MemoToolbarActionId.highlight,
  MemoToolbarActionId.undo,
  MemoToolbarActionId.redo,
];

const kMemoToolbarDefaultBottomRow = <MemoToolbarActionId>[
  MemoToolbarActionId.divider,
  MemoToolbarActionId.table,
  MemoToolbarActionId.cutParagraph,
  MemoToolbarActionId.todo,
  MemoToolbarActionId.heading1,
  MemoToolbarActionId.heading2,
  MemoToolbarActionId.heading3,
  MemoToolbarActionId.codeBlock,
  MemoToolbarActionId.inlineMath,
  MemoToolbarActionId.blockMath,
  MemoToolbarActionId.tag,
  MemoToolbarActionId.template,
  MemoToolbarActionId.attachment,
  MemoToolbarActionId.gallery,
  MemoToolbarActionId.link,
  MemoToolbarActionId.camera,
  MemoToolbarActionId.draftBox,
  MemoToolbarActionId.location,
];

const kMemoToolbarDefaultHiddenActions = <MemoToolbarActionId>{
  MemoToolbarActionId.divider,
  MemoToolbarActionId.table,
  MemoToolbarActionId.cutParagraph,
  MemoToolbarActionId.todo,
};

extension MemoToolbarActionIdX on MemoToolbarActionId {
  MemoToolbarRow get defaultRow {
    return switch (this) {
      MemoToolbarActionId.bold ||
      MemoToolbarActionId.italic ||
      MemoToolbarActionId.strikethrough ||
      MemoToolbarActionId.inlineCode ||
      MemoToolbarActionId.list ||
      MemoToolbarActionId.orderedList ||
      MemoToolbarActionId.taskList ||
      MemoToolbarActionId.quote ||
      MemoToolbarActionId.underline ||
      MemoToolbarActionId.highlight ||
      MemoToolbarActionId.undo ||
      MemoToolbarActionId.redo => MemoToolbarRow.top,
      MemoToolbarActionId.divider ||
      MemoToolbarActionId.table ||
      MemoToolbarActionId.cutParagraph ||
      MemoToolbarActionId.heading1 ||
      MemoToolbarActionId.heading2 ||
      MemoToolbarActionId.heading3 ||
      MemoToolbarActionId.codeBlock ||
      MemoToolbarActionId.inlineMath ||
      MemoToolbarActionId.blockMath ||
      MemoToolbarActionId.tag ||
      MemoToolbarActionId.template ||
      MemoToolbarActionId.attachment ||
      MemoToolbarActionId.gallery ||
      MemoToolbarActionId.todo ||
      MemoToolbarActionId.link ||
      MemoToolbarActionId.camera ||
      MemoToolbarActionId.draftBox ||
      MemoToolbarActionId.location => MemoToolbarRow.bottom,
    };
  }

  MemoToolbarItemId get itemId => MemoToolbarItemId.builtin(this);
}

class MemoToolbarPreferences {
  MemoToolbarPreferences({
    required List<MemoToolbarItemId> topRowItems,
    required List<MemoToolbarItemId> bottomRowItems,
    required Set<MemoToolbarItemId> hiddenItemIds,
    required List<MemoToolbarCustomButton> customButtons,
  }) : topRowItems = List.unmodifiable(topRowItems),
       bottomRowItems = List.unmodifiable(bottomRowItems),
       hiddenItemIds = Set.unmodifiable(hiddenItemIds),
       customButtons = List.unmodifiable(customButtons);

  static final defaults = MemoToolbarPreferences(
    topRowItems: kMemoToolbarDefaultTopRow
        .map((action) => action.itemId)
        .toList(growable: false),
    bottomRowItems: kMemoToolbarDefaultBottomRow
        .map((action) => action.itemId)
        .toList(growable: false),
    hiddenItemIds: kMemoToolbarDefaultHiddenActions
        .map((action) => action.itemId)
        .toSet(),
    customButtons: const <MemoToolbarCustomButton>[],
  );

  final List<MemoToolbarItemId> topRowItems;
  final List<MemoToolbarItemId> bottomRowItems;
  final Set<MemoToolbarItemId> hiddenItemIds;
  final List<MemoToolbarCustomButton> customButtons;

  List<MemoToolbarActionId> get topRow => topRowItems
      .map((item) => item.builtinAction)
      .whereType<MemoToolbarActionId>()
      .toList(growable: false);

  List<MemoToolbarActionId> get bottomRow => bottomRowItems
      .map((item) => item.builtinAction)
      .whereType<MemoToolbarActionId>()
      .toList(growable: false);

  Set<MemoToolbarActionId> get hiddenActions => hiddenItemIds
      .map((item) => item.builtinAction)
      .whereType<MemoToolbarActionId>()
      .toSet();

  factory MemoToolbarPreferences.fromJson(Object? json) {
    if (json is! Map) {
      return MemoToolbarPreferences.defaults;
    }

    List<MemoToolbarItemId> parseRow(String key) {
      final raw = json[key];
      if (raw is! List) return const <MemoToolbarItemId>[];
      return raw
          .map(MemoToolbarItemId.tryParse)
          .whereType<MemoToolbarItemId>()
          .toList(growable: false);
    }

    Set<MemoToolbarItemId> parseHidden() {
      final raw = json['hiddenActions'];
      if (raw is! List) return const <MemoToolbarItemId>{};
      return raw
          .map(MemoToolbarItemId.tryParse)
          .whereType<MemoToolbarItemId>()
          .toSet();
    }

    List<MemoToolbarCustomButton> parseCustomButtons() {
      final raw = json['customButtons'];
      if (raw is! List) return const <MemoToolbarCustomButton>[];
      return raw
          .map(MemoToolbarCustomButton.tryParse)
          .whereType<MemoToolbarCustomButton>()
          .toList(growable: false);
    }

    final topRowItems = parseRow('topRow');
    final bottomRowItems = parseRow('bottomRow');
    final hiddenItemIds = parseHidden();
    final customButtons = parseCustomButtons();
    final explicitlyStoredItems = <MemoToolbarItemId>{
      ...topRowItems,
      ...bottomRowItems,
      ...hiddenItemIds,
    };

    var normalized = MemoToolbarPreferences(
      topRowItems: topRowItems,
      bottomRowItems: bottomRowItems,
      hiddenItemIds: hiddenItemIds,
      customButtons: customButtons,
    ).normalized();

    for (final action in kMemoToolbarMigratedHiddenActions) {
      final item = action.itemId;
      if (!explicitlyStoredItems.contains(item)) {
        normalized = normalized.setHidden(action, true);
      }
    }

    return normalized;
  }

  Map<String, dynamic> toJson() => {
    'topRow': topRowItems
        .map((value) => value.storageValue)
        .toList(growable: false),
    'bottomRow': bottomRowItems
        .map((value) => value.storageValue)
        .toList(growable: false),
    'hiddenActions': hiddenItemIds
        .map((value) => value.storageValue)
        .toList(growable: false),
    'customButtons': customButtons
        .map((button) => button.toJson())
        .toList(growable: false),
  };

  MemoToolbarPreferences copyWith({
    List<MemoToolbarItemId>? topRowItems,
    List<MemoToolbarItemId>? bottomRowItems,
    Set<MemoToolbarItemId>? hiddenItemIds,
    List<MemoToolbarCustomButton>? customButtons,
  }) {
    return MemoToolbarPreferences(
      topRowItems: topRowItems ?? this.topRowItems,
      bottomRowItems: bottomRowItems ?? this.bottomRowItems,
      hiddenItemIds: hiddenItemIds ?? this.hiddenItemIds,
      customButtons: customButtons ?? this.customButtons,
    );
  }

  MemoToolbarPreferences normalized() {
    final normalizedCustomButtons = <MemoToolbarCustomButton>[];
    final seenCustomIds = <String>{};
    for (final button in customButtons) {
      final trimmedId = button.id.trim();
      final trimmedLabel = button.label.trim();
      final trimmedIconKey = button.iconKey.trim();
      if (trimmedId.isEmpty ||
          trimmedLabel.isEmpty ||
          trimmedIconKey.isEmpty ||
          button.insertContent.isEmpty) {
        continue;
      }
      if (!seenCustomIds.add(trimmedId)) continue;
      normalizedCustomButtons.add(
        button.copyWith(
          id: trimmedId,
          label: trimmedLabel,
          iconKey: trimmedIconKey,
        ),
      );
    }

    final validItems = <MemoToolbarItemId>{
      for (final action in MemoToolbarActionId.values) action.itemId,
      for (final button in normalizedCustomButtons) button.itemId,
    };

    final seen = <MemoToolbarItemId>{};
    final normalizedTop = <MemoToolbarItemId>[];
    final normalizedBottom = <MemoToolbarItemId>[];

    void addUnique(
      Iterable<MemoToolbarItemId> source,
      List<MemoToolbarItemId> target,
    ) {
      for (final item in source) {
        if (!validItems.contains(item)) continue;
        if (seen.add(item)) {
          target.add(item);
        }
      }
    }

    addUnique(topRowItems, normalizedTop);
    addUnique(bottomRowItems, normalizedBottom);

    for (final action in MemoToolbarActionId.values) {
      final item = action.itemId;
      if (seen.contains(item)) continue;
      switch (action.defaultRow) {
        case MemoToolbarRow.top:
          normalizedTop.add(item);
        case MemoToolbarRow.bottom:
          normalizedBottom.add(item);
      }
      seen.add(item);
    }

    for (final button in normalizedCustomButtons) {
      final item = button.itemId;
      if (seen.add(item)) {
        normalizedBottom.add(item);
      }
    }

    final normalizedHidden = hiddenItemIds.where(validItems.contains).toSet();

    return MemoToolbarPreferences(
      topRowItems: normalizedTop,
      bottomRowItems: normalizedBottom,
      hiddenItemIds: normalizedHidden,
      customButtons: normalizedCustomButtons,
    );
  }

  MemoToolbarCustomButton? customButtonById(String id) {
    for (final button in customButtons) {
      if (button.id == id) return button;
    }
    return null;
  }

  MemoToolbarCustomButton? customButtonForItem(MemoToolbarItemId item) {
    final customId = item.customId;
    if (customId == null) return null;
    return customButtonById(customId);
  }

  MemoToolbarRow rowOfItem(MemoToolbarItemId item) {
    if (topRowItems.contains(item)) return MemoToolbarRow.top;
    return MemoToolbarRow.bottom;
  }

  MemoToolbarRow rowOf(MemoToolbarActionId action) {
    return rowOfItem(action.itemId);
  }

  bool isHiddenItem(MemoToolbarItemId item) {
    return hiddenItemIds.contains(item);
  }

  bool isHidden(MemoToolbarActionId action) {
    return isHiddenItem(action.itemId);
  }

  MemoToolbarPreferences setHiddenItem(MemoToolbarItemId item, bool hidden) {
    final nextHidden = Set<MemoToolbarItemId>.from(hiddenItemIds);
    if (hidden) {
      nextHidden.add(item);
    } else {
      nextHidden.remove(item);
    }
    return copyWith(hiddenItemIds: nextHidden).normalized();
  }

  MemoToolbarPreferences setHidden(MemoToolbarActionId action, bool hidden) {
    return setHiddenItem(action.itemId, hidden);
  }

  MemoToolbarPreferences moveItem({
    required MemoToolbarItemId item,
    required MemoToolbarRow targetRow,
    required int targetIndex,
  }) {
    final nextTop = List<MemoToolbarItemId>.from(topRowItems);
    final nextBottom = List<MemoToolbarItemId>.from(bottomRowItems);
    final currentRow = rowOfItem(item);
    final currentList = currentRow == MemoToolbarRow.top ? nextTop : nextBottom;
    final destinationList = targetRow == MemoToolbarRow.top
        ? nextTop
        : nextBottom;
    final currentIndex = currentList.indexOf(item);

    if (currentIndex == -1) {
      return this;
    }

    currentList.removeAt(currentIndex);
    var safeTargetIndex = targetIndex.clamp(0, destinationList.length);
    if (currentRow == targetRow && currentIndex < safeTargetIndex) {
      safeTargetIndex -= 1;
    }
    safeTargetIndex = safeTargetIndex.clamp(0, destinationList.length);
    destinationList.insert(safeTargetIndex, item);

    return MemoToolbarPreferences(
      topRowItems: nextTop,
      bottomRowItems: nextBottom,
      hiddenItemIds: hiddenItemIds,
      customButtons: customButtons,
    ).normalized();
  }

  MemoToolbarPreferences moveAction({
    required MemoToolbarActionId action,
    required MemoToolbarRow targetRow,
    required int targetIndex,
  }) {
    return moveItem(
      item: action.itemId,
      targetRow: targetRow,
      targetIndex: targetIndex,
    );
  }

  MemoToolbarPreferences addCustomButton(
    MemoToolbarCustomButton button, {
    MemoToolbarRow row = MemoToolbarRow.bottom,
    bool hidden = true,
  }) {
    final nextButtons = [
      for (final existing in customButtons)
        if (existing.id != button.id) existing,
      button,
    ];
    final normalized = copyWith(customButtons: nextButtons).normalized();
    final targetIndex = row == MemoToolbarRow.top
        ? normalized.topRowItems.length
        : normalized.bottomRowItems.length;
    return normalized
        .moveItem(item: button.itemId, targetRow: row, targetIndex: targetIndex)
        .setHiddenItem(button.itemId, hidden);
  }

  List<MemoToolbarItemId> visibleItemIdsForRow(
    MemoToolbarRow row, {
    Set<MemoToolbarItemId>? supportedItems,
  }) {
    final source = row == MemoToolbarRow.top ? topRowItems : bottomRowItems;
    return source
        .where((item) => !hiddenItemIds.contains(item))
        .where((item) => supportedItems?.contains(item) ?? true)
        .toList(growable: false);
  }

  List<MemoToolbarActionId> visibleActionsForRow(
    MemoToolbarRow row, {
    Set<MemoToolbarActionId>? supportedActions,
  }) {
    final supportedItems = supportedActions
        ?.map((action) => action.itemId)
        .toSet();
    return visibleItemIdsForRow(row, supportedItems: supportedItems)
        .map((item) => item.builtinAction)
        .whereType<MemoToolbarActionId>()
        .toList(growable: false);
  }

  List<MemoToolbarItemId> hiddenItemIdsInOrder() {
    return <MemoToolbarItemId>[
      ...topRowItems,
      ...bottomRowItems,
    ].where(hiddenItemIds.contains).toList(growable: false);
  }

  List<MemoToolbarActionId> hiddenActionsInOrder() {
    return hiddenItemIdsInOrder()
        .map((item) => item.builtinAction)
        .whereType<MemoToolbarActionId>()
        .toList(growable: false);
  }

  int insertionIndexForVisibleSlot({
    required MemoToolbarRow row,
    required int visibleIndex,
    Set<MemoToolbarItemId>? supportedItems,
  }) {
    final source = row == MemoToolbarRow.top ? topRowItems : bottomRowItems;
    final visible = visibleItemIdsForRow(row, supportedItems: supportedItems);

    if (visible.isEmpty) {
      return source.length;
    }
    if (visibleIndex <= 0) {
      return source.indexOf(visible.first);
    }
    if (visibleIndex >= visible.length) {
      return source.length;
    }

    return source.indexOf(visible[visibleIndex]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemoToolbarPreferences &&
        listEquals(other.topRowItems, topRowItems) &&
        listEquals(other.bottomRowItems, bottomRowItems) &&
        setEquals(other.hiddenItemIds, hiddenItemIds) &&
        listEquals(other.customButtons, customButtons);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(topRowItems),
    Object.hashAll(bottomRowItems),
    Object.hashAll(
      hiddenItemIds.toList()
        ..sort((a, b) => a.storageValue.compareTo(b.storageValue)),
    ),
    Object.hashAll(customButtons),
  );
}
