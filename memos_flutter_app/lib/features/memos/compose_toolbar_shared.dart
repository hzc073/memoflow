import 'package:flutter/material.dart';

enum MemoComposePrimaryAction { tag, template, attachment, todo, link }

const kMemoComposePrimaryActions = <MemoComposePrimaryAction>[
  MemoComposePrimaryAction.tag,
  MemoComposePrimaryAction.template,
  MemoComposePrimaryAction.attachment,
  MemoComposePrimaryAction.todo,
  MemoComposePrimaryAction.link,
];

extension MemoComposePrimaryActionX on MemoComposePrimaryAction {
  IconData get icon {
    return switch (this) {
      MemoComposePrimaryAction.tag => Icons.tag,
      MemoComposePrimaryAction.template => Icons.description_outlined,
      MemoComposePrimaryAction.attachment => Icons.attach_file,
      MemoComposePrimaryAction.todo => Icons.playlist_add_check,
      MemoComposePrimaryAction.link => Icons.alternate_email_rounded,
    };
  }

  String get tooltip {
    return switch (this) {
      MemoComposePrimaryAction.tag => 'Tag',
      MemoComposePrimaryAction.template => '模板',
      MemoComposePrimaryAction.attachment => 'Attachment',
      MemoComposePrimaryAction.todo => 'Todo',
      MemoComposePrimaryAction.link => 'Link',
    };
  }
}

enum MemoComposeTodoShortcutAction { checkbox, codeBlock }

class MemoComposePrimaryToolbar extends StatelessWidget {
  const MemoComposePrimaryToolbar({
    super.key,
    required this.isDark,
    required this.busy,
    required this.moreOpen,
    required this.visibilityMessage,
    required this.visibilityIcon,
    required this.visibilityColor,
    required this.tagButtonKey,
    required this.todoButtonKey,
    required this.templateButtonKey,
    required this.visibilityButtonKey,
    required this.onTagPressed,
    required this.onTemplatePressed,
    required this.onAttachmentPressed,
    required this.onTodoPressed,
    required this.onLinkPressed,
    required this.onToggleMorePressed,
    required this.onVisibilityPressed,
  });

  final bool isDark;
  final bool busy;
  final bool moreOpen;
  final String visibilityMessage;
  final IconData visibilityIcon;
  final Color visibilityColor;
  final Key tagButtonKey;
  final Key templateButtonKey;
  final Key todoButtonKey;
  final Key visibilityButtonKey;
  final VoidCallback? onTagPressed;
  final VoidCallback? onTemplatePressed;
  final VoidCallback? onAttachmentPressed;
  final VoidCallback? onTodoPressed;
  final VoidCallback? onLinkPressed;
  final VoidCallback? onToggleMorePressed;
  final VoidCallback? onVisibilityPressed;

  @override
  Widget build(BuildContext context) {
    final toolbarIconColor = isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);
    final moreBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final moreBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          IconButton(
            key: tagButtonKey,
            tooltip: MemoComposePrimaryAction.tag.tooltip,
            onPressed: busy ? null : onTagPressed,
            icon: Icon(
              MemoComposePrimaryAction.tag.icon,
              color: toolbarIconColor,
            ),
          ),
          IconButton(
            key: templateButtonKey,
            tooltip: MemoComposePrimaryAction.template.tooltip,
            onPressed: busy ? null : onTemplatePressed,
            icon: Icon(
              MemoComposePrimaryAction.template.icon,
              color: toolbarIconColor,
            ),
          ),
          IconButton(
            tooltip: MemoComposePrimaryAction.attachment.tooltip,
            onPressed: busy ? null : onAttachmentPressed,
            icon: Icon(
              MemoComposePrimaryAction.attachment.icon,
              color: toolbarIconColor,
            ),
          ),
          IconButton(
            key: todoButtonKey,
            tooltip: MemoComposePrimaryAction.todo.tooltip,
            onPressed: busy ? null : onTodoPressed,
            icon: Icon(
              MemoComposePrimaryAction.todo.icon,
              color: toolbarIconColor,
            ),
          ),
          IconButton(
            tooltip: MemoComposePrimaryAction.link.tooltip,
            onPressed: busy ? null : onLinkPressed,
            icon: Icon(
              MemoComposePrimaryAction.link.icon,
              color: toolbarIconColor,
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: moreOpen ? moreBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: moreOpen ? Border.all(color: moreBorder, width: 1) : null,
            ),
            child: IconButton(
              tooltip: 'More',
              onPressed: busy ? null : onToggleMorePressed,
              icon: Icon(Icons.more_horiz, color: toolbarIconColor),
            ),
          ),
          Container(width: 1, height: 20, color: dividerColor),
          const SizedBox(width: 10),
          Tooltip(
            message: visibilityMessage,
            child: InkResponse(
              key: visibilityButtonKey,
              onTap: busy ? null : onVisibilityPressed,
              radius: 18,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: visibilityColor.withValues(alpha: 0.85),
                    width: 1.6,
                  ),
                ),
                child: Icon(visibilityIcon, size: 14, color: visibilityColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MemoComposeMoreToolbar extends StatelessWidget {
  const MemoComposeMoreToolbar({
    super.key,
    required this.isDark,
    required this.busy,
    this.onBoldPressed,
    this.onListPressed,
    this.onUnderlinePressed,
    this.onCameraPressed,
    this.onLocationPressed,
    this.onUndoPressed,
    this.onRedoPressed,
    this.undoEnabled = false,
    this.redoEnabled = false,
    this.locationBusy = false,
  });

  final bool isDark;
  final bool busy;
  final VoidCallback? onBoldPressed;
  final VoidCallback? onListPressed;
  final VoidCallback? onUnderlinePressed;
  final VoidCallback? onCameraPressed;
  final VoidCallback? onLocationPressed;
  final VoidCallback? onUndoPressed;
  final VoidCallback? onRedoPressed;
  final bool undoEnabled;
  final bool redoEnabled;
  final bool locationBusy;

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? Colors.white70 : Colors.black54;
    final disabledColor = iconColor.withValues(alpha: 0.45);
    const gap = 6.0;
    const horizontalPadding = 10.0;
    const verticalPadding = 6.0;
    const iconButtonSize = 32.0;
    final canEdit = !busy;

    Widget actionButton({
      required IconData icon,
      required VoidCallback? onPressed,
      bool enabled = true,
    }) {
      return IconButton(
        icon: Icon(icon, size: 20, color: enabled ? iconColor : disabledColor),
        onPressed: enabled ? onPressed : null,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: iconButtonSize,
          height: iconButtonSize,
        ),
        splashRadius: 18,
      );
    }

    final actions = <Widget>[];

    void addAction({
      required IconData icon,
      required VoidCallback? onPressed,
      bool enabled = true,
    }) {
      if (onPressed == null) return;
      if (actions.isNotEmpty) {
        actions.add(const SizedBox(width: gap));
      }
      actions.add(
        actionButton(icon: icon, onPressed: onPressed, enabled: enabled),
      );
    }

    addAction(
      icon: Icons.format_bold,
      onPressed: onBoldPressed,
      enabled: canEdit,
    );
    addAction(
      icon: Icons.format_list_bulleted,
      onPressed: onListPressed,
      enabled: canEdit,
    );
    addAction(
      icon: Icons.format_underlined,
      onPressed: onUnderlinePressed,
      enabled: canEdit,
    );
    addAction(
      icon: Icons.photo_camera_outlined,
      onPressed: onCameraPressed,
      enabled: canEdit,
    );
    addAction(
      icon: locationBusy ? Icons.my_location : Icons.place_outlined,
      onPressed: onLocationPressed,
      enabled: canEdit && !locationBusy,
    );
    addAction(
      icon: Icons.undo,
      onPressed: onUndoPressed,
      enabled: canEdit && undoEnabled,
    );
    addAction(
      icon: Icons.redo,
      onPressed: onRedoPressed,
      enabled: canEdit && redoEnabled,
    );

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2B2B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(mainAxisSize: MainAxisSize.min, children: actions),
      ),
    );
  }
}
