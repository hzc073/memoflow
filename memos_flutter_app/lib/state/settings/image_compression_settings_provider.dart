import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/sync_request.dart';
import '../../data/models/image_compression_settings.dart';
import '../../data/repositories/image_compression_settings_repository.dart';
import '../sync/sync_coordinator_provider.dart';
import '../system/session_provider.dart';

final imageCompressionSettingsRepositoryProvider =
    Provider<ImageCompressionSettingsRepository>((ref) {
      final session = ref.watch(appSessionProvider).valueOrNull;
      final key = session?.currentKey?.trim();
      final storageKey = (key == null || key.isEmpty) ? 'device' : key;
      return ImageCompressionSettingsRepository(
        ref.watch(secureStorageProvider),
        accountKey: storageKey,
      );
    });

final imageCompressionSettingsProvider =
    StateNotifierProvider<
      ImageCompressionSettingsController,
      ImageCompressionSettings
    >((ref) {
      return ImageCompressionSettingsController(
        ref,
        ref.watch(imageCompressionSettingsRepositoryProvider),
      );
    });

class ImageCompressionUiPolicy {
  const ImageCompressionUiPolicy({
    required this.enabled,
    required this.showOriginalToggle,
  });

  final bool enabled;
  final bool showOriginalToggle;
}

final imageCompressionUiPolicyProvider = Provider<ImageCompressionUiPolicy>((
  ref,
) {
  final settings = ref.watch(imageCompressionSettingsProvider);
  return ImageCompressionUiPolicy(
    enabled: settings.enabled,
    showOriginalToggle: settings.enabled,
  );
});

class ImageCompressionSettingsController
    extends StateNotifier<ImageCompressionSettings> {
  ImageCompressionSettingsController(this._ref, this._repo)
    : super(ImageCompressionSettings.defaults) {
    unawaited(_load());
  }

  final Ref _ref;
  final ImageCompressionSettingsRepository _repo;

  Future<void> _load() async {
    final stored = await _repo.read();
    state = stored;
  }

  void _setAndPersist(
    ImageCompressionSettings next, {
    bool triggerSync = true,
  }) {
    state = next;
    unawaited(_repo.write(next));
    if (triggerSync) {
      unawaited(
        _ref
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
              const SyncRequest(
                kind: SyncRequestKind.webDavSync,
                reason: SyncRequestReason.settings,
              ),
            ),
      );
    }
  }

  void setEnabled(bool value) => _setAndPersist(state.copyWith(enabled: value));

  void setMode(ImageCompressionMode value) =>
      _setAndPersist(state.copyWith(mode: value));

  void setOutputFormat(ImageCompressionOutputFormat value) =>
      _setAndPersist(state.copyWith(outputFormat: value));

  void setLossless(bool value) =>
      _setAndPersist(state.copyWith(lossless: value));

  void setKeepMetadata(bool value) =>
      _setAndPersist(state.copyWith(keepMetadata: value));

  void setSkipIfBigger(bool value) =>
      _setAndPersist(state.copyWith(skipIfBigger: value));

  void setResizeEnabled(bool value) => _setAndPersist(
    state.copyWith(resize: state.resize.copyWith(enabled: value)),
  );

  void setResizeMode(ImageCompressionResizeMode value) => _setAndPersist(
    state.copyWith(resize: state.resize.copyWith(mode: value)),
  );

  void setResizeWidth(int value) => _setAndPersist(
    state.copyWith(resize: state.resize.copyWith(width: value)),
  );

  void setResizeHeight(int value) => _setAndPersist(
    state.copyWith(resize: state.resize.copyWith(height: value)),
  );

  void setResizeEdge(int value) => _setAndPersist(
    state.copyWith(resize: state.resize.copyWith(edge: value)),
  );

  void setResizeDoNotEnlarge(bool value) => _setAndPersist(
    state.copyWith(resize: state.resize.copyWith(doNotEnlarge: value)),
  );

  void setJpegQuality(int value) =>
      _setAndPersist(state.copyWith(jpeg: state.jpeg.copyWith(quality: value)));

  void setJpegChromaSubsampling(JpegChromaSubsampling value) => _setAndPersist(
    state.copyWith(jpeg: state.jpeg.copyWith(chromaSubsampling: value)),
  );

  void setJpegProgressive(bool value) => _setAndPersist(
    state.copyWith(jpeg: state.jpeg.copyWith(progressive: value)),
  );

  void setPngQuality(int value) =>
      _setAndPersist(state.copyWith(png: state.png.copyWith(quality: value)));

  void setPngOptimizationLevel(int value) => _setAndPersist(
    state.copyWith(png: state.png.copyWith(optimizationLevel: value)),
  );

  void setWebpQuality(int value) =>
      _setAndPersist(state.copyWith(webp: state.webp.copyWith(quality: value)));

  void setTiffMethod(TiffCompressionMethod value) =>
      _setAndPersist(state.copyWith(tiff: state.tiff.copyWith(method: value)));

  void setTiffDeflatePreset(TiffDeflatePreset value) => _setAndPersist(
    state.copyWith(tiff: state.tiff.copyWith(deflatePreset: value)),
  );

  void setSizeTargetValue(int value) => _setAndPersist(
    state.copyWith(sizeTarget: state.sizeTarget.copyWith(value: value)),
  );

  void setSizeTargetUnit(ImageCompressionMaxOutputUnit value) => _setAndPersist(
    state.copyWith(sizeTarget: state.sizeTarget.copyWith(unit: value)),
  );

  Future<void> setAll(
    ImageCompressionSettings next, {
    bool triggerSync = true,
  }) async {
    state = next;
    await _repo.write(next);
    if (triggerSync) {
      unawaited(
        _ref
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
              const SyncRequest(
                kind: SyncRequestKind.webDavSync,
                reason: SyncRequestReason.settings,
              ),
            ),
      );
    }
  }
}
