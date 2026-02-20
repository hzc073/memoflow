import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool isDesktopShortcutTargetPlatform([TargetPlatform? platform]) {
  final value = platform ?? defaultTargetPlatform;
  return value == TargetPlatform.windows || value == TargetPlatform.macOS;
}

bool isDesktopShortcutEnabled() {
  return !kIsWeb && isDesktopShortcutTargetPlatform();
}

bool isPrimaryShortcutModifierPressed(Set<LogicalKeyboardKey> pressedKeys) {
  final hasControl =
      pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
      pressedKeys.contains(LogicalKeyboardKey.controlRight);
  final hasMeta =
      pressedKeys.contains(LogicalKeyboardKey.metaLeft) ||
      pressedKeys.contains(LogicalKeyboardKey.metaRight);
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    return hasMeta || hasControl;
  }
  return hasControl;
}

bool isShiftModifierPressed(Set<LogicalKeyboardKey> pressedKeys) {
  return pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
      pressedKeys.contains(LogicalKeyboardKey.shiftRight);
}

bool isAltModifierPressed(Set<LogicalKeyboardKey> pressedKeys) {
  return pressedKeys.contains(LogicalKeyboardKey.altLeft) ||
      pressedKeys.contains(LogicalKeyboardKey.altRight);
}

String desktopPrimaryShortcutLabel() {
  return defaultTargetPlatform == TargetPlatform.macOS ? 'Cmd' : 'Ctrl';
}

enum DesktopShortcutAction {
  search,
  quickRecord,
  quickInput,
  toggleSidebar,
  refresh,
  backHome,
  openSettings,
  enableAppLock,
  toggleFlomo,
  shortcutOverview,
  publishMemo,
  bold,
  underline,
  highlight,
  unorderedList,
  orderedList,
  undo,
  redo,
}

const List<DesktopShortcutAction> desktopShortcutGlobalActions =
    <DesktopShortcutAction>[
      DesktopShortcutAction.search,
      DesktopShortcutAction.quickRecord,
      DesktopShortcutAction.quickInput,
      DesktopShortcutAction.toggleSidebar,
      DesktopShortcutAction.refresh,
      DesktopShortcutAction.backHome,
      DesktopShortcutAction.openSettings,
      DesktopShortcutAction.enableAppLock,
      DesktopShortcutAction.toggleFlomo,
      DesktopShortcutAction.shortcutOverview,
    ];

const List<DesktopShortcutAction> desktopShortcutEditorActions =
    <DesktopShortcutAction>[
      DesktopShortcutAction.publishMemo,
      DesktopShortcutAction.bold,
      DesktopShortcutAction.underline,
      DesktopShortcutAction.highlight,
      DesktopShortcutAction.unorderedList,
      DesktopShortcutAction.orderedList,
      DesktopShortcutAction.undo,
      DesktopShortcutAction.redo,
    ];

String desktopShortcutActionLabel(DesktopShortcutAction action) {
  switch (action) {
    case DesktopShortcutAction.search:
      return '搜索';
    case DesktopShortcutAction.quickRecord:
      return '快速输入';
    case DesktopShortcutAction.quickInput:
      return '聚焦输入区';
    case DesktopShortcutAction.toggleSidebar:
      return '切换侧边栏';
    case DesktopShortcutAction.refresh:
      return '刷新';
    case DesktopShortcutAction.backHome:
      return '返回首页';
    case DesktopShortcutAction.openSettings:
      return '打开设置';
    case DesktopShortcutAction.enableAppLock:
      return '启用应用锁';
    case DesktopShortcutAction.toggleFlomo:
      return '显示/隐藏 MemoFlow';
    case DesktopShortcutAction.shortcutOverview:
      return '快捷键总览';
    case DesktopShortcutAction.publishMemo:
      return '发布笔记';
    case DesktopShortcutAction.bold:
      return '加粗';
    case DesktopShortcutAction.underline:
      return '下划线';
    case DesktopShortcutAction.highlight:
      return '高亮';
    case DesktopShortcutAction.unorderedList:
      return '无序列表';
    case DesktopShortcutAction.orderedList:
      return '有序列表';
    case DesktopShortcutAction.undo:
      return '撤销';
    case DesktopShortcutAction.redo:
      return '重做';
  }
}

@immutable
class DesktopShortcutBinding {
  const DesktopShortcutBinding({
    required this.keyId,
    required this.primary,
    required this.shift,
    required this.alt,
  });

  final int keyId;
  final bool primary;
  final bool shift;
  final bool alt;

  LogicalKeyboardKey get logicalKey =>
      LogicalKeyboardKey.findKeyByKeyId(keyId) ?? LogicalKeyboardKey(keyId);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'keyId': keyId,
    'primary': primary,
    'shift': shift,
    'alt': alt,
  };

  static DesktopShortcutBinding? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<Object?, Object?>();
    final parsedKeyId = _parseKeyId(map['keyId']);
    if (parsedKeyId == null) return null;
    return DesktopShortcutBinding(
      keyId: parsedKeyId,
      primary: _parseBool(map['primary']),
      shift: _parseBool(map['shift']),
      alt: _parseBool(map['alt']),
    );
  }

  static int? _parseKeyId(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
        return int.tryParse(trimmed.substring(2), radix: 16);
      }
      return int.tryParse(trimmed);
    }
    return null;
  }

  static bool _parseBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    return false;
  }

  @override
  bool operator ==(Object other) {
    return other is DesktopShortcutBinding &&
        other.keyId == keyId &&
        other.primary == primary &&
        other.shift == shift &&
        other.alt == alt;
  }

  @override
  int get hashCode => Object.hash(keyId, primary, shift, alt);
}

final Map<DesktopShortcutAction, DesktopShortcutBinding>
desktopShortcutDefaultBindings =
    Map<DesktopShortcutAction, DesktopShortcutBinding>.unmodifiable(
      <DesktopShortcutAction, DesktopShortcutBinding>{
        DesktopShortcutAction.search: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.keyK.keyId,
          primary: true,
          shift: false,
          alt: false,
        ),
        DesktopShortcutAction.quickRecord: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.keyN.keyId,
          primary: true,
          shift: true,
          alt: false,
        ),
        DesktopShortcutAction.quickInput: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.slash.keyId,
          primary: true,
          shift: false,
          alt: false,
        ),
        DesktopShortcutAction.toggleSidebar: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.backslash.keyId,
          primary: true,
          shift: false,
          alt: false,
        ),
        DesktopShortcutAction.refresh: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.keyR.keyId,
          primary: true,
          shift: false,
          alt: false,
        ),
        DesktopShortcutAction.backHome: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.keyF.keyId,
          primary: true,
          shift: true,
          alt: false,
        ),
        DesktopShortcutAction.openSettings: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.comma.keyId,
          primary: true,
          shift: false,
          alt: false,
        ),
        DesktopShortcutAction.enableAppLock: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.keyL.keyId,
          primary: true,
          shift: true,
          alt: false,
        ),
        DesktopShortcutAction.toggleFlomo: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.digit0.keyId,
          primary: true,
          shift: true,
          alt: false,
        ),
        DesktopShortcutAction.shortcutOverview: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.slash.keyId,
          primary: false,
          shift: true,
          alt: false,
        ),
        DesktopShortcutAction.publishMemo: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.enter.keyId,
          primary: true,
          shift: false,
          alt: false,
        ),
        DesktopShortcutAction.bold: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.keyB.keyId,
          primary: true,
          shift: false,
          alt: false,
        ),
        DesktopShortcutAction.underline: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.keyU.keyId,
          primary: true,
          shift: false,
          alt: false,
        ),
        DesktopShortcutAction.highlight: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.keyH.keyId,
          primary: true,
          shift: true,
          alt: false,
        ),
        DesktopShortcutAction.unorderedList: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.digit8.keyId,
          primary: true,
          shift: true,
          alt: false,
        ),
        DesktopShortcutAction.orderedList: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.digit7.keyId,
          primary: true,
          shift: true,
          alt: false,
        ),
        DesktopShortcutAction.undo: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.keyZ.keyId,
          primary: true,
          shift: false,
          alt: false,
        ),
        DesktopShortcutAction.redo: DesktopShortcutBinding(
          keyId: LogicalKeyboardKey.keyZ.keyId,
          primary: true,
          shift: true,
          alt: false,
        ),
      },
    );

DesktopShortcutAction? desktopShortcutActionFromStorageKey(String key) {
  final trimmed = key.trim();
  if (trimmed.isEmpty) return null;
  for (final action in DesktopShortcutAction.values) {
    if (action.name == trimmed) return action;
  }
  return null;
}

Map<DesktopShortcutAction, DesktopShortcutBinding>
normalizeDesktopShortcutBindings(
  Map<DesktopShortcutAction, DesktopShortcutBinding>? overrides,
) {
  final resolved = Map<DesktopShortcutAction, DesktopShortcutBinding>.from(
    desktopShortcutDefaultBindings,
  );
  if (overrides != null && overrides.isNotEmpty) {
    overrides.forEach((key, value) {
      if (desktopShortcutDefaultBindings.containsKey(key)) {
        resolved[key] = value;
      }
    });
  }
  return resolved;
}

Map<DesktopShortcutAction, DesktopShortcutBinding>
desktopShortcutBindingsFromStorage(Object? raw) {
  if (raw is! Map) return normalizeDesktopShortcutBindings(null);
  final map = raw.cast<Object?, Object?>();
  final parsed = <DesktopShortcutAction, DesktopShortcutBinding>{};
  map.forEach((k, v) {
    if (k is! String) return;
    final action = desktopShortcutActionFromStorageKey(k);
    final binding = DesktopShortcutBinding.fromJson(v);
    if (action == null || binding == null) return;
    parsed[action] = binding;
  });
  return normalizeDesktopShortcutBindings(parsed);
}

Map<String, dynamic> desktopShortcutBindingsToStorage(
  Map<DesktopShortcutAction, DesktopShortcutBinding> bindings,
) {
  final normalized = normalizeDesktopShortcutBindings(bindings);
  return <String, dynamic>{
    for (final entry in normalized.entries)
      entry.key.name: entry.value.toJson(),
  };
}

bool matchesDesktopShortcut({
  required KeyEvent event,
  required Set<LogicalKeyboardKey> pressedKeys,
  required DesktopShortcutBinding binding,
}) {
  if (event is! KeyDownEvent) return false;
  final primary = isPrimaryShortcutModifierPressed(pressedKeys);
  final shift = isShiftModifierPressed(pressedKeys);
  final alt = isAltModifierPressed(pressedKeys);
  return event.logicalKey.keyId == binding.keyId &&
      primary == binding.primary &&
      shift == binding.shift &&
      alt == binding.alt;
}

bool isDesktopShortcutModifierKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight;
}

DesktopShortcutBinding? desktopShortcutBindingFromKeyEvent(
  KeyEvent event, {
  required Set<LogicalKeyboardKey> pressedKeys,
  bool requireModifier = true,
}) {
  if (event is! KeyDownEvent) return null;
  final key = event.logicalKey;
  if (isDesktopShortcutModifierKey(key)) return null;
  final primary = isPrimaryShortcutModifierPressed(pressedKeys);
  final shift = isShiftModifierPressed(pressedKeys);
  final alt = isAltModifierPressed(pressedKeys);
  if (requireModifier && !(primary || shift || alt)) return null;
  return DesktopShortcutBinding(
    keyId: key.keyId,
    primary: primary,
    shift: shift,
    alt: alt,
  );
}

String desktopShortcutBindingLabel(DesktopShortcutBinding binding) {
  final segments = <String>[];
  if (binding.primary) {
    segments.add(desktopPrimaryShortcutLabel());
  }
  if (binding.shift) {
    segments.add('Shift');
  }
  if (binding.alt) {
    segments.add('Alt');
  }
  segments.add(_desktopShortcutKeyLabel(binding.logicalKey));
  return segments.join(' + ');
}

String _desktopShortcutKeyLabel(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.enter) return '回车';
  if (key == LogicalKeyboardKey.slash) return '/';
  if (key == LogicalKeyboardKey.backslash) return r'\';
  if (key == LogicalKeyboardKey.comma) return ',';
  if (key == LogicalKeyboardKey.space) return '空格';
  if (key == LogicalKeyboardKey.f1) return 'F1';

  final raw = key.keyLabel.trim();
  if (raw.isNotEmpty) {
    return raw.length == 1 ? raw.toUpperCase() : raw;
  }

  final debug = key.debugName?.trim();
  if (debug != null && debug.isNotEmpty) {
    return debug.replaceAll('Logical Keyboard Key ', '');
  }
  return '按键';
}
