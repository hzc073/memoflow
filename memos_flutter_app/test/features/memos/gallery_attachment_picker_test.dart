import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:memos_flutter_app/data/models/image_compression_settings.dart';
import 'package:memos_flutter_app/features/memos/gallery_attachment_original_picker.dart';
import 'package:memos_flutter_app/features/memos/gallery_attachment_picker.dart';

AssetEntity _asset({
  required String id,
  required AssetType type,
  String? title,
}) {
  return AssetEntity(
    id: id,
    typeInt: type.index,
    width: 16,
    height: 16,
    title: title,
  );
}

void main() {
  test(
    'ImageCompressionSettings defaults enable compression for new installs',
    () {
      expect(ImageCompressionSettings.defaults.enabled, isTrue);
      expect(
        ImageCompressionSettings.defaults.outputFormat,
        ImageCompressionOutputFormat.sameAsInput,
      );
    },
  );

  test('normalizeGalleryOriginalAssetIds keeps only selected images', () {
    final image = _asset(id: 'img-1', type: AssetType.image);
    final video = _asset(id: 'video-1', type: AssetType.video);

    final normalized = normalizeGalleryOriginalAssetIds(
      selectedAssets: [image, video],
      originalAssetIds: const {'img-1', 'video-1', 'missing'},
    );

    expect(normalized, {'img-1'});
  });

  test('shouldReadOriginalGalleryAssetFile only applies to marked images', () {
    final image = _asset(id: 'img-1', type: AssetType.image);
    final video = _asset(id: 'video-1', type: AssetType.video);

    expect(
      shouldReadOriginalGalleryAssetFile(
        asset: image,
        originalAssetIds: const {'img-1'},
      ),
      isTrue,
    );
    expect(
      shouldReadOriginalGalleryAssetFile(
        asset: image,
        originalAssetIds: const {'other'},
      ),
      isFalse,
    );
    expect(
      shouldReadOriginalGalleryAssetFile(
        asset: video,
        originalAssetIds: const {'video-1'},
      ),
      isFalse,
    );
  });

  test('buildPickedLocalAttachment defaults to gallery source', () {
    final attachment = buildPickedLocalAttachment(
      filePath: '/tmp/sample.png',
      filename: 'sample.png',
      size: 42,
    );

    expect(attachment.mimeType, 'image/png');
    expect(attachment.source, PickedLocalAttachmentSource.gallery);
    expect(attachment.skipCompression, isFalse);
  });

  test('buildPickedLocalAttachment can set skipCompression', () {
    final attachment = buildPickedLocalAttachment(
      filePath: '/tmp/sample.png',
      filename: 'sample.png',
      size: 42,
      skipCompression: true,
    );

    expect(attachment.mimeType, 'image/png');
    expect(attachment.skipCompression, isTrue);
  });

  test('buildPickedLocalAttachment can mark camera source', () {
    final attachment = buildPickedLocalAttachment(
      filePath: '/tmp/sample.mp4',
      filename: 'sample.mp4',
      size: 42,
      source: PickedLocalAttachmentSource.camera,
    );

    expect(attachment.mimeType, 'video/mp4');
    expect(attachment.source, PickedLocalAttachmentSource.camera);
    expect(attachment.skipCompression, isFalse);
  });

  test(
    'captureCameraAttachment returns a camera attachment from override',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'memo_gallery_camera_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final photo = File('${tempDir.path}${Platform.pathSeparator}captured.jpg')
        ..writeAsBytesSync(const [1, 2, 3, 4]);

      final attachment = await captureCameraAttachment(
        imagePicker: ImagePicker(),
        capturePhotoOverride: () async => XFile(photo.path),
      );

      expect(attachment, isNotNull);
      expect(attachment!.filePath, photo.path);
      expect(attachment.filename, 'captured.jpg');
      expect(attachment.mimeType, 'image/jpeg');
      expect(attachment.size, 4);
      expect(attachment.source, PickedLocalAttachmentSource.camera);
      expect(attachment.skipCompression, isFalse);
    },
  );

  test('captureCameraAttachment throws for missing file paths', () async {
    await expectLater(
      () => captureCameraAttachment(
        imagePicker: ImagePicker(),
        capturePhotoOverride: () async => XFile(''),
      ),
      throwsA(isA<CameraAttachmentFileMissingException>()),
    );
  });

  test(
    'OriginalToggleAssetPickerProvider clears original marks when unselected',
    () {
      final image = _asset(id: 'img-1', type: AssetType.image);
      final provider = OriginalToggleAssetPickerProvider(maxAssets: 10);

      provider.selectedAssets = [image];
      provider.toggleOriginalForAsset(image);
      expect(provider.originalAssetIds, {'img-1'});

      provider.selectedAssets = const [];
      expect(provider.originalAssetIds, isEmpty);
    },
  );

  test(
    'OriginalToggleAssetPickerProvider ignores non-image original toggles',
    () {
      final video = _asset(id: 'video-1', type: AssetType.video);
      final provider = OriginalToggleAssetPickerProvider(maxAssets: 10);

      provider.selectedAssets = [video];
      provider.toggleOriginalForAsset(video);

      expect(provider.originalAssetIds, isEmpty);
    },
  );

  test(
    'OriginalToggleAssetPickerProvider bottom toggle marks only last selected image',
    () {
      final image1 = _asset(id: 'img-1', type: AssetType.image);
      final image2 = _asset(id: 'img-2', type: AssetType.image);
      final video = _asset(id: 'video-1', type: AssetType.video);
      final provider = OriginalToggleAssetPickerProvider(maxAssets: 10);

      provider.selectedAssets = [image1, video, image2];
      provider.toggleOriginalForCurrentSelectedImage();

      expect(provider.originalAssetIds, {'img-2'});
      expect(provider.isCurrentOriginalTargetMarked, isTrue);
    },
  );

  test(
    'OriginalToggleAssetPickerProvider does not inherit original to new images',
    () {
      final image1 = _asset(id: 'img-1', type: AssetType.image);
      final image2 = _asset(id: 'img-2', type: AssetType.image);
      final provider = OriginalToggleAssetPickerProvider(maxAssets: 10);

      provider.selectedAssets = [image1];
      provider.toggleOriginalForCurrentSelectedImage();
      provider.selectAsset(image2);

      expect(provider.originalAssetIds, {'img-1'});
      expect(provider.isMarkedOriginal(image2), isFalse);
    },
  );

  test('buildOriginalTogglePickResult preserves assets and original ids', () {
    final image = _asset(id: 'img-1', type: AssetType.image);
    final provider = OriginalToggleAssetPickerProvider(maxAssets: 10);

    provider.selectedAssets = [image];
    provider.toggleOriginalForAsset(image);

    final result = buildOriginalTogglePickResult(provider);

    expect(result.assets, [image]);
    expect(result.originalAssetIds, {'img-1'});
  });

  test('shouldShowGridOriginalToggle follows compression visibility', () {
    expect(
      shouldShowGridOriginalToggle(
        showOriginalToggle: true,
        hasSelectedImages: true,
      ),
      isTrue,
    );
    expect(
      shouldShowGridOriginalToggle(
        showOriginalToggle: false,
        hasSelectedImages: true,
      ),
      isFalse,
    );
    expect(
      shouldShowGridOriginalToggle(
        showOriginalToggle: true,
        hasSelectedImages: false,
      ),
      isFalse,
    );
  });

  test(
    'shouldShowOriginalSelectionSummary matches original toggle visibility',
    () {
      expect(
        shouldShowOriginalSelectionSummary(
          showOriginalToggle: true,
          hasSelection: true,
        ),
        isTrue,
      );
      expect(
        shouldShowOriginalSelectionSummary(
          showOriginalToggle: false,
          hasSelection: true,
        ),
        isFalse,
      );
      expect(
        shouldShowOriginalSelectionSummary(
          showOriginalToggle: true,
          hasSelection: false,
        ),
        isFalse,
      );
    },
  );

  test('shouldShowOriginalBadge only applies to selected images', () {
    final image = _asset(id: 'img-1', type: AssetType.image);
    final video = _asset(id: 'video-1', type: AssetType.video);

    expect(
      shouldShowOriginalBadge(
        showOriginalToggle: true,
        selected: true,
        asset: image,
      ),
      isTrue,
    );
    expect(
      shouldShowOriginalBadge(
        showOriginalToggle: false,
        selected: true,
        asset: image,
      ),
      isFalse,
    );
    expect(
      shouldShowOriginalBadge(
        showOriginalToggle: true,
        selected: false,
        asset: image,
      ),
      isFalse,
    );
    expect(
      shouldShowOriginalBadge(
        showOriginalToggle: true,
        selected: true,
        asset: video,
      ),
      isFalse,
    );
  });

  test('shouldShowViewerOriginalToggle mirrors grid image rules', () {
    final image = _asset(id: 'img-1', type: AssetType.image);
    final video = _asset(id: 'video-1', type: AssetType.video);

    expect(
      shouldShowViewerOriginalToggle(
        showOriginalToggle: true,
        selected: true,
        asset: image,
      ),
      isTrue,
    );
    expect(
      shouldShowViewerOriginalToggle(
        showOriginalToggle: true,
        selected: false,
        asset: image,
      ),
      isFalse,
    );
    expect(
      shouldShowViewerOriginalToggle(
        showOriginalToggle: true,
        selected: true,
        asset: video,
      ),
      isFalse,
    );
  });
}
