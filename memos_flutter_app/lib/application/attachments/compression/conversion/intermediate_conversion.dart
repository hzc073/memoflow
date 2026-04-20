import 'dart:io';

import 'package:path/path.dart' as p;

import '../compression_cache_store.dart';
import '../compression_models.dart';
import '../engines/compression_engine.dart';

class IntermediateConversionService {
  const IntermediateConversionService(this._cacheStore);

  final CompressionCacheStore _cacheStore;

  Future<IntermediateConversionResult> prepare({
    required CompressionPlan plan,
    required CompressionEngine engine,
  }) async {
    if (!plan.requiresInputConversion || plan.outputFormat == null) {
      return IntermediateConversionResult(
        sourcePath: plan.sourceProbe.path,
        cleanup: null,
      );
    }

    final root = await _cacheStore.resolveRootDirectory();
    final tmpDir = Directory(p.join(root.path, 'tmp'));
    if (!await tmpDir.exists()) {
      await tmpDir.create(recursive: true);
    }
    final path = p.join(
      tmpDir.path,
      '${plan.cacheKey}.convert.${_cacheStore.extensionForFormat(plan.outputFormat!)}',
    );
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
    await engine.convert(
      CompressionConversionRequest(
        sourcePath: plan.sourceProbe.path,
        outputPath: path,
        inputFormat: plan.sourceProbe.format,
        outputFormat: plan.outputFormat!,
        keepMetadata: plan.settings.keepMetadata,
        resizeTarget: null,
      ),
    );
    return IntermediateConversionResult(
      sourcePath: path,
      cleanup: () async {
        if (file.existsSync()) {
          await file.delete();
        }
      },
    );
  }
}

class IntermediateConversionResult {
  const IntermediateConversionResult({
    required this.sourcePath,
    required this.cleanup,
  });

  final String sourcePath;
  final Future<void> Function()? cleanup;
}
