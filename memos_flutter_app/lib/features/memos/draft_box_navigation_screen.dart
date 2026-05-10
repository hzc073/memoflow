import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/drawer_navigation.dart';
import '../../core/top_toast.dart';
import '../../state/memos/compose_draft_provider.dart';
import '../../state/memos/memos_list_providers.dart';
import '../home/app_drawer.dart';
import '../home/app_drawer_destination_builder.dart';
import '../home/home_navigation_host.dart';
import '../notifications/notifications_screen.dart';
import 'draft_box_screen.dart';
import 'memo_editor_screen.dart';
import 'note_input_sheet.dart';

class DraftBoxNavigationScreen extends ConsumerStatefulWidget {
  const DraftBoxNavigationScreen({
    super.key,
    this.presentation = HomeScreenPresentation.standalone,
    this.embeddedNavigationHost,
  });

  final HomeScreenPresentation presentation;
  final HomeEmbeddedNavigationHost? embeddedNavigationHost;

  @override
  ConsumerState<DraftBoxNavigationScreen> createState() =>
      _DraftBoxNavigationScreenState();
}

class _DraftBoxNavigationScreenState
    extends ConsumerState<DraftBoxNavigationScreen> {
  final _screenKey = GlobalKey();
  var _openingDraft = false;

  void _navigateDrawer(AppDrawerDestination destination) {
    final host = widget.embeddedNavigationHost;
    if (host != null) {
      host.handleDrawerDestination(context, destination);
      return;
    }
    closeDrawerThenPushReplacement(
      context,
      buildDrawerDestinationScreen(context: context, destination: destination),
    );
  }

  void _openNotifications() {
    final host = widget.embeddedNavigationHost;
    if (host != null) {
      host.handleOpenNotifications(context);
      return;
    }
    closeDrawerThenPushReplacement(context, const NotificationsScreen());
  }

  Future<void> _handleDraftSelected(DraftBoxSelection selection) async {
    final normalizedUid = selection.draftUid.trim();
    if (_openingDraft || normalizedUid.isEmpty) return;
    setState(() => _openingDraft = true);
    try {
      if (selection.isCreateMemoDraft) {
        await NoteInputSheet.show(context, initialDraftUid: normalizedUid);
        return;
      }
      await _openEditDraft(selection);
    } finally {
      if (mounted) {
        ref.invalidate(composeDraftsProvider);
        setState(() => _openingDraft = false);
      }
    }
  }

  Future<void> _openEditDraft(DraftBoxSelection selection) async {
    final repository = ref.read(composeDraftRepositoryProvider);
    final draft = await repository.getByUid(selection.draftUid);
    if (!mounted || draft == null) return;

    final targetMemoUid = draft.targetMemoUid?.trim().isNotEmpty == true
        ? draft.targetMemoUid!.trim()
        : selection.targetMemoUid?.trim() ?? '';
    if (targetMemoUid.isEmpty) {
      _showTargetUnavailable();
      return;
    }

    final resolved = await ref
        .read(memosListControllerProvider)
        .resolveMemoForOpen(uid: targetMemoUid);
    if (!mounted) return;
    final memo = resolved.memo;
    if (memo == null) {
      _showTargetUnavailable();
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            MemoEditorScreen(existing: memo, initialEditDraft: draft),
      ),
    );
  }

  void _showTargetUnavailable() {
    showTopToast(
      context,
      context.tr(
        zh: '原笔记暂时无法打开，编辑草稿仍保留在草稿箱',
        en: 'The original memo cannot be opened right now. The edit draft remains in Draft Box.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraftBoxScreen(
      key: _screenKey,
      selected: AppDrawerDestination.draftBox,
      showDrawer: true,
      onSelect: _navigateDrawer,
      onOpenNotifications: _openNotifications,
      presentation: widget.presentation,
      embeddedNavigationHost: widget.embeddedNavigationHost,
      onDraftSelected: (selection) =>
          unawaited(_handleDraftSelected(selection)),
    );
  }
}
