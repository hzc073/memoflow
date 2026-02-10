import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../state/app_lock_provider.dart';
import '../../i18n/strings.g.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(appLockProvider.notifier);
    switch (state) {
      case AppLifecycleState.resumed:
        notifier.handleAppResumed();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        notifier.recordBackgrounded();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final lockState = ref.watch(appLockProvider);
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (lockState.locked)
              const Positioned.fill(
                child: PopScope(
                  canPop: false,
                  child: _AppLockOverlay(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AppLockOverlay extends ConsumerStatefulWidget {
  const _AppLockOverlay();

  @override
  ConsumerState<_AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends ConsumerState<_AppLockOverlay> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _error;
  var _unlocking = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Ensure the password field steals focus from any underlying editor.
      FocusManager.instance.primaryFocus?.unfocus();
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _clearInput() {
    _controller.value = const TextEditingValue();
  }

  Future<void> _unlock() async {
    if (_unlocking) return;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _clearInput();
      setState(() => _error = context.t.strings.legacy.msg_enter_password);
      return;
    }
    setState(() {
      _unlocking = true;
      _error = null;
    });
    final ok = await ref.read(appLockProvider.notifier).verifyPassword(text);
    if (!mounted) return;
    if (!ok) {
      _clearInput();
      FocusScope.of(context).requestFocus(_focusNode);
      setState(() {
        _error = context.t.strings.legacy.msg_incorrect_password;
        _unlocking = false;
      });
      return;
    }
    _clearInput();
    setState(() => _unlocking = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final border = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    return Material(
      color: bg,
      child: Stack(
        children: [
          if (isDark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0B0B0B),
                      bg,
                      bg,
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: border),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                                color: Colors.black.withValues(alpha: 0.06),
                              ),
                            ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.t.strings.legacy.msg_password_required,
                          style: TextStyle(fontWeight: FontWeight.w800, color: textMain, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.t.strings.legacy.msg_enter_password_continue,
                          style: TextStyle(color: textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: true,
                          obscureText: true,
                          onChanged: (_) {
                            if (_error != null) {
                              setState(() => _error = null);
                            }
                          },
                          onSubmitted: (_) => _unlock(),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textInputAction: TextInputAction.done,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: InputDecoration(
                            hintText: context.t.strings.legacy.msg_enter_password_3,
                            errorText: _error,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _unlocking ? null : _unlock,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MemoFlowPalette.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                              elevation: isDark ? 0 : 3,
                            ),
                            child: _unlocking
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(context.t.strings.legacy.msg_unlock, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
