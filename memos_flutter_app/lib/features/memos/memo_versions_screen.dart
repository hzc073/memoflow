import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/memo_timeline_provider.dart';
import '../../i18n/strings.g.dart';
import 'memo_version_preview_screen.dart';

class MemoVersionsScreen extends ConsumerWidget {
  const MemoVersionsScreen({super.key, required this.memoUid});

  final String memoUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncVersions = ref.watch(memoVersionsProvider(memoUid));
    final formatter = DateFormat('yyyy/MM/dd HH:mm:ss');

    String versionContent(Map<String, dynamic> payload) {
      final memo = payload['memo'];
      if (memo is Map) {
        final content = memo['content'];
        if (content is String) return content;
      }
      return '';
    }

    int charCount(String text) => text.trim().runes.length;

    Future<void> openVersionPreview(BuildContext context, int index) async {
      final versions = asyncVersions.valueOrNull;
      if (versions == null || index < 0 || index >= versions.length) return;
      final restored = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => MemoVersionPreviewScreen(version: versions[index]),
        ),
      );
      if (restored != true || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_restored)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.strings.settings.preferences.history),
      ),
      body: asyncVersions.when(
        data: (versions) {
          if (versions.isEmpty) {
            return Center(
              child: Text(context.t.strings.legacy.msg_no_content_yet),
            );
          }
          return ListView.separated(
            itemCount: versions.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final version = versions[index];
              final timeLabel = formatter.format(version.snapshotTime);
              final content = versionContent(version.payload);
              final count = charCount(content);
              return ListTile(
                onTap: () => openVersionPreview(context, index),
                title: Text(timeLabel),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${context.t.strings.legacy.msg_characters}: $count',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(context.t.strings.legacy.msg_failed_load_4(e: error)),
        ),
      ),
    );
  }
}
