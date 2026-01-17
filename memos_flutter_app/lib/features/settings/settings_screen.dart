import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../state/preferences_provider.dart';
import '../../state/session_provider.dart';
import '../../state/theme_mode_provider.dart';
import '../memos/memos_list_screen.dart';
import '../stats/stats_screen.dart';
import 'about_us_screen.dart';
import 'account_security_screen.dart';
import 'ai_settings_screen.dart';
import 'api_plugins_screen.dart';
import 'feedback_screen.dart';
import 'import_export_screen.dart';
import 'laboratory_screen.dart';
import 'password_lock_screen.dart';
import 'preferences_settings_screen.dart';
import 'user_guide_screen.dart';
import 'widgets_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _close(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MemosListScreen(
          title: 'MemoFlow',
          state: 'NORMAL',
          showDrawer: true,
          enableCompose: true,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);
    final hapticsEnabled = ref.watch(appPreferencesProvider.select((p) => p.hapticsEnabled));

    void haptic() {
      if (hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    final account = ref.watch(appSessionProvider).valueOrNull?.currentAccount;
    final name = (account?.user.displayName.isNotEmpty ?? false)
        ? account!.user.displayName
        : (account?.user.name.isNotEmpty ?? false)
            ? account!.user.name
            : 'MemoFlow';

    return WillPopScope(
      onWillPop: () async {
        _close(context);
        return false;
      },
      child: Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        leading: IconButton(
          tooltip: '关闭',
          icon: const Icon(Icons.close),
          onPressed: () => _close(context),
        ),
        title: const Text('设置'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: const _ThemeToggleFab(),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            children: [
              _ProfileCard(
                card: card,
                textMain: textMain,
                textMuted: textMuted,
                name: name,
                subtitle: '期待每一个记录的时刻',
                onTap: () {
                  haptic();
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountSecurityScreen()));
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ShortcutTile(
                      card: card,
                      textMain: textMain,
                      textMuted: textMuted,
                      icon: Icons.calendar_month_outlined,
                      label: '记录统计',
                      onTap: () {
                        haptic();
                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StatsScreen()));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ShortcutTile(
                      card: card,
                      textMain: textMain,
                      textMuted: textMuted,
                      icon: Icons.widgets_outlined,
                      label: '小部件',
                      onTap: () {
                        haptic();
                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WidgetsScreen()));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ShortcutTile(
                      card: card,
                      textMain: textMain,
                      textMuted: textMuted,
                      icon: Icons.code,
                      label: 'API & 插件',
                      onTap: () {
                        haptic();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const ApiPluginsScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _SettingRow(
                    icon: Icons.menu_book_outlined,
                    label: '使用指南',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const UserGuideScreen()));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _SettingRow(
                    icon: Icons.person_outline,
                    label: '账号与密码',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AccountSecurityScreen()),
                      );
                    },
                  ),
                  _SettingRow(
                    icon: Icons.tune,
                    label: '偏好设置',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const PreferencesSettingsScreen()),
                      );
                    },
                  ),
                  _SettingRow(
                    icon: Icons.smart_toy_outlined,
                    label: 'AI 设置',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AiSettingsScreen()),
                      );
                    },
                  ),
                  _SettingRow(
                    icon: Icons.lock_outline,
                    label: '密码锁',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const PasswordLockScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _SettingRow(
                    icon: Icons.science_outlined,
                    label: '实验室',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const LaboratoryScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CardGroup(
                card: card,
                divider: divider,
                children: [
                  _SettingRow(
                    icon: Icons.chat_bubble_outline,
                    label: '反馈建议',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const FeedbackScreen()),
                      );
                    },
                  ),
                  _SettingRow(
                    icon: Icons.import_export,
                    label: '导出/导入',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const ImportExportScreen()),
                      );
                    },
                  ),
                  _SettingRow(
                    icon: Icons.info_outline,
                    label: '关于我们',
                    textMain: textMain,
                    textMuted: textMuted,
                    onTap: () {
                      haptic();
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AboutUsScreen()));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Column(
                children: [
                  Text('版本 v0.8', style: TextStyle(fontSize: 11, color: textMuted)),
                  const SizedBox(height: 4),
                  Text('Made with ♥ for note-taking', style: TextStyle(fontSize: 11, color: textMuted)),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

class _CardGroup extends StatelessWidget {
  const _CardGroup({
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

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.textMain,
    required this.textMuted,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color textMain;
  final Color textMuted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
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
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                child: Icon(Icons.person, color: textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.w800, color: textMain)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: textMuted),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMain)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeToggleFab extends ConsumerWidget {
  const _ThemeToggleFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final icon = isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round;

    return FloatingActionButton.small(
      backgroundColor: bg,
      elevation: isDark ? 0 : 6,
      onPressed: () {
        final mode = ref.read(appThemeModeProvider);
        final brightness = Theme.of(context).brightness;
        final next = switch (mode) {
          ThemeMode.light => ThemeMode.dark,
          ThemeMode.dark => ThemeMode.light,
          ThemeMode.system => brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
        };
        ref.read(appThemeModeProvider.notifier).state = next;
      },
      child: Icon(icon, color: MemoFlowPalette.primary),
    );
  }
}
