import 'dart:async';

import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    required this.nextBuilder,
    this.delay = const Duration(milliseconds: 2400),
  });

  final WidgetBuilder nextBuilder;
  final Duration delay;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.nextBuilder),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SplashContent();
  }
}

class SplashContent extends StatelessWidget {
  const SplashContent({super.key});

  static const _background = Color(0xFFF7F5F0);
  static const _titleColor = Color(0xFF3C3C3C);
  static const _subtitleColor = Color(0xFF9C9489);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/splash/splash_logo.png',
                      width: 72,
                      height: 72,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'MemoFlow',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: _titleColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 48, left: 24, right: 24),
              child: Column(
                children: const [
                  Text(
                    'CAPTURE THE FLOW OF THOUGHT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.6,
                      color: _subtitleColor,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '捕捉思绪的流动',
                    locale: const Locale('zh'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.6,
                      color: _subtitleColor,
                      fontFamilyFallback: [
                        'Noto Sans SC',
                        'PingFang SC',
                        'Microsoft YaHei',
                        'sans-serif',
                      ],
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
