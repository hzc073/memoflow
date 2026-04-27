import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/app_motion.dart';
import '../../../core/memoflow_palette.dart';

class WindowsDesktopCommandBar extends StatelessWidget {
  const WindowsDesktopCommandBar({
    super.key,
    required this.leading,
    required this.center,
    required this.trailing,
    this.debugBadgeText,
    required this.desktopWindowMaximized,
    this.showWindowControls = true,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onClose,
    required this.minimizeTooltip,
    required this.maximizeTooltip,
    required this.restoreTooltip,
    required this.closeTooltip,
  });

  final Widget leading;
  final Widget center;
  final Widget trailing;
  final String? debugBadgeText;
  final bool desktopWindowMaximized;
  final bool showWindowControls;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onClose;
  final String minimizeTooltip;
  final String maximizeTooltip;
  final String restoreTooltip;
  final String closeTooltip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    final badgeText = debugBadgeText?.trim() ?? '';

    return Material(
      color: barBg,
      child: Container(
        key: const ValueKey<String>('windows-desktop-command-bar'),
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: barBg,
          border: Border(bottom: BorderSide(color: divider)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DragToMoveArea(child: SizedBox.expand()),
            Row(
              children: [
                Expanded(flex: 3, child: leading),
                Expanded(
                  flex: 5,
                  child: Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: center,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: trailing),
                        if (badgeText.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _DebugBadge(text: badgeText),
                        ],
                        if (showWindowControls) ...[
                          const SizedBox(width: 8),
                          _WindowControlButton(
                            tooltip: minimizeTooltip,
                            onPressed: onMinimize,
                            icon: Icons.minimize_rounded,
                          ),
                          _WindowControlButton(
                            tooltip: desktopWindowMaximized
                                ? restoreTooltip
                                : maximizeTooltip,
                            onPressed: onToggleMaximize,
                            icon: desktopWindowMaximized
                                ? Icons.filter_none_rounded
                                : Icons.crop_square_rounded,
                          ),
                          _WindowControlButton(
                            tooltip: closeTooltip,
                            onPressed: onClose,
                            icon: Icons.close_rounded,
                            destructive: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugBadge extends StatelessWidget {
  const _DebugBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: MemoFlowPalette.primary.withValues(alpha: isDark ? 0.24 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: MemoFlowPalette.primary.withValues(
            alpha: isDark ? 0.45 : 0.25,
          ),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: MemoFlowPalette.primary,
        ),
      ),
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  const _WindowControlButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.destructive = false,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final bool destructive;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = widget.destructive
        ? (isDark ? const Color(0xFFFFB4B4) : const Color(0xFFC62828))
        : (isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight);
    final hoverColor = widget.destructive
        ? const Color(0x33E53935)
        : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06));
    final pressedColor = widget.destructive
        ? const Color(0x55E53935)
        : (isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.1));
    final backgroundColor = _pressed
        ? pressedColor
        : (_hovered ? hoverColor : Colors.transparent);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) {
          _setHovered(false);
          _setPressed(false);
        },
        child: Listener(
          onPointerDown: (_) => _setPressed(true),
          onPointerUp: (_) => _setPressed(false),
          onPointerCancel: (_) => _setPressed(false),
          child: AnimatedContainer(
            duration: AppMotion.effectiveDuration(
              context,
              _pressed ? AppMotion.desktopPressDown : AppMotion.windowsHover,
            ),
            curve: AppMotion.emphasizedEnterCurve,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                hoverColor: Colors.transparent,
                onTap: widget.onPressed,
                child: SizedBox(
                  width: 38,
                  height: 32,
                  child: Icon(widget.icon, size: 18, color: iconColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
