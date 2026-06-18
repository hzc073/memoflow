import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/app_motion.dart';
import '../../../core/memoflow_palette.dart';
import '../../../data/models/local_memo.dart';
import '../../../i18n/strings.g.dart';
import '../../../platform/platform_target.dart';
import '../../../platform/widgets/platform_action_sheet.dart';
import '../memo_card_action.dart';

const Key memoCardActionPopoverKey = ValueKey<String>(
  'memo-card-action-popover',
);
const Key memoCardActionPrimarySectionKey = ValueKey<String>(
  'memo-card-action-primary-section',
);
const Key memoCardActionSecondarySectionKey = ValueKey<String>(
  'memo-card-action-secondary-section',
);
const Key memoCardActionDangerSectionKey = ValueKey<String>(
  'memo-card-action-danger-section',
);

Key memoCardActionItemKey(MemoCardAction action) =>
    ValueKey<String>('memo-card-action-${action.name}');

const double _memoCardActionMenuScale = 0.56;

double _scaled(num value) => value * _memoCardActionMenuScale;

enum MemoCardActionMenuSection { primary, secondary, danger }

class MemoCardActionDescriptor {
  const MemoCardActionDescriptor({
    required this.action,
    required this.label,
    required this.icon,
    required this.section,
    this.danger = false,
    this.showChevron = false,
  });

  final MemoCardAction action;
  final String label;
  final IconData icon;
  final MemoCardActionMenuSection section;
  final bool danger;
  final bool showChevron;
}

List<MemoCardActionDescriptor> buildMemoCardActionDescriptors({
  required BuildContext context,
  required LocalMemo memo,
  bool includeCopy = true,
  bool includeReminder = true,
}) {
  if (memo.state == 'ARCHIVED') {
    return [
      if (includeCopy)
        MemoCardActionDescriptor(
          action: MemoCardAction.copy,
          label: context.t.strings.legacy.msg_copy,
          icon: Icons.content_copy,
          section: MemoCardActionMenuSection.primary,
        ),
      MemoCardActionDescriptor(
        action: MemoCardAction.history,
        label: context.t.strings.settings.preferences.history,
        icon: Icons.history,
        section: MemoCardActionMenuSection.primary,
      ),
      MemoCardActionDescriptor(
        action: MemoCardAction.restore,
        label: context.t.strings.legacy.msg_restore,
        icon: Icons.restore_from_trash,
        section: MemoCardActionMenuSection.primary,
      ),
      MemoCardActionDescriptor(
        action: MemoCardAction.delete,
        label: context.t.strings.legacy.msg_delete,
        icon: Icons.delete_outline,
        section: MemoCardActionMenuSection.danger,
        danger: true,
      ),
    ];
  }

  return [
    if (includeCopy)
      MemoCardActionDescriptor(
        action: MemoCardAction.copy,
        label: context.t.strings.legacy.msg_copy,
        icon: Icons.content_copy,
        section: MemoCardActionMenuSection.primary,
      ),
    MemoCardActionDescriptor(
      action: MemoCardAction.edit,
      label: context.t.strings.legacy.msg_edit,
      icon: Icons.edit_outlined,
      section: MemoCardActionMenuSection.primary,
    ),
    if (includeReminder)
      MemoCardActionDescriptor(
        action: MemoCardAction.reminder,
        label: context.t.strings.legacy.msg_reminder,
        icon: Icons.notifications_none,
        section: MemoCardActionMenuSection.primary,
      ),
    MemoCardActionDescriptor(
      action: MemoCardAction.togglePinned,
      label: memo.pinned
          ? context.t.strings.legacy.msg_unpin
          : context.t.strings.legacy.msg_pin,
      icon: Icons.push_pin,
      section: MemoCardActionMenuSection.primary,
    ),
    MemoCardActionDescriptor(
      action: MemoCardAction.addToCollection,
      label: context.t.strings.collections.addToCollection,
      icon: Icons.create_new_folder,
      section: MemoCardActionMenuSection.primary,
    ),
    MemoCardActionDescriptor(
      action: MemoCardAction.archive,
      label: context.t.strings.legacy.msg_archive,
      icon: Icons.archive_outlined,
      section: MemoCardActionMenuSection.primary,
    ),
    MemoCardActionDescriptor(
      action: MemoCardAction.adjustTime,
      label: context.t.strings.memoTimeAdjustment.action,
      icon: Icons.schedule,
      section: MemoCardActionMenuSection.secondary,
      showChevron: true,
    ),
    MemoCardActionDescriptor(
      action: MemoCardAction.history,
      label: context.t.strings.settings.preferences.history,
      icon: Icons.history,
      section: MemoCardActionMenuSection.secondary,
      showChevron: true,
    ),
    MemoCardActionDescriptor(
      action: MemoCardAction.delete,
      label: context.t.strings.legacy.msg_delete,
      icon: Icons.delete_outline,
      section: MemoCardActionMenuSection.danger,
      danger: true,
    ),
  ];
}

List<MemoCardAction> buildMemoCardActionOrder({
  required BuildContext context,
  required LocalMemo memo,
  bool includeCopy = true,
  bool includeReminder = true,
}) {
  return buildMemoCardActionDescriptors(
    context: context,
    memo: memo,
    includeCopy: includeCopy,
    includeReminder: includeReminder,
  ).map((descriptor) => descriptor.action).toList(growable: false);
}

List<PopupMenuEntry<MemoCardAction>> buildMemoCardActionMenuItems({
  required BuildContext context,
  required LocalMemo memo,
  required Color deleteColor,
  bool includeCopy = true,
  bool includeReminder = true,
}) {
  final items = <PopupMenuEntry<MemoCardAction>>[];
  var lastSection = MemoCardActionMenuSection.primary;
  for (final descriptor in buildMemoCardActionDescriptors(
    context: context,
    memo: memo,
    includeCopy: includeCopy,
    includeReminder: includeReminder,
  )) {
    if (items.isNotEmpty && descriptor.section != lastSection) {
      items.add(const PopupMenuDivider());
    }
    lastSection = descriptor.section;
    items.add(
      PopupMenuItem<MemoCardAction>(
        value: descriptor.action,
        child: Text(
          descriptor.label,
          style: descriptor.danger
              ? TextStyle(color: deleteColor, fontWeight: FontWeight.w600)
              : null,
        ),
      ),
    );
  }
  return items;
}

Future<MemoCardAction?> showMemoCardContextMenu({
  required BuildContext context,
  required LocalMemo memo,
  required Offset globalPosition,
  bool includeCopy = true,
  bool includeReminder = true,
}) {
  return showMemoCardActionPopover(
    context: context,
    memo: memo,
    globalPosition: globalPosition,
    includeCopy: includeCopy,
    includeReminder: includeReminder,
  );
}

Future<MemoCardAction?> showMemoCardActionPopover({
  required BuildContext context,
  required LocalMemo memo,
  BuildContext? anchorContext,
  Offset? globalPosition,
  bool includeCopy = true,
  bool includeReminder = true,
}) {
  return showMemoActionPopover(
    context: context,
    actions: buildMemoCardActionDescriptors(
      context: context,
      memo: memo,
      includeCopy: includeCopy,
      includeReminder: includeReminder,
    ),
    anchorContext: anchorContext,
    globalPosition: globalPosition,
  );
}

Future<MemoCardAction?> showMemoActionPopover({
  required BuildContext context,
  required List<MemoCardActionDescriptor> actions,
  BuildContext? anchorContext,
  Offset? globalPosition,
}) {
  if (actions.isEmpty) return Future<MemoCardAction?>.value(null);
  if (resolvePlatformTarget(context) == PlatformTarget.iPhone) {
    return showPlatformActionSheet<MemoCardAction>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          for (final descriptor in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: descriptor.danger,
              onPressed: () =>
                  Navigator.of(sheetContext).pop(descriptor.action),
              child: Text(descriptor.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(context.t.strings.legacy.msg_cancel_2),
        ),
      ),
    );
  }
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null || !overlay.hasSize) {
    return Future<MemoCardAction?>.value(null);
  }
  final anchorRect = _resolveAnchorRect(
    overlay: overlay,
    anchorContext: anchorContext,
    globalPosition: globalPosition,
  );
  final motionEnabled = AppMotion.isEnabled(context);
  return showGeneralDialog<MemoCardAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: motionEnabled
        ? const Duration(milliseconds: 150)
        : Duration.zero,
    pageBuilder: (dialogContext, _, _) {
      final padding = MediaQuery.paddingOf(dialogContext);
      return Stack(
        children: [
          const Positioned.fill(child: SizedBox.expand()),
          CustomSingleChildLayout(
            delegate: _MemoCardActionPopoverLayoutDelegate(
              anchorRect: anchorRect,
              padding: padding,
            ),
            child: MemoCardActionPopover(
              actions: actions,
              onSelected: (action) => Navigator.of(dialogContext).pop(action),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (!motionEnabled) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          alignment: Alignment.topRight,
          child: child,
        ),
      );
    },
  );
}

Rect _resolveAnchorRect({
  required RenderBox overlay,
  BuildContext? anchorContext,
  Offset? globalPosition,
}) {
  final anchorObject = anchorContext?.findRenderObject();
  if (anchorObject is RenderBox && anchorObject.hasSize) {
    final topLeft = anchorObject.localToGlobal(Offset.zero, ancestor: overlay);
    return topLeft & anchorObject.size;
  }
  if (globalPosition != null) {
    final local = overlay.globalToLocal(globalPosition);
    return Rect.fromLTWH(local.dx, local.dy, 1, 1);
  }
  return Rect.fromCenter(
    center: overlay.size.center(Offset.zero),
    width: 1,
    height: 1,
  );
}

class MemoCardActionPopover extends StatelessWidget {
  const MemoCardActionPopover({
    super.key = memoCardActionPopoverKey,
    required this.actions,
    required this.onSelected,
  });

  final List<MemoCardActionDescriptor> actions;
  final ValueChanged<MemoCardAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = actions
        .where((item) => item.section == MemoCardActionMenuSection.primary)
        .toList(growable: false);
    final secondary = actions
        .where((item) => item.section == MemoCardActionMenuSection.secondary)
        .toList(growable: false);
    final danger = actions
        .where((item) => item.section == MemoCardActionMenuSection.danger)
        .toList(growable: false);
    final textColor = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE8D8D4);
    final surfaceColor = isDark ? const Color(0xFF2B2523) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE9DAD6);

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(_scaled(24)),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              blurRadius: _scaled(28),
              offset: Offset(0, _scaled(14)),
              color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_scaled(24)),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                _scaled(20),
                0,
                _scaled(20),
                _scaled(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (primary.isNotEmpty)
                    _MemoCardActionPrimaryGrid(
                      actions: primary,
                      textColor: textColor,
                      onSelected: onSelected,
                    ),
                  if (secondary.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.zero,
                      child: Divider(height: 1, color: dividerColor),
                    ),
                    _MemoCardActionSecondaryList(
                      actions: secondary,
                      textColor: textColor,
                      onSelected: onSelected,
                    ),
                  ],
                  if (danger.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: _scaled(16)),
                      child: Divider(height: 1, color: dividerColor),
                    ),
                    _MemoCardActionDangerList(
                      actions: danger,
                      onSelected: onSelected,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoCardActionPrimaryGrid extends StatelessWidget {
  const _MemoCardActionPrimaryGrid({
    required this.actions,
    required this.textColor,
    required this.onSelected,
  });

  final List<MemoCardActionDescriptor> actions;
  final Color textColor;
  final ValueChanged<MemoCardAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      key: memoCardActionPrimarySectionKey,
      crossAxisCount: 3,
      padding: const EdgeInsets.fromLTRB(0, 7, 0, 2),
      mainAxisSpacing: _scaled(8),
      crossAxisSpacing: _scaled(8),
      childAspectRatio: 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final action in actions)
          _MemoCardPrimaryActionTile(
            descriptor: action,
            textColor: textColor,
            onSelected: onSelected,
          ),
      ],
    );
  }
}

class _MemoCardPrimaryActionTile extends StatelessWidget {
  const _MemoCardPrimaryActionTile({
    required this.descriptor,
    required this.textColor,
    required this.onSelected,
  });

  final MemoCardActionDescriptor descriptor;
  final Color textColor;
  final ValueChanged<MemoCardAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = MemoFlowPalette.primary;
    return Semantics(
      button: true,
      label: descriptor.label,
      child: InkWell(
        key: memoCardActionItemKey(descriptor.action),
        borderRadius: BorderRadius.circular(_scaled(18)),
        onTap: () => onSelected(descriptor.action),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: _scaled(4)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: _scaled(54),
                height: _scaled(54),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
                ),
                child: Icon(
                  descriptor.icon,
                  size: _scaled(26),
                  color: textColor,
                ),
              ),
              SizedBox(height: _scaled(8)),
              Text(
                descriptor.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: _scaled(15),
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoCardActionSecondaryList extends StatelessWidget {
  const _MemoCardActionSecondaryList({
    required this.actions,
    required this.textColor,
    required this.onSelected,
  });

  final List<MemoCardActionDescriptor> actions;
  final Color textColor;
  final ValueChanged<MemoCardAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: memoCardActionSecondarySectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t.strings.collections.reader.moreSettingsTitle,
          style: TextStyle(
            fontSize: _scaled(13),
            fontWeight: FontWeight.w600,
            color: textColor.withValues(alpha: 0.46),
          ),
        ),
        SizedBox(height: _scaled(10)),
        for (final action in actions)
          _MemoCardListActionTile(
            descriptor: action,
            textColor: textColor,
            onSelected: onSelected,
          ),
      ],
    );
  }
}

class _MemoCardActionDangerList extends StatelessWidget {
  const _MemoCardActionDangerList({
    required this.actions,
    required this.onSelected,
  });

  final List<MemoCardActionDescriptor> actions;
  final ValueChanged<MemoCardAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dangerColor = isDark
        ? const Color(0xFFFF7A7A)
        : const Color(0xFFE05656);
    return Column(
      key: memoCardActionDangerSectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final action in actions)
          _MemoCardListActionTile(
            descriptor: action,
            textColor: dangerColor,
            onSelected: onSelected,
          ),
      ],
    );
  }
}

class _MemoCardListActionTile extends StatelessWidget {
  const _MemoCardListActionTile({
    required this.descriptor,
    required this.textColor,
    required this.onSelected,
  });

  final MemoCardActionDescriptor descriptor;
  final Color textColor;
  final ValueChanged<MemoCardAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: descriptor.label,
      child: InkWell(
        key: memoCardActionItemKey(descriptor.action),
        borderRadius: BorderRadius.circular(_scaled(12)),
        onTap: () => onSelected(descriptor.action),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: _scaled(10)),
          child: Row(
            children: [
              Icon(descriptor.icon, size: _scaled(25), color: textColor),
              SizedBox(width: _scaled(16)),
              Expanded(
                child: Text(
                  descriptor.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _scaled(15),
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              if (descriptor.showChevron)
                Icon(Icons.chevron_right, size: _scaled(24), color: textColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoCardActionPopoverLayoutDelegate extends SingleChildLayoutDelegate {
  const _MemoCardActionPopoverLayoutDelegate({
    required this.anchorRect,
    required this.padding,
  });

  final Rect anchorRect;
  final EdgeInsets padding;

  static final double _edgePadding = _scaled(12);
  static final double _gap = _scaled(8);
  static final double _maxWidth = _scaled(344);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = math.max(
      0.0,
      math.min(
        _maxWidth,
        constraints.maxWidth - padding.horizontal - (_edgePadding * 2),
      ),
    );
    final maxHeight = math.max(
      0.0,
      constraints.maxHeight - padding.vertical - (_edgePadding * 2),
    );
    return BoxConstraints(
      minWidth: math.min(_scaled(280), maxWidth),
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final minLeft = padding.left + _edgePadding;
    final maxLeft = math.max(
      minLeft,
      size.width - padding.right - childSize.width - _edgePadding,
    );
    var left = anchorRect.right - childSize.width;
    left = left.clamp(minLeft, maxLeft).toDouble();

    final minTop = padding.top + _edgePadding;
    final maxTop = math.max(
      minTop,
      size.height - padding.bottom - childSize.height - _edgePadding,
    );
    var top = anchorRect.bottom + _gap;
    if (top + childSize.height > size.height - padding.bottom - _edgePadding) {
      top = anchorRect.top - childSize.height - _gap;
    }
    top = top.clamp(minTop, maxTop).toDouble();
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_MemoCardActionPopoverLayoutDelegate oldDelegate) {
    return anchorRect != oldDelegate.anchorRect ||
        padding != oldDelegate.padding;
  }
}
