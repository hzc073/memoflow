import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../state/app_lock_provider.dart';

class PasswordLockScreen extends ConsumerWidget {
  const PasswordLockScreen({super.key});

  Future<String?> _showSetPasswordDialog(BuildContext context, {required bool isChange}) async {
    final password = await showDialog<String?>(
          context: context,
          builder: (context) => _PasswordDialog(isChange: isChange),
        );

    final trimmed = password?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> _selectAutoLockTime(BuildContext context, WidgetRef ref, AutoLockTime selected) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(alignment: Alignment.centerLeft, child: Text('自动锁定时间')),
              ),
              ...AutoLockTime.values.map((v) {
                final isSelected = v == selected;
                return ListTile(
                  leading: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off),
                  title: Text(v.label),
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(appLockProvider.notifier).setAutoLockTime(v);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appLockProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('密码锁'),
        centerTitle: false,
      ),
      body: Stack(
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
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _Group(
                card: card,
                divider: divider,
                children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '开启密码锁',
                        style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
                      ),
                    ),
                    Switch(
                      value: state.enabled,
                      onChanged: (v) async {
                        if (!v) {
                          ref.read(appLockProvider.notifier).setEnabled(false);
                          return;
                        }
                        if (!state.hasPassword) {
                          final password = await _showSetPasswordDialog(context, isChange: false);
                          if (password == null) return;
                          if (!context.mounted) return;
                          await ref.read(appLockProvider.notifier).setPassword(password);
                        }
                        if (!context.mounted) return;
                        ref.read(appLockProvider.notifier).setEnabled(true);
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: MemoFlowPalette.primary,
                      inactiveTrackColor: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.12),
                      inactiveThumbColor: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.white,
                    ),
                  ],
                ),
              ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: state.enabled ? 1.0 : 0.45,
                child: _Group(
                  card: card,
                  divider: divider,
                  children: [
                _ActionRow(
                  label: '修改密码',
                  trailingText: null,
                  enabled: state.enabled,
                  textMain: textMain,
                  textMuted: textMuted,
                  onTap: () async {
                    final password = await _showSetPasswordDialog(context, isChange: true);
                    if (password == null) return;
                    if (!context.mounted) return;
                    await ref.read(appLockProvider.notifier).setPassword(password);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已修改密码（本地）')));
                  },
                ),
                _ActionRow(
                  label: '自动锁定时间',
                  trailingText: state.autoLockTime.label,
                  enabled: state.enabled,
                  textMain: textMain,
                  textMuted: textMuted,
                  onTap: () => _selectAutoLockTime(context, ref, state.autoLockTime),
                ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '启用密码锁后，每次打开应用都需要进行验证。自动锁定时间是指应用切入后台后多久需要再次验证。',
                style: TextStyle(fontSize: 12, height: 1.4, color: textMuted.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.isChange});

  final bool isChange;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  late final TextEditingController _pwdController;
  late final TextEditingController _confirmController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pwdController = TextEditingController();
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _pwdController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final p1 = _pwdController.text.trim();
    final p2 = _confirmController.text.trim();
    if (p1.isEmpty) {
      setState(() => _error = '请输入密码');
      return;
    }
    if (p1 != p2) {
      setState(() => _error = '两次输入不一致');
      return;
    }
    Navigator.of(context).pop(p1);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isChange ? '修改密码' : '设置密码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pwdController,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '新密码',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '确认密码',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('确定')),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.card,
    required this.divider,
    required this.children,
  });

  final Color card;
  final Color divider;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(height: 1, color: divider),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.trailingText,
    required this.enabled,
    required this.textMain,
    required this.textMuted,
    required this.onTap,
  });

  final String label;
  final String? trailingText;
  final bool enabled;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
                ),
              ),
              if (trailingText != null) ...[
                Text(trailingText!, style: TextStyle(fontWeight: FontWeight.w600, color: textMuted)),
                const SizedBox(width: 6),
              ],
              Icon(Icons.chevron_right, size: 20, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
