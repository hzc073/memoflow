// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/app_localization.dart';
import '../../core/drawer_navigation.dart';
import '../../core/platform_layout.dart';
import '../../data/models/recycle_bin_item.dart';
import '../../state/memos/memo_timeline_provider.dart';
import '../../i18n/strings.g.dart';
import '../home/app_drawer.dart';
import '../home/app_drawer_destination_builder.dart';
import '../home/desktop/desktop_destination_shell.dart';
import '../home/home_entry_screen.dart';
import '../home/home_navigation_host.dart';
import 'memos_list_screen.dart';
import 'recycle_bin_preview_screen.dart';

class RecycleBinScreen extends ConsumerStatefulWidget {
  const RecycleBinScreen({
    super.key,
    this.presentation = HomeScreenPresentation.standalone,
    this.embeddedNavigationHost,
  });

  final HomeScreenPresentation presentation;
  final HomeEmbeddedNavigationHost? embeddedNavigationHost;

  @override
  ConsumerState<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends ConsumerState<RecycleBinScreen> {
  void _backToAllMemos() {
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleBackToPrimaryDestination(context);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeEntryScreen()),
      (route) => false,
    );
  }

  void _handleBack() {
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleBackToPrimaryDestination(context);
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    _backToAllMemos();
  }

  void _navigate(AppDrawerDestination dest) {
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleDrawerDestination(context, dest);
      return;
    }
    closeDrawerThenPushReplacement(
      context,
      buildDrawerDestinationScreen(context: context, destination: dest),
    );
  }

  void _openTag(String tag) {
    final embeddedNavigationHost = widget.embeddedNavigationHost;
    if (embeddedNavigationHost != null) {
      embeddedNavigationHost.handleDrawerTag(context, tag);
      return;
    }
    closeDrawerThenPushReplacement(
      context,
      MemosListScreen(
        title: '#$tag',
        state: 'NORMAL',
        tag: tag,
        showDrawer: true,
        enableCompose: true,
      ),
    );
  }

  void _openNotifications() {
    openNotificationsDrawerDestination(
      context: context,
      navigationHost: widget.embeddedNavigationHost,
      presentation: widget.presentation,
    );
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
    final enableWindowsDragToMove = isWindowsDesktop;
    final useEmbeddedBottomNav =
        widget.presentation == HomeScreenPresentation.embeddedBottomNav;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerPanel = AppDrawer(
      selected: AppDrawerDestination.recycleBin,
      onSelect: _navigate,
      onSelectTag: _openTag,
      onOpenNotifications: _openNotifications,
      embedded: useDesktopSidePane,
    );

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

    final pageBody = asyncItems.when(
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
    );

    return PopScope(
      canPop: useEmbeddedBottomNav,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || useEmbeddedBottomNav) return;
        _handleBack();
      },
      child: DesktopDestinationShell(
        selectedDestination: AppDrawerDestination.recycleBin,
        onSelectDestination: _navigate,
        onSelectTag: _openTag,
        onOpenNotifications: _openNotifications,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(context.t.strings.legacy.msg_recycle_bin),
        actions: [
          if ((asyncItems.valueOrNull ?? const <RecycleBinItem>[]).isNotEmpty)
            IconButton(
              tooltip: context.t.strings.legacy.msg_clear,
              onPressed: handleClearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
        body: pageBody,
        fallback: Scaffold(
          drawer: useDesktopSidePane ? null : drawerPanel,
          appBar: AppBar(
            toolbarHeight: resolveDesktopTopLevelToolbarHeight(
              platform: desktopPlatform,
              navigationMode: desktopNavigationMode,
              navigationContext: desktopNavigationContext,
            ),
            flexibleSpace: enableWindowsDragToMove
                ? const DragToMoveArea(child: SizedBox.expand())
                : null,
            automaticallyImplyLeading: !omitTopLevelChrome,
            leading: resolveDesktopTopLevelLeading(
              platform: desktopPlatform,
              navigationMode: desktopNavigationMode,
              navigationContext: desktopNavigationContext,
              leading: IconButton(
                tooltip: context.t.strings.legacy.msg_back,
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleBack,
              ),
            ),
            title: resolveDesktopTopLevelTitle(
              platform: desktopPlatform,
              navigationMode: desktopNavigationMode,
              navigationContext: desktopNavigationContext,
              title: IgnorePointer(
                ignoring: enableWindowsDragToMove,
                child: Text(context.t.strings.legacy.msg_recycle_bin),
              ),
            ),
            actions: [
              if ((asyncItems.valueOrNull ?? const <RecycleBinItem>[])
                  .isNotEmpty)
                IconButton(
                  tooltip: context.t.strings.legacy.msg_clear,
                  onPressed: handleClearAll,
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
          ),
          body: useDesktopSidePane
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
                    Expanded(child: pageBody),
                  ],
                )
              : pageBody,
        ),
      ),
    );
  }
}
