import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_localization.dart';
import '../../data/models/recycle_bin_item.dart';
import '../../state/memo_timeline_provider.dart';
import '../../i18n/strings.g.dart';
import 'memo_markdown.dart';

class RecycleBinPreviewScreen extends ConsumerStatefulWidget {
  const RecycleBinPreviewScreen({super.key, required this.item});

  final RecycleBinItem item;

  @override
  ConsumerState<RecycleBinPreviewScreen> createState() =>
      _RecycleBinPreviewScreenState();
}

class _RecycleBinPreviewScreenState
    extends ConsumerState<RecycleBinPreviewScreen> {
  bool _deleting = false;

  bool get _isMemo => widget.item.type == RecycleBinItemType.memo;

  String _memoContent() {
    final memo = widget.item.payload['memo'];
    if (memo is Map) {
      final content = memo['content'];
      if (content is String) return content;
    }
    return '';
  }

  String _attachmentText() {
    final attachment = widget.item.payload['attachment'];
    if (attachment is Map) {
      final filename = (attachment['filename'] as String?)?.trim() ?? '';
      final type = (attachment['type'] as String?)?.trim() ?? '';
      final summary = widget.item.summary.trim();
      final lines = <String>[
        if (filename.isNotEmpty) filename,
        if (type.isNotEmpty) type,
        if (summary.isNotEmpty) summary,
      ];
      if (lines.isNotEmpty) return lines.join('\n');
    }
    final summary = widget.item.summary.trim();
    if (summary.isNotEmpty) return summary;
    return '';
  }

  int _charCount(String text) => text.trim().runes.length;

  Future<void> _delete() async {
    if (_deleting) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(dialogContext.t.strings.legacy.msg_recycle_bin),
            content: Text(dialogContext.t.strings.legacy.msg_delete),
            actions: [
              TextButton(
                onPressed: () => dialogContext.safePop(false),
                child: Text(dialogContext.t.strings.legacy.msg_cancel_2),
              ),
              FilledButton(
                onPressed: () => dialogContext.safePop(true),
                child: Text(dialogContext.t.strings.legacy.msg_delete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref
          .read(memoTimelineServiceProvider)
          .deleteRecycleBinItem(widget.item);
      if (!mounted) return;
      context.safePop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_delete_failed(e: e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _isMemo ? _memoContent() : _attachmentText();
    final formatter = DateFormat('yyyy/M/d HH:mm');
    final title = formatter.format(widget.item.deletedTime);
    final count = _charCount(content);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _deleting ? null : _delete,
            child: _deleting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.t.strings.legacy.msg_delete),
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
                  child: _isMemo
                      ? MemoMarkdown(
                          data: content,
                          normalizeHeadings: true,
                          renderImages: false,
                        )
                      : SelectableText(
                          content.isEmpty
                              ? context.t.strings.legacy.msg_empty_content
                              : content,
                        ),
                ),
              ),
            ),
          ),
          if (_isMemo)
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
