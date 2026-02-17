import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_localization.dart';
import '../../data/models/memo_version.dart';
import '../../state/memo_timeline_provider.dart';
import '../../i18n/strings.g.dart';
import 'memo_markdown.dart';

class MemoVersionPreviewScreen extends ConsumerStatefulWidget {
  const MemoVersionPreviewScreen({super.key, required this.version});

  final MemoVersion version;

  @override
  ConsumerState<MemoVersionPreviewScreen> createState() =>
      _MemoVersionPreviewScreenState();
}

class _MemoVersionPreviewScreenState
    extends ConsumerState<MemoVersionPreviewScreen> {
  bool _restoring = false;

  String _versionContent() {
    final memo = widget.version.payload['memo'];
    if (memo is Map) {
      final content = memo['content'];
      if (content is String) return content;
    }
    return '';
  }

  int _charCount(String text) => text.trim().runes.length;

  Future<void> _restore() async {
    if (_restoring) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(dialogContext.t.strings.settings.preferences.history),
            content: Text(dialogContext.t.strings.legacy.msg_restore_backup),
            actions: [
              TextButton(
                onPressed: () => dialogContext.safePop(false),
                child: Text(dialogContext.t.strings.legacy.msg_cancel_2),
              ),
              FilledButton(
                onPressed: () => dialogContext.safePop(true),
                child: Text(dialogContext.t.strings.legacy.msg_restore),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _restoring = true);
    try {
      await ref
          .read(memoTimelineServiceProvider)
          .restoreMemoVersion(widget.version);
      if (!mounted) return;
      context.safePop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _restoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_restore_failed(e: e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _versionContent();
    final formatter = DateFormat('yyyy/M/d HH:mm');
    final title = formatter.format(widget.version.snapshotTime);
    final count = _charCount(content);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _restoring ? null : _restore,
            child: _restoring
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.t.strings.legacy.msg_restore),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: MemoMarkdown(
                    data: content,
                    normalizeHeadings: true,
                    renderImages: false,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              '${context.t.strings.legacy.msg_characters}: $count',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
