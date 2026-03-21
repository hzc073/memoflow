import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../../i18n/strings.g.dart';
import 'gallery_attachment_picker_constants.dart';

@immutable
class OriginalToggleGalleryAssetPickResult {
  const OriginalToggleGalleryAssetPickResult({
    required this.assets,
    required this.originalAssetIds,
  });

  final List<AssetEntity> assets;
  final Set<String> originalAssetIds;
}

class OriginalToggleAssetPickerProvider extends DefaultAssetPickerProvider {
  OriginalToggleAssetPickerProvider({
    super.selectedAssets,
    super.maxAssets,
    super.pageSize,
    super.pathThumbnailSize,
    super.requestType = RequestType.common,
    super.sortPathDelegate,
    super.sortPathsByModifiedDate,
    super.filterOptions,
    super.initializeDelayDuration,
  });

  final Set<String> _originalAssetIds = <String>{};

  Set<String> get originalAssetIds => Set.unmodifiable(_originalAssetIds);

  Iterable<AssetEntity> get selectedImageAssets =>
      selectedAssets.where((asset) => asset.type == AssetType.image);

  bool get hasSelectedImages => selectedImageAssets.isNotEmpty;

  AssetEntity? get currentOriginalTargetAsset {
    final selectedImages = selectedImageAssets.toList(growable: false);
    if (selectedImages.isEmpty) return null;
    return selectedImages.last;
  }

  bool get isCurrentOriginalTargetMarked {
    final asset = currentOriginalTargetAsset;
    return asset != null && _originalAssetIds.contains(asset.id);
  }

  int get originalSelectedCount => selectedAssets
      .where(
        (asset) =>
            asset.type == AssetType.image &&
            _originalAssetIds.contains(asset.id),
      )
      .length;

  bool isMarkedOriginal(AssetEntity asset) =>
      _originalAssetIds.contains(asset.id);

  void toggleOriginalForCurrentSelectedImage() {
    final asset = currentOriginalTargetAsset;
    if (asset == null) return;
    toggleOriginalForAsset(asset);
  }

  void toggleOriginalForAsset(AssetEntity asset) {
    if (asset.type != AssetType.image) return;
    if (!selectedAssets.any((selectedAsset) => selectedAsset.id == asset.id)) {
      return;
    }
    if (_originalAssetIds.contains(asset.id)) {
      _originalAssetIds.remove(asset.id);
    } else {
      _originalAssetIds.add(asset.id);
    }
    notifyListeners();
  }

  @override
  void unSelectAsset(AssetEntity item) {
    _originalAssetIds.remove(item.id);
    super.unSelectAsset(item);
  }

  @override
  set selectedAssets(List<AssetEntity> value) {
    super.selectedAssets = value;
    final selectedIds = value.map((asset) => asset.id).toSet();
    final before = _originalAssetIds.length;
    _originalAssetIds.removeWhere((id) => !selectedIds.contains(id));
    if (before != _originalAssetIds.length) {
      notifyListeners();
    }
  }
}

class OriginalToggleAssetPickerBuilderDelegate
    extends
        DefaultAssetPickerBuilderDelegate<OriginalToggleAssetPickerProvider> {
  OriginalToggleAssetPickerBuilderDelegate({
    required super.provider,
    required super.initialPermission,
    super.gridCount,
    super.pickerTheme,
    super.specialItems = const [],
    super.loadingIndicatorBuilder,
    super.selectPredicate,
    super.shouldRevertGrid,
    super.limitedPermissionOverlayPredicate,
    super.pathNameBuilder,
    super.assetsChangeCallback,
    super.assetsChangeRefreshPredicate,
    super.viewerUseRootNavigator,
    super.viewerPageRouteSettings,
    super.viewerPageRouteBuilder,
    super.themeColor,
    super.textDelegate,
    super.locale,
    super.gridThumbnailSize,
    super.previewThumbnailSize,
    super.specialPickerType,
    super.keepScrollOffset,
    super.shouldAutoplayPreview,
    super.dragToSelect,
    super.enableLivePhoto,
  });

  @override
  Widget confirmButton(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, child) {
        final selectionProvider = provider;
        final isSelectedNotEmpty = selectionProvider.isSelectedNotEmpty;
        final shouldAllowConfirm =
            isSelectedNotEmpty ||
            selectionProvider.previousSelectedAssets.isNotEmpty;
        return MaterialButton(
          minWidth: shouldAllowConfirm ? 48 : 20,
          height: bottomActionBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: theme.colorScheme.secondary,
          disabledColor: theme.splashColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          onPressed: shouldAllowConfirm
              ? () {
                  Navigator.maybeOf(context)?.maybePop(
                    OriginalToggleGalleryAssetPickResult(
                      assets: List<AssetEntity>.from(
                        selectionProvider.selectedAssets,
                      ),
                      originalAssetIds: Set<String>.from(
                        selectionProvider.originalAssetIds,
                      ),
                    ),
                  );
                }
              : null,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          child: Text(
            isSelectedNotEmpty && !isSingleAssetMode
                ? '${textDelegate.confirm} (${selectionProvider.selectedAssets.length}/${selectionProvider.maxAssets})'
                : textDelegate.confirm,
            style: TextStyle(
              color: shouldAllowConfirm
                  ? theme.textTheme.bodyLarge?.color
                  : theme.textTheme.bodySmall?.color,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget selectedBackdrop(BuildContext context, int index, AssetEntity asset) {
    final indicatorSize = MediaQuery.sizeOf(context).width / gridCount / 3;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isPreviewEnabled) {
            viewAsset(context, index, asset);
            return;
          }
          final selected = provider.selectedAssets.contains(asset);
          selectAsset(context, asset, index, selected);
        },
        child: ListenableBuilder(
          listenable: provider,
          builder: (context, child) {
            final selectionProvider = provider;
            final selectedIndex = selectionProvider.selectedAssets.indexOf(
              asset,
            );
            final selected = selectedIndex != -1;
            final showOriginalToggle =
                selected && asset.type == AssetType.image;
            final isOriginal =
                showOriginalToggle && selectionProvider.isMarkedOriginal(asset);
            return AnimatedContainer(
              duration: switchingPathDuration,
              padding: EdgeInsets.all(indicatorSize * .35),
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.45)
                  : theme.colorScheme.surface.withValues(alpha: 0.1),
              child: Stack(
                children: [
                  if (selected && !isSingleAssetMode)
                    Align(
                      alignment: AlignmentDirectional.topStart,
                      child: SizedBox(
                        height: indicatorSize / 2.5,
                        child: FittedBox(
                          alignment: AlignmentDirectional.topStart,
                          fit: BoxFit.cover,
                          child: Text(
                            '${selectedIndex + 1}',
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color
                                  ?.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (showOriginalToggle && isOriginal)
                    Align(
                      alignment: AlignmentDirectional.bottomStart,
                      child: IgnorePointer(
                        child: _OriginalToggleChip(
                          label: context.t.strings.legacy.msg_original_image,
                          selected: isOriginal,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget bottomActionBar(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, child) {
        final selectionProvider = provider;
        final bottomPadding = MediaQuery.paddingOf(context).bottom;
        final children = <Widget>[
          if (isPermissionLimited) accessLimitedBottomTip(context),
          if (hasBottomActions)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(
                top: selectionProvider.isSelectedNotEmpty ? 8 : 0,
                bottom: bottomPadding,
              ),
              color: theme.bottomAppBarTheme.color ?? theme.colorScheme.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selectionProvider.isSelectedNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        context.t.strings.legacy
                            .msg_gallery_original_selection_summary(
                              selectedCount:
                                  selectionProvider.selectedAssets.length,
                              originalCount:
                                  selectionProvider.originalSelectedCount,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  SizedBox(
                    height: bottomActionBarHeight,
                    child: Row(
                      children: [
                        if (isPreviewEnabled) previewButton(context),
                        if (selectionProvider.hasSelectedImages)
                          Padding(
                            padding: EdgeInsetsDirectional.only(
                              start: isPreviewEnabled ? 12 : 0,
                            ),
                            child: _BottomOriginalToggle(
                              selected: selectionProvider
                                  .isCurrentOriginalTargetMarked,
                              label:
                                  context.t.strings.legacy.msg_original_image,
                              onTap: selectionProvider
                                  .toggleOriginalForCurrentSelectedImage,
                            ),
                          ),
                        if (isPreviewEnabled || !isSingleAssetMode)
                          const Spacer(),
                        if (isPreviewEnabled || !isSingleAssetMode)
                          confirmButton(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ];
        if (children.isEmpty) return const SizedBox.shrink();
        return Column(mainAxisSize: MainAxisSize.min, children: children);
      },
    );
  }
}

Future<OriginalToggleGalleryAssetPickResult?>
pickGalleryAssetsWithOriginalToggle(
  BuildContext context, {
  int maxAssets = 100,
  bool useRootNavigator = true,
}) async {
  final requestOption = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );
  final permissionState = await AssetPicker.permissionCheck(
    requestOption: requestOption,
  );
  if (permissionState != PermissionState.authorized &&
      permissionState != PermissionState.limited) {
    return null;
  }
  if (!context.mounted) return null;

  const transitionDuration = Duration(milliseconds: 250);
  final provider = OriginalToggleAssetPickerProvider(
    maxAssets: maxAssets,
    requestType: RequestType.common,
    initializeDelayDuration: transitionDuration,
  );
  final themeColor = Theme.of(context).colorScheme.primary;
  final picker =
      AssetPicker<
        AssetEntity,
        AssetPathEntity,
        OriginalToggleAssetPickerBuilderDelegate
      >(
        permissionRequestOption: requestOption,
        builder: OriginalToggleAssetPickerBuilderDelegate(
          provider: provider,
          initialPermission: permissionState,
          pickerTheme: AssetPicker.themeData(themeColor),
          locale: Localizations.maybeLocaleOf(context),
          previewThumbnailSize: memoGalleryPreviewThumbnailSize,
          specialPickerType: SpecialPickerType.noPreview,
        ),
      );

  return Navigator.maybeOf(
    context,
    rootNavigator: useRootNavigator,
  )?.push<OriginalToggleGalleryAssetPickResult>(
    AssetPickerPageRoute<OriginalToggleGalleryAssetPickResult>(
      builder: (_) => picker,
    ),
  );
}

class _OriginalToggleChip extends StatelessWidget {
  const _OriginalToggleChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const selectedBg = Color(0xFFE36A5C);
    final bg = selected ? selectedBg : Colors.black.withValues(alpha: 0.58);
    final fg = Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: selected ? 0.92 : 0.72),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.26),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomOriginalToggle extends StatelessWidget {
  const _BottomOriginalToggle({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final inactiveBorder = Colors.white.withValues(alpha: 0.72);
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: selected ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: selected ? activeColor : inactiveBorder,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: selected
                ? Icon(
                    Icons.check,
                    size: 14,
                    color: theme.colorScheme.onPrimary,
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
