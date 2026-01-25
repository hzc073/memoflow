import 'dart:io';

import 'package:confetti/confetti.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../state/preferences_provider.dart';

enum _DonationStep { request, success }

class DonationDialog extends ConsumerStatefulWidget {
  const DonationDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const DonationDialog(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<DonationDialog> createState() => _DonationDialogState();
}

class _DonationDialogState extends ConsumerState<DonationDialog>
    with TickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _starsController;
  _DonationStep _step = _DonationStep.request;
  var _savingQr = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _starsController.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).maybePop();
  }

  void _goSuccess() {
    ref.read(appPreferencesProvider.notifier).setSupporterCrownEnabled(true);
    setState(() => _step = _DonationStep.success);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _confettiController.play();
    });
  }

  Future<bool> _ensureGalleryPermission() async {
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt <= 28) {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
      return true;
    }
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    }
    return true;
  }

  bool _isGallerySaveSuccess(dynamic result) {
    if (result is Map) {
      final flag = result['isSuccess'] ?? result['success'];
      if (flag is bool) return flag;
    }
    return result == true;
  }

  Future<void> _saveQrToGallery() async {
    if (_savingQr) return;
    setState(() => _savingQr = true);
    try {
      final allowed = await _ensureGalleryPermission();
      if (!allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(zh: '需要相册权限以保存二维码', en: 'Gallery permission required'),
            ),
          ),
        );
        return;
      }

      final data = await rootBundle.load('assets/images/donation_qr.png');
      final bytes = data.buffer.asUint8List();
      final name =
          'MemoFlow_QR_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
      final result = await ImageGallerySaver.saveImage(
        bytes,
        name: name,
        quality: 100,
      );
      final ok = _isGallerySaveSuccess(result);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(zh: '保存失败', en: 'Save failed'))),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(zh: '二维码已保存到系统相册', en: 'QR saved to gallery'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(zh: '保存失败：$e', en: 'Save failed: $e')),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingQr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F1B18) : Colors.white;
    final surface = isDark ? const Color(0xFF2C2520) : const Color(0xFFF7EFE6);
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.65 : 0.6);
    final accent = MemoFlowPalette.primary;
    final danger = const Color(0xFFC6564A);
    final badgeBg = isDark ? const Color(0xFF233128) : const Color(0xFFE6F4EA);
    final badgeText = isDark
        ? const Color(0xFF9AD1A8)
        : const Color(0xFF3BA55D);

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Stack(
          children: [
            if (_step == _DonationStep.success)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      emissionFrequency: 0.04,
                      numberOfParticles: 28,
                      maxBlastForce: 20,
                      minBlastForce: 8,
                      gravity: 0.28,
                      shouldLoop: false,
                      colors: const [
                        Color(0xFFC0564D),
                        Color(0xFFE1A670),
                        Color(0xFF7E9B8F),
                        Color(0xFFF2C879),
                        Color(0xFFB56C4A),
                      ],
                    ),
                  ),
                ),
              ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.96,
                          end: 1.0,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _step == _DonationStep.request
                      ? _DonationRequestCard(
                          key: const ValueKey('request'),
                          cardColor: cardColor,
                          surface: surface,
                          textMain: textMain,
                          textMuted: textMuted,
                          accent: accent,
                          danger: danger,
                          onSaveQr: _saveQrToGallery,
                          onConfirm: _goSuccess,
                          onCancel: _close,
                        )
                      : _DonationSuccessCard(
                          key: const ValueKey('success'),
                          cardColor: cardColor,
                          textMain: textMain,
                          textMuted: textMuted,
                          accent: accent,
                          badgeBg: badgeBg,
                          badgeText: badgeText,
                          starsController: _starsController,
                          onClose: _close,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonationRequestCard extends StatelessWidget {
  const _DonationRequestCard({
    super.key,
    required this.cardColor,
    required this.surface,
    required this.textMain,
    required this.textMuted,
    required this.accent,
    required this.danger,
    required this.onSaveQr,
    required this.onConfirm,
    required this.onCancel,
  });

  final Color cardColor;
  final Color surface;
  final Color textMain;
  final Color textMuted;
  final Color accent;
  final Color danger;
  final VoidCallback onSaveQr;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final shadow = Colors.black.withValues(alpha: 0.12);
    final border = textMuted.withValues(alpha: 0.18);
    final labelStyle = TextStyle(
      fontSize: 11,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w700,
      color: danger,
    );
    final bodyPrefix = context.tr(
      zh: 'MemoFlow 是我用业余时间肝出来的孩子。目前开发者已连续熬夜修 Bug，急需一杯冰美式“续命”。你的投喂不仅能恢复我的电量，还能让新功能提早 ',
      en: 'MemoFlow is a side project I build in my spare time. I have been up late fixing bugs and could really use an iced Americano. Your support refuels my battery and helps new features ship ',
    );
    final bodySuffix = context.tr(zh: ' 上线！', en: ' sooner!');

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(blurRadius: 28, offset: const Offset(0, 16), color: shadow),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BatteryIcon(color: danger),
          const SizedBox(height: 8),
          Text('bolt 10% ENERGY LEFT', style: labelStyle),
          const SizedBox(height: 6),
          Text(
            context.tr(zh: '能量值告急！', en: 'Energy critically low!'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textMain,
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 12.5, height: 1.45, color: textMuted),
              children: [
                TextSpan(text: bodyPrefix),
                TextSpan(
                  text: '200%',
                  style: TextStyle(fontWeight: FontWeight.w700, color: accent),
                ),
                TextSpan(text: bodySuffix),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          _QrPlaceholder(
            surface: surface,
            border: border,
            textMuted: textMuted,
            onLongPress: onSaveQr,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              zh: '点击确认赞赏后，将解锁限定版金色标识 or 永久去广告承诺（虽然本来就没广告）',
              en: 'After confirming support, you will unlock a limited gold badge or a forever ad-free promise (though there were never ads).',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, height: 1.4, color: textMuted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              icon: const Icon(
                Icons.coffee_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                context.tr(
                  zh: '☕ 这就是我要的咖啡/加个鸡腿',
                  en: '☕ Coffee it is / add a drumstick',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              onPressed: onConfirm,
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onCancel,
            child: Text(
              context.tr(
                zh: '👀 下次一定，先去修 Bug',
                en: '👀 Next time, back to fixing bugs',
              ),
              style: TextStyle(color: textMuted, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonationSuccessCard extends StatelessWidget {
  const _DonationSuccessCard({
    super.key,
    required this.cardColor,
    required this.textMain,
    required this.textMuted,
    required this.accent,
    required this.badgeBg,
    required this.badgeText,
    required this.starsController,
    required this.onClose,
  });

  final Color cardColor;
  final Color textMain;
  final Color textMuted;
  final Color accent;
  final Color badgeBg;
  final Color badgeText;
  final AnimationController starsController;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final shadow = Colors.black.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(blurRadius: 28, offset: const Offset(0, 16), color: shadow),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SparklingCoffee(color: accent, controller: starsController),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              context.tr(zh: '⚡ ENERGY RESTORED', en: '⚡ ENERGY RESTORED'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: badgeText,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              zh: '收到心意！能量已充满 ⚡',
              en: 'Thanks! Energy fully restored ⚡',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              zh: '为了对得起这杯咖啡，今晚我决定不睡了，写它个一百行代码！',
              en: "To deserve this coffee, I'm pulling an all-nighter to write 100 lines of code!",
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.4, color: textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              onPressed: onClose,
              child: Text(
                context.tr(zh: '太棒啦！ ❤️', en: 'Awesome! ❤️'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryIcon extends StatelessWidget {
  const _BatteryIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          Positioned(
            left: 4,
            top: 4,
            bottom: 4,
            child: Container(
              width: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Positioned(
            right: -6,
            top: 8,
            bottom: 8,
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder({
    required this.surface,
    required this.border,
    required this.textMuted,
    this.onLongPress,
  });

  final Color surface;
  final Color border;
  final Color textMuted;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Column(
          children: [
            Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                    color: Colors.black.withValues(alpha: 0.12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/donation_qr.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr(
                zh: '长按保存后打开支付宝扫一扫',
                en: 'Save and open Alipay to scan',
              ),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklingCoffee extends StatelessWidget {
  const _SparklingCoffee({required this.color, required this.controller});

  final Color color;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final starOne = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeInOut),
    );
    final starTwo = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
    );
    return SizedBox(
      width: 96,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.coffee_rounded, size: 48, color: color),
          _TwinkleStar(
            animation: starOne,
            left: 16,
            top: 6,
            size: 14,
            color: color.withValues(alpha: 0.8),
          ),
          _TwinkleStar(
            animation: starTwo,
            left: 60,
            top: 2,
            size: 10,
            color: color.withValues(alpha: 0.7),
          ),
          _TwinkleStar(
            animation: starOne,
            left: 64,
            top: 36,
            size: 8,
            color: color.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}

class _TwinkleStar extends StatelessWidget {
  const _TwinkleStar({
    required this.animation,
    required this.left,
    required this.top,
    required this.size,
    required this.color,
  });

  final Animation<double> animation;
  final double left;
  final double top;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.75, end: 1.1).animate(animation),
          child: Icon(Icons.auto_awesome, size: size, color: color),
        ),
      ),
    );
  }
}
