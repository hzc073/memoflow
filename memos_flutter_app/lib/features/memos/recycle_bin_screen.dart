import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_localization.dart';
import '../../data/models/recycle_bin_item.dart';
import '../../state/memo_timeline_provider.dart';
import '../../i18n/strings.g.dart';
import 'memos_list_screen.dart';
import 'recycle_bin_preview_screen.dart';

class RecycleBinScreen extends ConsumerStatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  ConsumerState<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends ConsumerState<RecycleBinScreen> {
  void _backToAllMemos() {
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

  void _handleBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    _backToAllMemos();
  }

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(memoTimelineServiceProvider).purgeExpiredRecycleBin());
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(memoTimelineServiceProvider);
    final asyncItems = ref.watch(recycleBinItemsProvider);
    final formatter = DateFormat('yyyy-MM-dd HH:mm');

    Future<void> handleRestore(RecycleBinItem item) async {
      try {
        await service.restoreRecycleBinItem(item);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.strings.legacy.msg_restored)),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_restore_failed(e: e)),
          ),
        );
      }
    }

    Future<void> handleDelete(RecycleBinItem item) async {
      try {
        await service.deleteRecycleBinItem(item);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_delete_failed(e: e)),
          ),
        );
      }
    }

    Future<void> openPreview(RecycleBinItem item) async {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => RecycleBinPreviewScreen(item: item),
        ),
      );
    }

    Future<void> handleClearAll() async {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.t.strings.legacy.msg_recycle_bin),
              content: Text(
                context.t.strings.legacy.msg_clear_recycle_bin_confirm,
              ),
              actions: [
                TextButton(
                  onPressed: () => context.safePop(false),
                  child: Text(context.t.strings.legacy.msg_cancel_2),
                ),
                FilledButton(
                  onPressed: () => context.safePop(true),
                  child: Text(context.t.strings.legacy.msg_clear),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      try {
        await service.clearRecycleBin();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.strings.legacy.msg_delete_failed(e: e)),
          ),
        );
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: context.t.strings.legacy.msg_back,
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(context.t.strings.legacy.msg_recycle_bin),
          actions: [
            if ((asyncItems.valueOrNull ?? const <RecycleBinItem>[]).isNotEmpty)
              IconButton(
                tooltip: context.t.strings.legacy.msg_clear,
                onPressed: handleClearAll,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
          ],
        ),
        body: asyncItems.when(
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Text(context.t.strings.legacy.msg_no_content_yet),
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final deletedLabel = formatter.format(item.deletedTime);
                final expireLabel = formatter.format(item.expireTime);
                return ListTile(
                  onTap: () => openPreview(item),
                  leading: Icon(
                    item.type == RecycleBinItemType.memo
                        ? Icons.sticky_note_2_outlined
                        : Icons.attach_file,
                  ),
                  title: Text(
                    item.summary.trim().isEmpty
                        ? context.t.strings.legacy.msg_empty_content
                        : item.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('$deletedLabel  |  $expireLabel'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'restore') {
                        unawaited(handleRestore(item));
                      } else if (value == 'delete') {
                        unawaited(handleDelete(item));
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'restore',
                        child: Text(context.t.strings.legacy.msg_restore),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text(context.t.strings.legacy.msg_delete),
                      ),
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
      ),
    );
  }
}
