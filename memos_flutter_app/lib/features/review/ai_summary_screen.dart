import 'package:flutter/material.dart';

import '../about/about_screen.dart';
import '../home/app_drawer.dart';
import '../memos/memos_list_screen.dart';
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
  var _range = _AiRange.last30Days;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _navigate(BuildContext context, AppDrawerDestination dest) {
    Navigator.of(context).pop();
    final route = switch (dest) {
      AppDrawerDestination.memos =>
        const MemosListScreen(title: 'MemoFlow', state: 'NORMAL', showDrawer: true, enableCompose: true),
      AppDrawerDestination.dailyReview => const DailyReviewScreen(),
      AppDrawerDestination.aiSummary => const AiSummaryScreen(),
      AppDrawerDestination.archived => const MemosListScreen(title: '回收站', state: 'ARCHIVED', showDrawer: true),
      AppDrawerDestination.tags => const TagsScreen(),
      AppDrawerDestination.resources => const ResourcesScreen(),
      AppDrawerDestination.stats => const StatsScreen(),
      AppDrawerDestination.settings => const SettingsScreen(),
      AppDrawerDestination.about => const AboutScreen(),
    };
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => route));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        selected: AppDrawerDestination.aiSummary,
        onSelect: (d) => _navigate(context, d),
        onSelectTag: (t) => _openTag(context, t),
      ),
      appBar: AppBar(title: const Text('AI 总结')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('生成报告', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: '范围',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_AiRange>(
                value: _range,
                isExpanded: true,
                items: _AiRange.values
                    .map(
                      (r) => DropdownMenuItem<_AiRange>(
                        value: r,
                        child: Text(r.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (v) => setState(() => _range = v ?? _AiRange.last30Days),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _promptController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '提示词（可选）',
              hintText: '例如：请按主题/情绪/高频标签总结，并给出下一步建议',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI 总结：待实现（后续可接入 LLM 并支持年终报告）')),
              );
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('生成'),
          ),
          const SizedBox(height: 24),
          Text(
            '说明：该页面计划用于选择范围后，将笔记内容发送给 LLM 生成总结/报告；不会改变后端数据。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

enum _AiRange {
  last7Days('最近 7 天'),
  last30Days('最近 30 天'),
  thisMonth('本月'),
  thisYear('今年'),
  all('全部');

  const _AiRange(this.label);

  final String label;
}
