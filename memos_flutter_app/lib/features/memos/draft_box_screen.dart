import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform_layout.dart';
import '../../data/models/compose_draft.dart';
import '../../i18n/strings.g.dart';
import '../../state/memos/compose_draft_provider.dart';
import '../../state/memos/note_draft_provider.dart';
import 'widgets/draft_box_memo_card.dart';

class DraftBoxScreen extends ConsumerWidget {
  const DraftBoxScreen({super.key, this.activeDraftId});

  final String? activeDraftId;

  static Future<String?> show(BuildContext context, {String? activeDraftId}) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => DraftBoxScreen(activeDraftId: activeDraftId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(composeDraftsProvider);
    final title = context.t.strings.legacy.msg_draft_box_title;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: draftsAsync.when(
        data: (drafts) {
          if (drafts.isEmpty) {
            return _EmptyDraftBox(title: title);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final draft = drafts[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == drafts.length - 1 ? 0 : 10,
                ),
                child: _DraftBoxCardSlot(
                  draft: draft,
                  selected: draft.uid == activeDraftId,
                  onTap: () => Navigator.of(context).pop(draft.uid),
                  onDelete: () => _handleDeleteDraft(context, ref, draft),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '${context.t.strings.legacy.msg_load_failed}: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDeleteDraft(
    BuildContext context,
    WidgetRef ref,
    ComposeDraftRecord draft,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.t.strings.legacy.msg_delete_draft),
        content: Text(dialogContext.t.strings.legacy.msg_delete_draft_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.t.strings.legacy.msg_cancel_2),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.t.strings.legacy.msg_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final repository = ref.read(composeDraftRepositoryProvider);
      await repository.deleteDraft(draft.uid);
      final latestDraft = await repository.latestDraft();
      final noteDraftController = ref.read(noteDraftProvider.notifier);
      if (latestDraft == null) {
        await noteDraftController.clear();
      } else {
        await noteDraftController.setDraft(latestDraft.snapshot.content);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.strings.legacy.msg_draft_deleted)),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_delete_failed(e: error)),
        ),
      );
    }
  }
}

class _DraftBoxCardSlot extends StatelessWidget {
  const _DraftBoxCardSlot({
    required this.draft,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final ComposeDraftRecord draft;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    Widget child = DraftBoxMemoCard(
      draft: draft,
      selected: selected,
      onTap: onTap,
      onDelete: onDelete,
    );
    if (Theme.of(context).platform == TargetPlatform.windows) {
      child = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: kMemoFlowDesktopMemoCardMaxWidth,
          ),
          child: child,
        ),
      );
    }
    return child;
  }
}

class _EmptyDraftBox extends StatelessWidget {
  const _EmptyDraftBox({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 52),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              context.t.strings.legacy.msg_draft_box_empty_desc,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
