import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../core/platform_layout.dart';
import '../../data/models/compose_draft.dart';
import '../../i18n/strings.g.dart';
import '../../state/memos/compose_draft_provider.dart';
import '../../state/memos/note_draft_provider.dart';
import '../home/app_drawer.dart';
import '../home/app_drawer_menu_button.dart';
import '../home/desktop/desktop_destination_shell.dart';
import '../home/home_navigation_host.dart';
import 'widgets/draft_box_memo_card.dart';

class DraftBoxSelection {
  const DraftBoxSelection({
    required this.draftUid,
    required this.kind,
    this.targetMemoUid,
  });

  factory DraftBoxSelection.fromDraft(ComposeDraftRecord draft) {
    return DraftBoxSelection(
      draftUid: draft.uid,
      kind: draft.kind,
      targetMemoUid: draft.targetMemoUid,
    );
  }

  final String draftUid;
  final ComposeDraftKind kind;
  final String? targetMemoUid;

  bool get isCreateMemoDraft => kind == ComposeDraftKind.createMemo;
  bool get isEditMemoDraft => kind == ComposeDraftKind.editMemo;
}

class DraftBoxScreen extends ConsumerWidget {
  const DraftBoxScreen({
    super.key,
    this.activeDraftId,
    this.selected,
    this.showDrawer = false,
    this.onSelect,
    this.onSelectTag,
    this.onOpenNotifications,
    this.presentation = HomeScreenPresentation.standalone,
    this.embeddedNavigationHost,
    this.onDraftSelected,
  });

  final String? activeDraftId;
  final AppDrawerDestination? selected;
  final bool showDrawer;
  final ValueChanged<AppDrawerDestination>? onSelect;
  final ValueChanged<String>? onSelectTag;
  final VoidCallback? onOpenNotifications;
  final HomeScreenPresentation presentation;
  final HomeEmbeddedNavigationHost? embeddedNavigationHost;
  final ValueChanged<DraftBoxSelection>? onDraftSelected;

  static Future<DraftBoxSelection?> show(
    BuildContext context, {
    String? activeDraftId,
  }) {
    return Navigator.of(context).push<DraftBoxSelection>(
      MaterialPageRoute<DraftBoxSelection>(
        builder: (_) => DraftBoxScreen(activeDraftId: activeDraftId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(composeDraftsProvider);
    final title = context.t.strings.legacy.msg_draft_box_title;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useDesktopSidePane = shouldUseDesktopSidePaneLayout(screenWidth);
    final isWindowsDesktop =
        Theme.of(context).platform == TargetPlatform.windows;
    final desktopPlatform = Theme.of(context).platform;
    final desktopNavigationMode = useDesktopSidePane
        ? DesktopTitlebarNavigationMode.expandedSidebar
        : DesktopTitlebarNavigationMode.hidden;
    const desktopNavigationContext =
        DesktopTitlebarNavigationContext.topLevelDestination;
    final omitTopLevelChrome = shouldOmitDesktopTopLevelChrome(
      platform: desktopPlatform,
      navigationMode: desktopNavigationMode,
      navigationContext: desktopNavigationContext,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useEmbeddedBottomNav =
        presentation == HomeScreenPresentation.embeddedBottomNav;
    final effectiveSelected = selected ?? AppDrawerDestination.draftBox;
    final drawerPanel = showDrawer
        ? AppDrawer(
            selected: effectiveSelected,
            onSelect: onSelect ?? (_) {},
            onSelectTag: onSelectTag,
            onOpenNotifications: onOpenNotifications,
            embedded: useDesktopSidePane,
          )
        : null;

    void selectDraft(ComposeDraftRecord draft) {
      final selection = DraftBoxSelection.fromDraft(draft);
      final handler = onDraftSelected;
      if (handler != null) {
        handler(selection);
        return;
      }
      Navigator.of(context).pop(selection);
    }

    final body = draftsAsync.when(
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
                onTap: () => selectDraft(draft),
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
    );

    if ((isWindowsDesktop || desktopPlatform == TargetPlatform.macOS) &&
        showDrawer) {
      final bg = isDark
          ? MemoFlowPalette.backgroundDark
          : MemoFlowPalette.backgroundLight;
      return DesktopDestinationShell(
        selectedDestination: effectiveSelected,
        onSelectDestination: onSelect ?? (_) {},
        onSelectTag: onSelectTag,
        onOpenNotifications: onOpenNotifications,
        backgroundColor: bg,
        title: Text(title),
        body: body,
        fallback: const SizedBox.shrink(),
      );
    }

    return Scaffold(
      drawer: showDrawer && !useDesktopSidePane && !useEmbeddedBottomNav
          ? drawerPanel
          : null,
      appBar: AppBar(
        toolbarHeight: resolveDesktopTopLevelToolbarHeight(
          platform: desktopPlatform,
          navigationMode: desktopNavigationMode,
          navigationContext: desktopNavigationContext,
        ),
        automaticallyImplyLeading: !omitTopLevelChrome,
        leading: resolveDesktopTopLevelLeading(
          platform: desktopPlatform,
          navigationMode: desktopNavigationMode,
          navigationContext: desktopNavigationContext,
          leading: showDrawer && !useDesktopSidePane
              ? useEmbeddedBottomNav
                    ? IconButton(
                        tooltip: context.t.strings.legacy.msg_back,
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => embeddedNavigationHost
                            ?.handleBackToPrimaryDestination(context),
                      )
                    : AppDrawerMenuButton(
                        tooltip: context.t.strings.legacy.msg_toggle_sidebar,
                        iconColor:
                            Theme.of(context).appBarTheme.iconTheme?.color ??
                            IconTheme.of(context).color ??
                            Theme.of(context).colorScheme.onSurface,
                        badgeBorderColor:
                            Theme.of(context).appBarTheme.backgroundColor ??
                            Theme.of(context).scaffoldBackgroundColor,
                      )
              : null,
        ),
        title: resolveDesktopTopLevelTitle(
          platform: desktopPlatform,
          navigationMode: desktopNavigationMode,
          navigationContext: desktopNavigationContext,
          title: Text(title),
        ),
      ),
      body: useDesktopSidePane && drawerPanel != null
          ? Row(
              children: [
                SizedBox(
                  width: kMemoFlowDesktopDrawerWidth,
                  child: drawerPanel,
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                Expanded(child: body),
              ],
            )
          : body,
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
      final latestDraft = await repository.latestCreateDraft();
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
