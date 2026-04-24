import 'dart:async';
import 'dart:math' as math;

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
    with TickerProviderStateMixin {
  static const Color backgroundColor = SplashTokens.backgroundColor;
  static const Color primaryColor = SplashTokens.brandColor;
  static const String _logoAsset = SplashTokens.logoAsset;
  static const int _typewriterMsPerChar = startupTypewriterMsPerChar;
  static const Duration _liquidLoopDuration = Duration(milliseconds: 2600);
  static const Duration _liquidStartDelay = Duration(milliseconds: 180);
  static const ValueKey<String> _logoKey = ValueKey<String>('startup-logo');

  AnimationController? _typewriterController;
  AnimationController? _liquidController;
  Timer? _liquidStartTimer;
  int? _lastSloganLength;
  bool _hasRenderedFirstFrame = false;
  bool _isLiquidOverlayEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hasRenderedFirstFrame = true;
      _scheduleLiquidOverlay();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
    _syncTypewriter();
  }

  @override
  void didUpdateWidget(StartupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTypewriter(forceRestart: widget.showSlogan && !oldWidget.showSlogan);
  }

  @override
  void dispose() {
    _liquidStartTimer?.cancel();
    _typewriterController?.dispose();
    _liquidController?.dispose();
    super.dispose();
  }

  String _sloganText(BuildContext context) =>
      context.t.strings.legacy.msg_startup_slogan;

  void _syncMotion() {
    final motionEnabled = AppMotion.isEnabled(context);
    if (!motionEnabled) {
      _liquidStartTimer?.cancel();
      _liquidStartTimer = null;
      _isLiquidOverlayEnabled = false;
      _liquidController?.stop();
      _liquidController?.value = 0;
      return;
    }
    if (!_isLiquidOverlayEnabled) {
      _scheduleLiquidOverlay();
      return;
    }
    _liquidController ??= AnimationController(
      vsync: this,
      duration: _liquidLoopDuration,
    );
    if (!_liquidController!.isAnimating) {
      _liquidController!.repeat();
    }
  }

  void _scheduleLiquidOverlay() {
    if (!_hasRenderedFirstFrame ||
        !AppMotion.isEnabled(context) ||
        _isLiquidOverlayEnabled ||
        _liquidStartTimer != null) {
      return;
    }
    _liquidStartTimer = Timer(_liquidStartDelay, () {
      _liquidStartTimer = null;
      if (!mounted || !AppMotion.isEnabled(context)) return;
      _isLiquidOverlayEnabled = true;
      _syncMotion();
      setState(() {});
    });
  }

  void _syncTypewriter({bool forceRestart = false}) {
    final sloganLength = _sloganText(context).runes.length;
    if (!widget.showSlogan || !AppMotion.isEnabled(context)) {
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

  Widget _buildLogo() {
    final controller = _liquidController;
    if (!AppMotion.isEnabled(context) || controller == null) {
      return _buildLogoAsset();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildLogoAsset(),
        IgnorePointer(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, child) =>
                _StartupLiquidOverlay(progress: controller.value),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoAsset() {
    return Image.asset(
      _logoAsset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final scale = (shortestSide / 375).clamp(0.85, 1.1).toDouble();
    final logoSize = 176 * scale;
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
                child: _buildLogo(),
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

class _StartupLiquidOverlay extends StatelessWidget {
  const _StartupLiquidOverlay({required this.progress});

  final double progress;

  static const Color _primaryColor = SplashTokens.brandColor;
  static const String _logoAsset = SplashTokens.logoAsset;

  @override
  Widget build(BuildContext context) {
    final waveOffsetA = math.sin(progress * math.pi * 2) * 0.18;
    final waveOffsetB = math.cos((progress * math.pi * 2) + 0.9) * 0.16;
    final glowOffset = math.sin((progress * math.pi * 2 * 0.7) - 0.6) * 0.22;

    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 0.28,
          child: _buildMaskedLayer(
            begin: Alignment(-0.95 + waveOffsetA, -0.72),
            end: Alignment(0.82 + waveOffsetA, 0.96),
            colors: [
              Colors.white.withValues(alpha: 0.00),
              Colors.white.withValues(alpha: 0.72),
              _primaryColor.withValues(alpha: 0.34),
              _primaryColor.withValues(alpha: 0.00),
            ],
            stops: const [0.02, 0.30, 0.68, 1.0],
          ),
        ),
        Opacity(
          opacity: 0.22,
          child: _buildMaskedLayer(
            begin: Alignment(-0.82 + waveOffsetB, 0.88),
            end: Alignment(1.02 + waveOffsetB, -0.76),
            colors: [
              Colors.white.withValues(alpha: 0.00),
              _primaryColor.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0.64),
              Colors.white.withValues(alpha: 0.00),
            ],
            stops: const [0.08, 0.38, 0.60, 0.98],
          ),
        ),
        Opacity(
          opacity: 0.18,
          child: _buildMaskedLayer(
            begin: Alignment(-0.30 + glowOffset, -1.0),
            end: Alignment(0.64 + glowOffset, 0.52),
            colors: [
              Colors.white.withValues(alpha: 0.00),
              Colors.white.withValues(alpha: 0.85),
              Colors.white.withValues(alpha: 0.00),
            ],
            stops: const [0.18, 0.52, 0.88],
          ),
        ),
      ],
    );
  }

  Widget _buildMaskedLayer({
    required Alignment begin,
    required Alignment end,
    required List<Color> colors,
    required List<double> stops,
  }) {
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: begin,
          end: end,
          colors: colors,
          stops: stops,
        ).createShader(bounds);
      },
      child: Image.asset(
        _logoAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
