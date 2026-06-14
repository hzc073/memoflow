import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/maintenance/storage_space_summary_models.dart';
import '../../core/top_toast.dart';
import '../../platform/widgets/platform_controls.dart';
import '../../platform/widgets/platform_primary_action.dart';
import '../../state/maintenance/storage_space_controller.dart';
import '../../i18n/strings.g.dart';
import 'settings_ui.dart';

class StorageSpaceScreen extends ConsumerWidget {
  const StorageSpaceScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final confirmed = await showSettingsConfirmationDialog(
      context: context,
      title: context.t.strings.legacy.msg_confirm_clear_media_cache,
      message: context.t.strings.legacy.msg_clear_media_cache_confirm_message,
      confirmLabel: context.t.strings.common.confirm,
      cancelLabel: context.t.strings.common.cancel,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final result = await ref
          .read(storageSpaceControllerProvider.notifier)
          .clearCache();
      if (!context.mounted) return;
      showTopToast(context, _clearResultMessage(context, result));
    } catch (error) {
      if (!context.mounted) return;
      showTopToast(
        context,
        context.t.strings.legacy.msg_action_failed(e: error),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storageSpaceControllerProvider);
    final summary = state.summary;

    return SettingsPage(
      showBackButton: showBackButton,
      title: Text(context.t.strings.legacy.msg_storage_space),
      onRefresh: () =>
          ref.read(storageSpaceControllerProvider.notifier).loadSummary(),
      children: [
        _StorageSummaryHeader(state: state),
        const SizedBox(height: 12),
        SettingsSection(
          children: [
            if (summary == null)
              _LoadingStorageRow(state: state)
            else
              for (final category in _orderedCategories(summary))
                _StorageCategoryRow(
                  category: category,
                  clearing: state.clearing,
                  onClearCache:
                      category.categoryId == StorageSpaceCategoryId.cache
                      ? () => _clearCache(context, ref)
                      : null,
                ),
          ],
        ),
      ],
    );
  }
}

class _StorageSummaryHeader extends StatelessWidget {
  const _StorageSummaryHeader({required this.state});

  final StorageSpaceState state;

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    final title = context.t.strings.legacy.msg_memoflow_known_usage;
    final description = summary == null
        ? state.loadError != null
              ? context.t.strings.legacy.msg_media_cache_size_unavailable
              : context.t.strings.legacy.msg_media_cache_calculating
        : _deviceUsageDescription(context, summary);
    final value = summary == null
        ? null
        : _formatBytes(context, summary.knownUsageBytes);

    return SettingsSection(
      children: [
        SettingsCustomRow(
          leading: Icon(
            Icons.pie_chart_outline,
            size: 20,
            color: settingsPageTokens(context).textMuted,
          ),
          title: SettingsContentHeader(
            title: title,
            description: description,
            trailing: value == null
                ? state.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: PlatformProgress(),
                        )
                      : null
                : Text(
                    value,
                    style: TextStyle(
                      color: settingsPageTokens(context).textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _LoadingStorageRow extends StatelessWidget {
  const _LoadingStorageRow({required this.state});

  final StorageSpaceState state;

  @override
  Widget build(BuildContext context) {
    return SettingsCustomRow(
      leading: Icon(
        Icons.storage_outlined,
        size: 20,
        color: settingsPageTokens(context).textMuted,
      ),
      title: SettingsRowTitle(context.t.strings.legacy.msg_storage_cache),
      description: SettingsRowDescription(
        state.loadError != null
            ? context.t.strings.legacy.msg_media_cache_size_unavailable
            : context.t.strings.legacy.msg_media_cache_calculating,
      ),
    );
  }
}

class _StorageCategoryRow extends StatelessWidget {
  const _StorageCategoryRow({
    required this.category,
    required this.clearing,
    required this.onClearCache,
  });

  final StorageSpaceCategorySummary category;
  final bool clearing;
  final VoidCallback? onClearCache;

  @override
  Widget build(BuildContext context) {
    final tokens = settingsPageTokens(context);
    final isCache = category.categoryId == StorageSpaceCategoryId.cache;
    return SettingsCustomRow(
      leading: Icon(
        _categoryIcon(category.categoryId),
        size: 20,
        color: tokens.textMuted,
      ),
      title: SettingsRowTitle(_categoryLabel(context, category.categoryId)),
      description: SettingsRowDescription(
        _categoryDescription(context, category.categoryId),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatBytes(context, category.sizeBytes),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: tokens.textMuted,
            ),
          ),
          if (isCache) ...[
            const SizedBox(width: 12),
            if (clearing)
              const SizedBox(width: 18, height: 18, child: PlatformProgress())
            else
              SettingsAction(
                label: Text(context.t.strings.legacy.msg_clear),
                icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                variant: PlatformPrimaryActionVariant.text,
                onPressed: onClearCache,
              ),
          ],
        ],
      ),
    );
  }
}

List<StorageSpaceCategorySummary> _orderedCategories(
  StorageSpaceSummary summary,
) {
  return [
    for (final id in StorageSpaceCategoryId.values)
      if (summary.category(id) != null) summary.category(id)!,
  ];
}

String _deviceUsageDescription(
  BuildContext context,
  StorageSpaceSummary summary,
) {
  final ratio = summary.deviceUsageRatio;
  if (ratio == null) {
    return context.t.strings.legacy.msg_storage_device_capacity_unavailable;
  }
  final percent = ratio * 100;
  if (percent > 0 && percent < 1) {
    return context
        .t
        .strings
        .legacy
        .msg_storage_memoflow_device_usage_less_than_one_percent;
  }
  return context.t.strings.legacy.msg_storage_memoflow_device_usage_percent(
    percent: percent.toStringAsFixed(percent >= 10 ? 0 : 1),
  );
}

String _categoryLabel(BuildContext context, StorageSpaceCategoryId id) {
  return switch (id) {
    StorageSpaceCategoryId.cache => context.t.strings.legacy.msg_storage_cache,
    StorageSpaceCategoryId.noteContent =>
      context.t.strings.legacy.msg_storage_note_content,
    StorageSpaceCategoryId.noteImages =>
      context.t.strings.legacy.msg_storage_note_images,
    StorageSpaceCategoryId.noteVideos =>
      context.t.strings.legacy.msg_storage_note_videos,
    StorageSpaceCategoryId.noteAudio =>
      context.t.strings.legacy.msg_storage_note_audio,
    StorageSpaceCategoryId.noteFiles =>
      context.t.strings.legacy.msg_storage_note_files,
  };
}

String _categoryDescription(BuildContext context, StorageSpaceCategoryId id) {
  return switch (id) {
    StorageSpaceCategoryId.cache =>
      context.t.strings.legacy.msg_storage_cache_description,
    StorageSpaceCategoryId.noteContent =>
      context.t.strings.legacy.msg_storage_note_content_description,
    StorageSpaceCategoryId.noteImages ||
    StorageSpaceCategoryId.noteVideos ||
    StorageSpaceCategoryId.noteAudio ||
    StorageSpaceCategoryId.noteFiles =>
      context.t.strings.legacy.msg_storage_attachment_read_only_description,
  };
}

IconData _categoryIcon(StorageSpaceCategoryId id) {
  return switch (id) {
    StorageSpaceCategoryId.cache => Icons.cached_outlined,
    StorageSpaceCategoryId.noteContent => Icons.notes_outlined,
    StorageSpaceCategoryId.noteImages => Icons.image_outlined,
    StorageSpaceCategoryId.noteVideos => Icons.movie_outlined,
    StorageSpaceCategoryId.noteAudio => Icons.audiotrack_outlined,
    StorageSpaceCategoryId.noteFiles => Icons.insert_drive_file_outlined,
  };
}

String _clearResultMessage(
  BuildContext context,
  StorageSpaceCacheClearResult result,
) {
  if (result.isPartialFailure) {
    return context.t.strings.legacy.msg_clear_media_cache_partial_failure;
  }
  if (result.isFailure) {
    return context.t.strings.legacy.msg_clear_media_cache_failed;
  }
  return context.t.strings.legacy.msg_clear_media_cache_success;
}

String _formatBytes(BuildContext context, int bytes) {
  if (bytes < 1024) {
    return '$bytes ${context.t.strings.legacy.msg_bytes}';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} ${context.t.strings.legacy.msg_kb}';
  }
  final mb = kb / 1024;
  if (mb < 1024) {
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} ${context.t.strings.legacy.msg_mb}';
  }
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(gb >= 10 ? 0 : 1)} ${context.t.strings.legacy.msg_gb}';
}
