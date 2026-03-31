import 'package:flutter/material.dart';
import '../../core/app_localization.dart';
import '../../data/models/memo_toolbar_preferences.dart';
import '../../i18n/strings.g.dart';
import 'memo_toolbar_custom_icon_catalog.dart';

export '../../data/models/memo_toolbar_preferences.dart';

enum MemoComposeTodoShortcutAction { checkbox, codeBlock }

class MemoComposeToolbarActionSpec {
  const MemoComposeToolbarActionSpec({
    required this.id,
    this.buttonKey,
    this.icon,
    this.label,
    this.onPressed,
    this.enabled = true,
    this.supported = true,
  });

  factory MemoComposeToolbarActionSpec.builtin({
    required MemoToolbarActionId id,
    Key? buttonKey,
    IconData? icon,
    String? label,
    VoidCallback? onPressed,
    bool enabled = true,
    bool supported = true,
  }) {
    return MemoComposeToolbarActionSpec(
      id: id.itemId,
      buttonKey: buttonKey,
      icon: icon,
      label: label,
      onPressed: onPressed,
      enabled: enabled,
      supported: supported,
    );
  }

  factory MemoComposeToolbarActionSpec.custom({
    required MemoToolbarCustomButton button,
    Key? buttonKey,
    IconData? icon,
    String? label,
    VoidCallback? onPressed,
    bool enabled = true,
    bool supported = true,
  }) {
    return MemoComposeToolbarActionSpec(
      id: button.itemId,
      buttonKey: buttonKey,
      icon: icon ?? resolveMemoToolbarCustomIcon(button.iconKey),
      label: label ?? button.label,
      onPressed: onPressed,
      enabled: enabled,
      supported: supported,
    );
  }

  final MemoToolbarItemId id;
  final Key? buttonKey;
  final IconData? icon;
  final String? label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool supported;
}

extension MemoToolbarActionPresentationX on MemoToolbarActionId {
  IconData get icon {
    return switch (this) {
      MemoToolbarActionId.bold => Icons.format_bold,
      MemoToolbarActionId.italic => Icons.format_italic,
      MemoToolbarActionId.strikethrough => Icons.format_strikethrough,
      MemoToolbarActionId.inlineCode => Icons.code,
      MemoToolbarActionId.list => Icons.format_list_bulleted,
      MemoToolbarActionId.orderedList => Icons.format_list_numbered,
      MemoToolbarActionId.taskList => Icons.check_box_outlined,
      MemoToolbarActionId.quote => Icons.format_quote,
      MemoToolbarActionId.heading1 => Icons.looks_one_outlined,
      MemoToolbarActionId.heading2 => Icons.looks_two_outlined,
      MemoToolbarActionId.heading3 => Icons.looks_3_outlined,
      MemoToolbarActionId.underline => Icons.format_underlined,
      MemoToolbarActionId.highlight => Icons.highlight_alt,
      MemoToolbarActionId.divider => Icons.horizontal_rule,
      MemoToolbarActionId.codeBlock => Icons.data_object,
      MemoToolbarActionId.inlineMath => Icons.functions,
      MemoToolbarActionId.blockMath => Icons.calculate_outlined,
      MemoToolbarActionId.table => Icons.table_chart_outlined,
      MemoToolbarActionId.cutParagraph => Icons.content_cut,
      MemoToolbarActionId.undo => Icons.undo,
      MemoToolbarActionId.redo => Icons.redo,
      MemoToolbarActionId.tag => Icons.tag,
      MemoToolbarActionId.template => Icons.description_outlined,
      MemoToolbarActionId.attachment => Icons.attach_file,
      MemoToolbarActionId.gallery => Icons.photo_library_outlined,
      MemoToolbarActionId.todo => Icons.playlist_add_check,
      MemoToolbarActionId.link => Icons.alternate_email_rounded,
      MemoToolbarActionId.camera => Icons.photo_camera_outlined,
      MemoToolbarActionId.location => Icons.place_outlined,
      MemoToolbarActionId.draftBox => Icons.inventory_2_outlined,
    };
  }

  String label(BuildContext context) {
    final legacy = context.t.strings.legacy;
    final toolbar = context.t.strings.settings.preferences.editorToolbar;
    return switch (this) {
      MemoToolbarActionId.bold => legacy.msg_bold,
      MemoToolbarActionId.italic => toolbar.actions.italic,
      MemoToolbarActionId.strikethrough => toolbar.actions.strikethrough,
      MemoToolbarActionId.inlineCode => toolbar.actions.inlineCode,
      MemoToolbarActionId.list => toolbar.actions.bulletedList,
      MemoToolbarActionId.orderedList => legacy.msg_ordered_list,
      MemoToolbarActionId.taskList => toolbar.actions.taskList,
      MemoToolbarActionId.quote => toolbar.actions.quote,
      MemoToolbarActionId.heading1 => toolbar.actions.heading1,
      MemoToolbarActionId.heading2 => toolbar.actions.heading2,
      MemoToolbarActionId.heading3 => toolbar.actions.heading3,
      MemoToolbarActionId.underline => legacy.msg_underline,
      MemoToolbarActionId.highlight => legacy.msg_highlight,
      MemoToolbarActionId.divider => toolbar.actions.divider,
      MemoToolbarActionId.codeBlock => legacy.msg_code_block,
      MemoToolbarActionId.inlineMath => toolbar.actions.inlineMath,
      MemoToolbarActionId.blockMath => toolbar.actions.blockMath,
      MemoToolbarActionId.table => toolbar.actions.table,
      MemoToolbarActionId.cutParagraph => toolbar.actions.cutParagraph,
      MemoToolbarActionId.undo => legacy.msg_undo,
      MemoToolbarActionId.redo => legacy.msg_redo,
      MemoToolbarActionId.tag => legacy.msg_tag,
      MemoToolbarActionId.template => legacy.msg_template,
      MemoToolbarActionId.attachment => legacy.msg_attachment,
      MemoToolbarActionId.gallery => toolbar.actions.gallery,
      MemoToolbarActionId.todo => legacy.msg_todo,
      MemoToolbarActionId.link => legacy.msg_link,
      MemoToolbarActionId.camera => legacy.msg_capture_photo,
      MemoToolbarActionId.location => legacy.msg_location_2,
      MemoToolbarActionId.draftBox => context.tr(zh: '草稿箱', en: 'Draft Box'),
    };
  }
}

extension MemoToolbarItemPresentationX on MemoToolbarItemId {
  IconData resolveIcon(MemoToolbarPreferences preferences) {
    final builtinAction = this.builtinAction;
    if (builtinAction != null) return builtinAction.icon;
    final customButton = preferences.customButtonForItem(this);
    if (customButton != null) {
      return resolveMemoToolbarCustomIcon(customButton.iconKey);
    }
    return Icons.extension_rounded;
  }

  String resolveLabel(
    BuildContext context,
    MemoToolbarPreferences preferences,
  ) {
    final builtinAction = this.builtinAction;
    if (builtinAction != null) return builtinAction.label(context);
    return preferences.customButtonForItem(this)?.label ?? storageValue;
  }
}

class MemoComposeToolbar extends StatelessWidget {
  const MemoComposeToolbar({
    super.key,
    required this.isDark,
    required this.preferences,
    required this.actions,
    required this.visibilityMessage,
    required this.visibilityIcon,
    required this.visibilityColor,
    required this.visibilityButtonKey,
    required this.onVisibilityPressed,
  });

  static const topRowKey = ValueKey<String>('memo-compose-toolbar-top-row');
  static const bottomRowKey = ValueKey<String>(
    'memo-compose-toolbar-bottom-row',
  );

  final bool isDark;
  final MemoToolbarPreferences preferences;
  final List<MemoComposeToolbarActionSpec> actions;
  final String visibilityMessage;
  final IconData visibilityIcon;
  final Color visibilityColor;
  final Key visibilityButtonKey;
  final VoidCallback? onVisibilityPressed;

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? Colors.white70 : Colors.black54;
    final disabledColor = iconColor.withValues(alpha: 0.45);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);
    final visibilityBackgroundColor = visibilityColor.withValues(
      alpha: isDark ? 0.16 : 0.1,
    );

    final actionMap = <MemoToolbarItemId, MemoComposeToolbarActionSpec>{
      for (final action in actions) action.id: action,
    };
    final supportedItems = actions
        .where((action) => action.supported)
        .map((action) => action.id)
        .toSet();

    final topActions = preferences
        .visibleItemIdsForRow(
          MemoToolbarRow.top,
          supportedItems: supportedItems,
        )
        .map((id) => actionMap[id])
        .whereType<MemoComposeToolbarActionSpec>()
        .toList(growable: false);
    final bottomActions = preferences
        .visibleItemIdsForRow(
          MemoToolbarRow.bottom,
          supportedItems: supportedItems,
        )
        .map((id) => actionMap[id])
        .whereType<MemoComposeToolbarActionSpec>()
        .toList(growable: false);

    Widget buildActionButton(MemoComposeToolbarActionSpec action) {
      final tooltip =
          action.label ?? action.id.resolveLabel(context, preferences);
      final actionIcon = action.icon ?? action.id.resolveIcon(preferences);
      return IconButton(
        key: action.buttonKey,
        tooltip: tooltip,
        onPressed: action.enabled ? action.onPressed : null,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        splashRadius: 18,
        icon: Icon(
          actionIcon,
          size: 20,
          color: action.enabled ? iconColor : disabledColor,
        ),
      );
    }

    Widget buildRow(List<MemoComposeToolbarActionSpec> rowActions, Key key) {
      return Row(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rowActions.length; i++) ...[
            buildActionButton(rowActions[i]),
            if (i != rowActions.length - 1) const SizedBox(width: 6),
          ],
        ],
      );
    }

    final hasToolbarActions = topActions.isNotEmpty || bottomActions.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: hasToolbarActions
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (topActions.isNotEmpty)
                          buildRow(topActions, MemoComposeToolbar.topRowKey),
                        if (topActions.isNotEmpty && bottomActions.isNotEmpty)
                          const SizedBox(height: 6),
                        if (bottomActions.isNotEmpty)
                          buildRow(
                            bottomActions,
                            MemoComposeToolbar.bottomRowKey,
                          ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 12),
        Container(width: 1, height: 30, color: dividerColor),
        const SizedBox(width: 12),
        Tooltip(
          message: visibilityMessage,
          child: InkResponse(
            key: visibilityButtonKey,
            onTap: onVisibilityPressed,
            radius: 18,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: visibilityBackgroundColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: visibilityColor.withValues(alpha: isDark ? 0.28 : 0.2),
                ),
              ),
              child: Icon(visibilityIcon, size: 15, color: visibilityColor),
            ),
          ),
        ),
      ],
    );
  }
}
