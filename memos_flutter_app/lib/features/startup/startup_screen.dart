import 'package:flutter/material.dart';

import '../../core/app_motion.dart';
import '../../core/splash_tokens.g.dart';
import '../../i18n/strings.g.dart';

const int startupTypewriterMsPerChar = 160;
const int startupPostTypewriterHoldMs = 500;

int startupMinimumVisibleMsFor({
  required BuildContext context,
  required bool showSlogan,
}) {
  if (!AppMotion.isEnabled(context)) return 0;
  if (!showSlogan) return SplashTokens.startupVisibleMinMs;
  final sloganLength = context.t.strings.legacy.msg_startup_slogan.runes.length;
  return (sloganLength * startupTypewriterMsPerChar) +
      startupPostTypewriterHoldMs;
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key, required this.showSlogan});

  final bool showSlogan;

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with SingleTickerProviderStateMixin {
  static const Color backgroundColor = SplashTokens.backgroundColor;
  static const Color primaryColor = SplashTokens.brandColor;
  static const String _logoAsset = SplashTokens.logoAsset;
  static const int _typewriterMsPerChar = startupTypewriterMsPerChar;
  static const ValueKey<String> _logoKey = ValueKey<String>('startup-logo');

  AnimationController? _typewriterController;
  int? _lastSloganLength;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTypewriter();
  }

  @override
  void didUpdateWidget(StartupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTypewriter(forceRestart: widget.showSlogan && !oldWidget.showSlogan);
  }

  @override
  void dispose() {
    _typewriterController?.dispose();
    super.dispose();
  }

  String _sloganText(BuildContext context) =>
      context.t.strings.legacy.msg_startup_slogan;

  void _syncTypewriter({bool forceRestart = false}) {
    final sloganLength = _sloganText(context).runes.length;
    if (!widget.showSlogan) {
      _typewriterController?.dispose();
      _typewriterController = null;
      _lastSloganLength = sloganLength;
      return;
    }
    if (forceRestart ||
        _typewriterController == null ||
        _lastSloganLength != sloganLength) {
      _startTypewriter(sloganLength);
    }
    _lastSloganLength = sloganLength;
  }

  void _startTypewriter(int sloganLength) {
    _typewriterController?.dispose();
    final durationMs = sloganLength * _typewriterMsPerChar;
    _typewriterController =
        AnimationController(
          vsync: this,
          duration: Duration(milliseconds: durationMs),
        )..addListener(() {
          if (!mounted) return;
          setState(() {});
        });
    _typewriterController?.forward();
  }

  String _currentSloganText(BuildContext context) {
    if (!widget.showSlogan) return '';
    final sloganRunes = _sloganText(context).runes.toList();
    final controller = _typewriterController;
    if (controller == null) return String.fromCharCodes(sloganRunes);
    final total = sloganRunes.length;
    var count = (total * controller.value).floor();
    if (count < 0) count = 0;
    if (count > total) count = total;
    if (count == 0) return '';
    return String.fromCharCodes(sloganRunes.sublist(0, count));
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final scale = (shortestSide / 375).clamp(0.85, 1.1).toDouble();
    final logoSize = 144 * scale;
    final sloganSize = 14 * scale;
    final memoFlowSize = (sloganSize - (2 * scale)).clamp(10.0, sloganSize);
    final sloganPadding = 48 * scale;
    final textGap = 6 * scale;

    return ColoredBox(
      color: backgroundColor,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: SizedBox.square(
                key: _logoKey,
                dimension: logoSize,
                child: Image.asset(
                  _logoAsset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: sloganPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showSlogan)
                    Text(
                      _currentSloganText(context),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: primaryColor.withValues(alpha: 0.85),
                        fontSize: sloganSize,
                        letterSpacing: 1.2,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  SizedBox(height: widget.showSlogan ? textGap : 0),
                  Text(
                    'MemoFlow',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: memoFlowSize,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
