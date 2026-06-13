import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop_quick_input_channel.dart';
import '../../core/desktop_runtime_role.dart';
import '../../i18n/strings.g.dart';
import '../../platform/widgets/platform_dialog.dart';
import '../../platform/widgets/platform_primary_action.dart';
import '../../state/settings/workspace_preferences_provider.dart';
import '../memos/compose_toolbar_shared.dart';
import '../memos/memo_toolbar_custom_icon_catalog.dart' as toolbar_icons;
import 'settings_ui.dart';

class MemoToolbarSettingsScreen extends ConsumerWidget {
  const MemoToolbarSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(
      currentWorkspacePreferencesProvider.select(
        (p) => p.memoToolbarPreferences,
      ),
    );
    final notifier = ref.read(currentWorkspacePreferencesProvider.notifier);
    final runtimeRole = ref.read(desktopRuntimeRoleProvider);
    final tokens = settingsPageTokens(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = tokens.textMain;
    final mutedTextColor = tokens.textMuted;
    final borderColor = colorScheme.outlineVariant.withValues(alpha: 0.65);
    final toolbarStrings = context.t.strings.settings.preferences.editorToolbar;
    final toolboxItems = prefs.hiddenItemIdsInOrder();

    MemoToolbarPreferences moveItemToSlot({
      required MemoToolbarItemId item,
      required MemoToolbarRow row,
      required int visibleIndex,
    }) {
      final targetIndex = prefs.insertionIndexForVisibleSlot(
        row: row,
        visibleIndex: visibleIndex,
      );
      return prefs
          .moveItem(item: item, targetRow: row, targetIndex: targetIndex)
          .setHiddenItem(item, false);
    }

    void persist(MemoToolbarPreferences next) {
      notifier.setMemoToolbarPreferences(next.normalized());
      unawaited(_notifyDesktopToolbarPreferencesChanged(runtimeRole));
    }

    void resetToDefaults() {
      notifier.resetMemoToolbarPreferences();
      unawaited(_notifyDesktopToolbarPreferencesChanged(runtimeRole));
    }

    void clearAllToolbarButtons() {
      persist(
        prefs.copyWith(
          hiddenItemIds: {...prefs.topRowItems, ...prefs.bottomRowItems},
        ),
      );
    }

    Future<void> createCustomButton() async {
      final created = await showPlatformDialog<MemoToolbarCustomButton>(
        context: context,
        builder: (dialogContext) => const _CreateCustomToolbarButtonDialog(),
      );
      if (!context.mounted || created == null) return;
      persist(prefs.addCustomButton(created));
    }

    return SettingsPage(
      title: Text(toolbarStrings.title),
      actions: [
        TextButton(
          onPressed: resetToDefaults,
          child: Text(context.t.strings.legacy.msg_restore_defaults),
        ),
      ],
      children: [
        SettingsSection(
          header: Text(toolbarStrings.toolbox),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: _ToolboxPanel(
                preferences: prefs,
                items: toolboxItems,
                isDark: tokens.isDark,
                textColor: textColor,
                mutedTextColor: mutedTextColor,
                borderColor: borderColor,
                onCreateCustom: createCustomButton,
                onAdd: (item) => persist(prefs.setHiddenItem(item, false)),
                onDropIntoToolbox: (item) =>
                    persist(prefs.setHiddenItem(item, true)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsSection(
          header: Text(toolbarStrings.toolbarPreview),
          footer: Text(toolbarStrings.toolbarDescription),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      key: const ValueKey('memo-toolbar-clear-all'),
                      onPressed: clearAllToolbarButtons,
                      icon: const Icon(Icons.clear_all_rounded, size: 18),
                      label: Text(context.t.strings.legacy.msg_clear),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _EditorToolbarPreview(
                    isDark: tokens.isDark,
                    preferences: prefs,
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                    borderColor: borderColor,
                    onRemove: (item) =>
                        persist(prefs.setHiddenItem(item, true)),
                    onDrop: (item, row, visibleIndex) => persist(
                      moveItemToSlot(
                        item: item,
                        row: row,
                        visibleIndex: visibleIndex,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _toolbarItemKeySuffix(MemoToolbarItemId item) {
  final builtinAction = item.builtinAction;
  if (builtinAction != null) return builtinAction.name;
  final customId = item.customId;
  if (customId != null) return 'custom-$customId';
  return item.storageValue.replaceAll(':', '-');
}

Future<void> _notifyDesktopToolbarPreferencesChanged(
  DesktopRuntimeRole runtimeRole,
) async {
  if (kIsWeb || runtimeRole != DesktopRuntimeRole.desktopSettings) {
    return;
  }
  try {
    await DesktopMultiWindow.invokeMethod(
      0,
      desktopMainReloadPreferencesMethod,
      null,
    );
  } catch (_) {}
}

class _ToolbarDraggable extends StatelessWidget {
  const _ToolbarDraggable({
    super.key,
    required this.data,
    required this.feedback,
    required this.childWhenDragging,
    required this.child,
  });

  final MemoToolbarItemId data;
  final Widget feedback;
  final Widget childWhenDragging;
  final Widget child;

  bool get _useImmediateDrag {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_useImmediateDrag) {
      return Draggable<MemoToolbarItemId>(
        data: data,
        feedback: feedback,
        childWhenDragging: childWhenDragging,
        child: child,
      );
    }
    return LongPressDraggable<MemoToolbarItemId>(
      data: data,
      feedback: feedback,
      childWhenDragging: childWhenDragging,
      child: child,
    );
  }
}

class _ToolboxPanel extends StatelessWidget {
  const _ToolboxPanel({
    required this.preferences,
    required this.items,
    required this.isDark,
    required this.textColor,
    required this.mutedTextColor,
    required this.borderColor,
    required this.onCreateCustom,
    required this.onAdd,
    required this.onDropIntoToolbox,
  });

  final MemoToolbarPreferences preferences;
  final List<MemoToolbarItemId> items;
  final bool isDark;
  final Color textColor;
  final Color mutedTextColor;
  final Color borderColor;
  final VoidCallback onCreateCustom;
  final ValueChanged<MemoToolbarItemId> onAdd;
  final ValueChanged<MemoToolbarItemId> onDropIntoToolbox;

  @override
  Widget build(BuildContext context) {
    final toolbarStrings = context.t.strings.settings.preferences.editorToolbar;
    final colorScheme = Theme.of(context).colorScheme;

    return DragTarget<MemoToolbarItemId>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onDropIntoToolbox(details.data),
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.1)
                : Colors.transparent,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const crossAxisSpacing = 12.0;
              const minTileWidth = 68.0;
              final crossAxisCount =
                  ((constraints.maxWidth + crossAxisSpacing) /
                          (minTileWidth + crossAxisSpacing))
                      .floor()
                      .clamp(3, 6);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length + 1,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: crossAxisSpacing,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.82,
                    ),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _ToolboxCreateTile(
                          key: const ValueKey('memo-toolbar-create-custom'),
                          textColor: textColor,
                          mutedTextColor: mutedTextColor,
                          onTap: onCreateCustom,
                        );
                      }
                      final item = items[index - 1];
                      return _ToolboxActionTile(
                        preferences: preferences,
                        item: item,
                        textColor: textColor,
                        mutedTextColor: mutedTextColor,
                        onAdd: () => onAdd(item),
                      );
                    },
                  ),
                  if (items.isEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      toolbarStrings.toolboxEmpty,
                      style: TextStyle(color: mutedTextColor),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ToolboxCreateTile extends StatelessWidget {
  const _ToolboxCreateTile({
    super.key,
    required this.textColor,
    required this.mutedTextColor,
    required this.onTap,
  });

  final Color textColor;
  final Color mutedTextColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final toolbarStrings = context.t.strings.settings.preferences.editorToolbar;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _ToolActionVisual(
                icon: Icons.add_rounded,
                iconColor: textColor,
                backgroundColor: textColor.withValues(alpha: 0.05),
                borderColor: textColor.withValues(alpha: 0.14),
                dashedBorder: true,
              ),
              Positioned(
                top: -6,
                right: -6,
                child: _ActionBadgeButton(
                  icon: Icons.add,
                  color: const Color(0xFF2EAF61),
                  onTap: onTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            toolbarStrings.createCustomButton,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.25, color: mutedTextColor),
          ),
        ],
      ),
    );
  }
}

class _ToolboxActionTile extends StatelessWidget {
  const _ToolboxActionTile({
    required this.preferences,
    required this.item,
    required this.textColor,
    required this.mutedTextColor,
    required this.onAdd,
  });

  final MemoToolbarPreferences preferences;
  final MemoToolbarItemId item;
  final Color textColor;
  final Color mutedTextColor;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final visual = _ToolActionVisual(
      icon: item.resolveIcon(preferences),
      iconColor: textColor,
      backgroundColor: textColor.withValues(alpha: 0.05),
      borderColor: textColor.withValues(alpha: 0.08),
    );
    final keySuffix = _toolbarItemKeySuffix(item);

    return _ToolbarDraggable(
      key: ValueKey<String>('memo-toolbar-toolbox-$keySuffix'),
      data: item,
      feedback: Material(color: Colors.transparent, child: visual),
      childWhenDragging: Opacity(opacity: 0.35, child: visual),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Tooltip(
                message: item.resolveLabel(context, preferences),
                child: visual,
              ),
              Positioned(
                top: -6,
                right: -6,
                child: _ActionBadgeButton(
                  key: ValueKey<String>('memo-toolbar-add-$keySuffix'),
                  icon: Icons.add,
                  color: const Color(0xFF2EAF61),
                  onTap: onAdd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.resolveLabel(context, preferences),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.25, color: mutedTextColor),
          ),
        ],
      ),
    );
  }
}

class _EditorToolbarPreview extends StatelessWidget {
  const _EditorToolbarPreview({
    required this.isDark,
    required this.preferences,
    required this.textColor,
    required this.mutedTextColor,
    required this.borderColor,
    required this.onRemove,
    required this.onDrop,
  });

  final bool isDark;
  final MemoToolbarPreferences preferences;
  final Color textColor;
  final Color mutedTextColor;
  final Color borderColor;
  final ValueChanged<MemoToolbarItemId> onRemove;
  final void Function(
    MemoToolbarItemId item,
    MemoToolbarRow row,
    int visibleIndex,
  )
  onDrop;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark
        ? Colors.white.withValues(alpha: 0.035)
        : Colors.white.withValues(alpha: 0.8);
    final editorBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final visibilityColor = mutedTextColor;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: editorBorderColor),
      ),
      child: Column(
        children: [
          Container(
            alignment: Alignment.topLeft,
            constraints: const BoxConstraints(minHeight: 124),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Text(
              context.t.strings.legacy.msg_write_something_supports_tag_tasks_x,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: mutedTextColor),
            ),
          ),
          Divider(height: 1, color: dividerColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _ToolbarPreviewContent(
                    preferences: preferences,
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                    dividerColor: dividerColor,
                    visibilityColor: visibilityColor,
                    onRemove: onRemove,
                    onDrop: onDrop,
                  ),
                ),
                const SizedBox(width: 10),
                _SendPreviewButton(isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarPreviewContent extends StatelessWidget {
  const _ToolbarPreviewContent({
    required this.preferences,
    required this.textColor,
    required this.mutedTextColor,
    required this.dividerColor,
    required this.visibilityColor,
    required this.onRemove,
    required this.onDrop,
  });

  final MemoToolbarPreferences preferences;
  final Color textColor;
  final Color mutedTextColor;
  final Color dividerColor;
  final Color visibilityColor;
  final ValueChanged<MemoToolbarItemId> onRemove;
  final void Function(
    MemoToolbarItemId item,
    MemoToolbarRow row,
    int visibleIndex,
  )
  onDrop;

  @override
  Widget build(BuildContext context) {
    final topItems = preferences.visibleItemIdsForRow(MemoToolbarRow.top);
    final bottomItems = preferences.visibleItemIdsForRow(MemoToolbarRow.bottom);

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ToolbarPreviewRow(
                    preferences: preferences,
                    row: MemoToolbarRow.top,
                    items: topItems,
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                    onRemove: onRemove,
                    onDrop: onDrop,
                  ),
                  if (topItems.isNotEmpty && bottomItems.isNotEmpty)
                    const SizedBox(height: 8),
                  if (bottomItems.isNotEmpty || topItems.isEmpty)
                    _ToolbarPreviewRow(
                      preferences: preferences,
                      row: MemoToolbarRow.bottom,
                      items: bottomItems,
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                      onRemove: onRemove,
                      onDrop: onDrop,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(width: 1, height: 30, color: dividerColor),
        const SizedBox(width: 12),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: visibilityColor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: visibilityColor.withValues(alpha: 0.12)),
          ),
          child: Icon(Icons.public, size: 15, color: visibilityColor),
        ),
      ],
    );
  }
}

class _ToolbarPreviewRow extends StatelessWidget {
  const _ToolbarPreviewRow({
    required this.preferences,
    required this.row,
    required this.items,
    required this.textColor,
    required this.mutedTextColor,
    required this.onRemove,
    required this.onDrop,
  });

  final MemoToolbarPreferences preferences;
  final MemoToolbarRow row;
  final List<MemoToolbarItemId> items;
  final Color textColor;
  final Color mutedTextColor;
  final ValueChanged<MemoToolbarItemId> onRemove;
  final void Function(
    MemoToolbarItemId item,
    MemoToolbarRow row,
    int visibleIndex,
  )
  onDrop;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyToolbarDropArea(
        row: row,
        textColor: textColor,
        mutedTextColor: mutedTextColor,
        onDrop: onDrop,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < items.length; index++)
          _ToolbarActionDropTarget(
            preferences: preferences,
            row: row,
            index: index,
            item: items[index],
            textColor: textColor,
            onRemove: () => onRemove(items[index]),
            onDrop: onDrop,
          ),
        _ToolbarRowEndDropTarget(
          row: row,
          activeColor: textColor,
          onAccept: (item) => onDrop(item, row, items.length),
        ),
      ],
    );
  }
}

class _EmptyToolbarDropArea extends StatelessWidget {
  const _EmptyToolbarDropArea({
    required this.row,
    required this.textColor,
    required this.mutedTextColor,
    required this.onDrop,
  });

  final MemoToolbarRow row;
  final Color textColor;
  final Color mutedTextColor;
  final void Function(
    MemoToolbarItemId item,
    MemoToolbarRow row,
    int visibleIndex,
  )
  onDrop;

  @override
  Widget build(BuildContext context) {
    return DragTarget<MemoToolbarItemId>(
      key: ValueKey<String>('memo-toolbar-drop-${row.name}-0'),
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onDrop(details.data, row, 0),
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        return Container(
          constraints: const BoxConstraints(minWidth: 180, minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? textColor.withValues(alpha: 0.12)
                : textColor.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? textColor.withValues(alpha: 0.35)
                  : textColor.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            context.t.strings.settings.preferences.editorToolbar.emptyRow,
            style: TextStyle(color: mutedTextColor, fontSize: 12),
          ),
        );
      },
    );
  }
}

class _ToolbarRowEndDropTarget extends StatelessWidget {
  const _ToolbarRowEndDropTarget({
    required this.row,
    required this.activeColor,
    required this.onAccept,
  });

  final MemoToolbarRow row;
  final Color activeColor;
  final ValueChanged<MemoToolbarItemId> onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<MemoToolbarItemId>(
      key: ValueKey<String>('memo-toolbar-drop-end-${row.name}'),
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: isActive ? 18 : 12,
          height: 40,
          margin: const EdgeInsets.only(left: 4),
          alignment: Alignment.centerRight,
          child: Container(
            width: 3,
            height: isActive ? 28 : 20,
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: isActive ? 0.78 : 0.16),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      },
    );
  }
}

class _ToolbarActionDropTarget extends StatefulWidget {
  const _ToolbarActionDropTarget({
    required this.preferences,
    required this.row,
    required this.index,
    required this.item,
    required this.textColor,
    required this.onRemove,
    required this.onDrop,
  });

  final MemoToolbarPreferences preferences;
  final MemoToolbarRow row;
  final int index;
  final MemoToolbarItemId item;
  final Color textColor;
  final VoidCallback onRemove;
  final void Function(
    MemoToolbarItemId item,
    MemoToolbarRow row,
    int visibleIndex,
  )
  onDrop;

  @override
  State<_ToolbarActionDropTarget> createState() =>
      _ToolbarActionDropTargetState();
}

class _ToolbarActionDropTargetState extends State<_ToolbarActionDropTarget> {
  bool _isHovering = false;
  bool _insertBefore = true;

  bool _resolveInsertBefore(Offset globalOffset) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return true;
    }
    final localOffset = renderObject.globalToLocal(globalOffset);
    return localOffset.dx <= renderObject.size.width / 2;
  }

  void _handleMove(DragTargetDetails<MemoToolbarItemId> details) {
    final nextInsertBefore = _resolveInsertBefore(details.offset);
    if (_isHovering && _insertBefore == nextInsertBefore) {
      return;
    }
    setState(() {
      _isHovering = true;
      _insertBefore = nextInsertBefore;
    });
  }

  void _clearHover() {
    if (!_isHovering) return;
    setState(() {
      _isHovering = false;
      _insertBefore = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final keySuffix = _toolbarItemKeySuffix(widget.item);
    return DragTarget<MemoToolbarItemId>(
      key: ValueKey<String>(
        'memo-toolbar-target-${widget.row.name}-$keySuffix',
      ),
      onWillAcceptWithDetails: (_) => true,
      onMove: _handleMove,
      onLeave: (_) => _clearHover(),
      onAcceptWithDetails: (details) {
        final visibleIndex = _resolveInsertBefore(details.offset)
            ? widget.index
            : widget.index + 1;
        widget.onDrop(details.data, widget.row, visibleIndex);
        _clearHover();
      },
      builder: (context, candidateData, rejectedData) {
        final showIndicator = _isHovering || candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _ToolbarActionPreviewButton(
                  preferences: widget.preferences,
                  item: widget.item,
                  iconColor: widget.textColor,
                  onRemove: widget.onRemove,
                ),
              ),
              if (showIndicator)
                Positioned(
                  top: 2,
                  bottom: 2,
                  left: _insertBefore ? 0 : null,
                  right: _insertBefore ? null : 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: widget.textColor.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolbarActionPreviewButton extends StatelessWidget {
  const _ToolbarActionPreviewButton({
    required this.preferences,
    required this.item,
    required this.iconColor,
    required this.onRemove,
  });

  final MemoToolbarPreferences preferences;
  final MemoToolbarItemId item;
  final Color iconColor;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final visual = _ToolActionVisual(
      icon: item.resolveIcon(preferences),
      iconColor: iconColor,
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
    );
    final keySuffix = _toolbarItemKeySuffix(item);

    return _ToolbarDraggable(
      key: ValueKey<String>('memo-toolbar-editor-$keySuffix'),
      data: item,
      feedback: Material(color: Colors.transparent, child: visual),
      childWhenDragging: Opacity(opacity: 0.35, child: visual),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Tooltip(
            message: item.resolveLabel(context, preferences),
            child: visual,
          ),
          Positioned(
            top: -6,
            right: -6,
            child: _ActionBadgeButton(
              key: ValueKey<String>('memo-toolbar-remove-$keySuffix'),
              icon: Icons.remove,
              color: const Color(0xFFE35757),
              onTap: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolActionVisual extends StatelessWidget {
  const _ToolActionVisual({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    this.dashedBorder = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final bool dashedBorder;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: dashedBorder ? null : Border.all(color: borderColor),
      ),
      child: Icon(icon, size: 20, color: iconColor),
    );
    if (!dashedBorder) return child;

    return CustomPaint(
      painter: _DashedRoundedRectPainter(color: borderColor),
      child: child,
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rect);
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final nextDistance = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, nextDistance), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ActionBadgeButton extends StatelessWidget {
  const _ActionBadgeButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 14,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 12, color: Colors.white),
        ),
      ),
    );
  }
}

class _CreateCustomToolbarButtonDialog extends StatefulWidget {
  const _CreateCustomToolbarButtonDialog();

  @override
  State<_CreateCustomToolbarButtonDialog> createState() =>
      _CreateCustomToolbarButtonDialogState();
}

enum _CustomIconGroup {
  all,
  aToE,
  fToJ,
  kToO,
  pToT,
  uToZ;

  String key(BuildContext context) => switch (this) {
    _CustomIconGroup.all => context.t.strings.legacy.msg_all,
    _CustomIconGroup.aToE => 'A-E',
    _CustomIconGroup.fToJ => 'F-J',
    _CustomIconGroup.kToO => 'K-O',
    _CustomIconGroup.pToT => 'P-T',
    _CustomIconGroup.uToZ => 'U-Z',
  };

  String valueKey() => switch (this) {
    _CustomIconGroup.all => 'all',
    _CustomIconGroup.aToE => 'a-e',
    _CustomIconGroup.fToJ => 'f-j',
    _CustomIconGroup.kToO => 'k-o',
    _CustomIconGroup.pToT => 'p-t',
    _CustomIconGroup.uToZ => 'u-z',
  };

  bool matches(toolbar_icons.MemoToolbarCustomIconOption option) =>
      switch (this) {
        _CustomIconGroup.all => true,
        _CustomIconGroup.aToE => _iconKeyStartsBetween(option.key, 'A', 'E'),
        _CustomIconGroup.fToJ => _iconKeyStartsBetween(option.key, 'F', 'J'),
        _CustomIconGroup.kToO => _iconKeyStartsBetween(option.key, 'K', 'O'),
        _CustomIconGroup.pToT => _iconKeyStartsBetween(option.key, 'P', 'T'),
        _CustomIconGroup.uToZ => _iconKeyStartsBetween(option.key, 'U', 'Z'),
      };
}

bool _iconKeyStartsBetween(String key, String start, String end) {
  if (key.isEmpty) {
    return false;
  }
  final codeUnit = key[0].toUpperCase().codeUnitAt(0);
  return codeUnit >= start.codeUnitAt(0) && codeUnit <= end.codeUnitAt(0);
}

class _CreateCustomToolbarButtonDialogState
    extends State<_CreateCustomToolbarButtonDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _contentController;
  String _selectedIconKey = kMemoToolbarDefaultCustomIconKey;
  _CustomIconGroup _selectedGroup = _CustomIconGroup.all;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
    _contentController = TextEditingController();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String? _validateLabel(String value) {
    if (value.trim().isEmpty) {
      return context
          .t
          .strings
          .settings
          .preferences
          .editorToolbar
          .customButtonNameRequired;
    }
    return null;
  }

  String? _validateContent(String value) {
    if (value.isEmpty) {
      return context
          .t
          .strings
          .settings
          .preferences
          .editorToolbar
          .customButtonContentRequired;
    }
    return null;
  }

  void _submit() {
    setState(() => _submitted = true);
    final labelError = _validateLabel(_labelController.text);
    final contentError = _validateContent(_contentController.text);
    if (labelError != null || contentError != null) {
      return;
    }

    Navigator.of(context).pop(
      MemoToolbarCustomButton.create(
        label: _labelController.text.trim(),
        iconKey: _selectedIconKey,
        insertContent: _contentController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final toolbarStrings = context.t.strings.settings.preferences.editorToolbar;
    final textTheme = Theme.of(context).textTheme;
    final labelError = _submitted
        ? _validateLabel(_labelController.text)
        : null;
    final contentError = _submitted
        ? _validateContent(_contentController.text)
        : null;
    final iconOptions = toolbar_icons.kMemoToolbarCustomIconOptions
        .where((option) => _selectedGroup.matches(option))
        .toList(growable: false);

    return SettingsFormDialog(
      maxWidth: 488,
      title: Text(toolbarStrings.createCustomDialogTitle),
      actions: [
        SettingsDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          label: Text(context.t.strings.legacy.msg_cancel),
        ),
        SettingsDialogAction(
          key: const ValueKey('memo-toolbar-create-save'),
          onPressed: _submit,
          variant: PlatformPrimaryActionVariant.filled,
          label: Text(context.t.strings.legacy.msg_save),
        ),
      ],
      children: [
        Text(toolbarStrings.customButtonIconLabel, style: textTheme.titleSmall),
        const SizedBox(height: 10),
        SettingsOptionChipGroup<_CustomIconGroup>(
          value: _selectedGroup,
          options: [
            for (final group in _CustomIconGroup.values)
              SettingsChoiceOption<_CustomIconGroup>(
                key: ValueKey('memo-toolbar-icon-group-${group.valueKey()}'),
                value: group,
                label: group.key(context),
              ),
          ],
          onChanged: (group) => setState(() => _selectedGroup = group),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 320,
          child: LayoutBuilder(
            builder: (context, constraints) {
              var crossAxisCount = ((constraints.maxWidth + 8) / 56).floor();
              if (crossAxisCount < 5) {
                crossAxisCount = 5;
              }

              return GridView.builder(
                key: ValueKey(
                  'memo-toolbar-icon-grid-${_selectedGroup.valueKey()}',
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: iconOptions.length,
                itemBuilder: (context, index) {
                  final option = iconOptions[index];
                  return _CustomIconOption(
                    key: ValueKey('memo-toolbar-icon-option-${option.key}'),
                    option: option,
                    selected: option.key == _selectedIconKey,
                    onTap: () => setState(() => _selectedIconKey = option.key),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        SettingsDialogTextField(
          label: toolbarStrings.customButtonNameLabel,
          controller: _labelController,
          hint: toolbarStrings.customButtonNameHint,
          errorText: labelError,
          inputFormatters: [LengthLimitingTextInputFormatter(4)],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        SettingsDialogTextField(
          label: toolbarStrings.customButtonContentLabel,
          controller: _contentController,
          hint: toolbarStrings.customButtonContentLabel,
          helperText: toolbarStrings.customButtonContentHelp,
          errorText: contentError,
          minLines: 3,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text(toolbarStrings.customButtonPreview, style: textTheme.titleSmall),
        const SizedBox(height: 10),
        Row(
          children: [
            _ToolActionVisual(
              icon: toolbar_icons.resolveMemoToolbarCustomIcon(
                _selectedIconKey,
              ),
              iconColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.08),
              borderColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labelController.text.trim().isEmpty
                        ? toolbarStrings.customButtonNameHint
                        : _labelController.text.trim(),
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _contentController.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CustomIconOption extends StatelessWidget {
  const _CustomIconOption({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final toolbar_icons.MemoToolbarCustomIconOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = selected
        ? colorScheme.primary
        : colorScheme.outline.withValues(alpha: 0.4);
    final backgroundColor = selected
        ? colorScheme.primary.withValues(alpha: 0.08)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);

    return Tooltip(
      message: option.label,
      waitDuration: const Duration(milliseconds: 250),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Icon(
            option.iconData,
            size: 18,
            color: selected ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _SendPreviewButton extends StatelessWidget {
  const _SendPreviewButton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: isDark ? 0.28 : 0.36),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(Icons.send_rounded, size: 20, color: colorScheme.onPrimary),
    );
  }
}
