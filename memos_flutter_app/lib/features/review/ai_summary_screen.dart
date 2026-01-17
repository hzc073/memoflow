import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/memoflow_palette.dart';
import '../about/about_screen.dart';
import '../home/app_drawer.dart';
import '../memos/memos_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../resources/resources_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';
import 'daily_review_screen.dart';

class AiSummaryScreen extends StatefulWidget {
  const AiSummaryScreen({super.key});

  @override
  State<AiSummaryScreen> createState() => _AiSummaryScreenState();
}

class _AiSummaryScreenState extends State<AiSummaryScreen> {
  final _promptController = TextEditingController();
  var _range = _AiRange.last7Days;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _navigate(BuildContext context, AppDrawerDestination dest) {
    Navigator.of(context).pop();
    final route = switch (dest) {
      AppDrawerDestination.memos => const MemosListScreen(
        title: 'MemoFlow',
        state: 'NORMAL',
        showDrawer: true,
        enableCompose: true,
      ),
      AppDrawerDestination.dailyReview => const DailyReviewScreen(),
      AppDrawerDestination.aiSummary => const AiSummaryScreen(),
      AppDrawerDestination.archived => const MemosListScreen(
        title: '回收站',
        state: 'ARCHIVED',
        showDrawer: true,
      ),
      AppDrawerDestination.tags => const TagsScreen(),
      AppDrawerDestination.resources => const ResourcesScreen(),
      AppDrawerDestination.stats => const StatsScreen(),
      AppDrawerDestination.settings => const SettingsScreen(),
      AppDrawerDestination.about => const AboutScreen(),
    };
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => route));
  }

  void _backToAllMemos(BuildContext context) {
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

  void _openTag(BuildContext context, String tag) {
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MemosListScreen(
          title: '#$tag',
          state: 'NORMAL',
          tag: tag,
          showDrawer: true,
          enableCompose: true,
        ),
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
  }

  void _applyPrompt(String text) {
    _promptController.text = text;
    _promptController.selection = TextSelection.fromPosition(
      TextPosition(offset: _promptController.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final border = isDark
        ? MemoFlowPalette.borderDark
        : MemoFlowPalette.borderLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.6 : 0.5);
    final chipBg = isDark
        ? MemoFlowPalette.cardDark
        : MemoFlowPalette.cardLight;
    final inputBg = isDark
        ? const Color(0xFF161616)
        : MemoFlowPalette.audioSurfaceLight;

    final quickPrompts = <_PromptOption>[
      _PromptOption(
        icon: Icons.mood,
        label: '最近一周我的情绪变化',
        lightColor: MemoFlowPalette.aiChipBlueLight,
        darkColor: const Color(0xFF78A1C0),
      ),
      _PromptOption(
        icon: Icons.lightbulb,
        label: '今年内我重复提到的想法',
        lightColor: MemoFlowPalette.reviewChipOrangeLight,
        darkColor: const Color(0xFFE5A36A),
      ),
      _PromptOption(
        icon: Icons.assignment,
        label: '总结我关于项目的灵感',
        lightColor: const Color(0xFF6B8E6B),
        darkColor: const Color(0xFF86AD86),
      ),
      _PromptOption(
        icon: Icons.trending_up,
        label: '分析我的学习进度',
        lightColor: const Color(0xFFA67EB7),
        darkColor: const Color(0xFFBF9BD1),
      ),
    ];

    return WillPopScope(
      onWillPop: () async {
        _backToAllMemos(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: bg,
        drawer: AppDrawer(
          selected: AppDrawerDestination.aiSummary,
          onSelect: (d) => _navigate(context, d),
          onSelectTag: (t) => _openTag(context, t),
          onOpenNotifications: () => _openNotifications(context),
        ),
        appBar: AppBar(
          title: const Text('AI 总结'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(color: bg.withValues(alpha: 0.9)),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: border.withValues(alpha: 0.6)),
          ),
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.4 : 0.03,
                        ),
                        blurRadius: isDark ? 20 : 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '时间范围',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _AiRangeButton(
                              label: _AiRange.last7Days.label,
                              selected: _range == _AiRange.last7Days,
                              onTap: () =>
                                  setState(() => _range = _AiRange.last7Days),
                              primary: MemoFlowPalette.primary,
                              background: chipBg,
                              borderColor: border,
                              textColor: textMain,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _AiRangeButton(
                              label: _AiRange.last30Days.label,
                              selected: _range == _AiRange.last30Days,
                              onTap: () =>
                                  setState(() => _range = _AiRange.last30Days),
                              primary: MemoFlowPalette.primary,
                              background: chipBg,
                              borderColor: border,
                              textColor: textMain,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _AiRangeButton(
                              label: _AiRange.custom.label,
                              selected: _range == _AiRange.custom,
                              onTap: () =>
                                  setState(() => _range = _AiRange.custom),
                              primary: MemoFlowPalette.primary,
                              background: chipBg,
                              borderColor: border,
                              textColor: textMain,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '总结指令 (可选)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _promptController,
                        minLines: 4,
                        maxLines: 4,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: textMain,
                        ),
                        decoration: InputDecoration(
                          hintText: '输入你想总结的内容或指令...',
                          hintStyle: TextStyle(
                            color: textMuted.withValues(alpha: 0.7),
                          ),
                          filled: true,
                          fillColor: inputBg,
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: border.withValues(
                                alpha: isDark ? 0.7 : 0.0,
                              ),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: border.withValues(
                                alpha: isDark ? 0.7 : 0.0,
                              ),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: MemoFlowPalette.primary.withValues(
                                alpha: isDark ? 0.6 : 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  '快速尝试',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final option in quickPrompts)
                      _PromptChip(
                        label: option.label,
                        icon: option.icon,
                        iconColor: option.color(isDark),
                        background: chipBg,
                        borderColor: border,
                        textColor: textMain,
                        onTap: () => _applyPrompt(option.label),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        bg,
                        bg.withValues(alpha: 0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: MemoFlowPalette.primary.withValues(
                            alpha: isDark ? 0.2 : 0.2,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('AI 总结：待实现')),
                          );
                        },
                        icon: const Icon(Icons.auto_awesome, size: 20),
                        label: const Text('开始生成总结'),
                        style: FilledButton.styleFrom(
                          backgroundColor: MemoFlowPalette.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
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

enum _AiRange {
  last7Days('最近一周'),
  last30Days('最近一月'),
  custom('自定义');

  const _AiRange(this.label);

  final String label;
}

class _PromptOption {
  const _PromptOption({
    required this.icon,
    required this.label,
    required this.lightColor,
    required this.darkColor,
  });

  final IconData icon;
  final String label;
  final Color lightColor;
  final Color darkColor;

  Color color(bool isDark) => isDark ? darkColor : lightColor;
}

class _AiRangeButton extends StatelessWidget {
  const _AiRangeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.primary,
    required this.background,
    required this.borderColor,
    required this.textColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color primary;
  final Color background;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? primary : background,
            borderRadius: BorderRadius.circular(12),
            border: selected ? null : Border.all(color: borderColor),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Color background;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
