import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/sync/compose_draft_transfer.dart';
import 'package:memos_flutter_app/application/sync/config_transfer/config_transfer_bundle.dart';
import 'package:memos_flutter_app/application/sync/config_transfer/config_transfer_codec.dart';
import 'package:memos_flutter_app/application/sync/migration/memoflow_migration_models.dart';
import 'package:memos_flutter_app/data/models/compose_draft.dart';
import 'package:memos_flutter_app/data/models/image_compression_settings.dart';

Map<String, dynamic> _decodeJsonBytes(List<int> bytes) {
  final decoded = jsonDecode(utf8.decode(bytes));
  return (decoded as Map).cast<String, dynamic>();
}

void main() {
  test('encode and decode preserve V2 image compression settings', () async {
    final codec = const ConfigTransferCodec();
    final settings = ImageCompressionSettings.defaults.copyWith(
      mode: ImageCompressionMode.size,
      outputFormat: ImageCompressionOutputFormat.tiff,
      lossless: true,
      keepMetadata: true,
      skipIfBigger: false,
      resize: ImageCompressionSettings.defaults.resize.copyWith(
        mode: ImageCompressionResizeMode.fixedWidth,
        width: 1440,
        height: 1080,
        edge: 1440,
        doNotEnlarge: false,
      ),
      jpeg: ImageCompressionSettings.defaults.jpeg.copyWith(
        quality: 73,
        chromaSubsampling: JpegChromaSubsampling.chroma444,
        progressive: false,
      ),
      png: ImageCompressionSettings.defaults.png.copyWith(
        quality: 63,
        optimizationLevel: 6,
      ),
      webp: ImageCompressionSettings.defaults.webp.copyWith(quality: 58),
      tiff: ImageCompressionSettings.defaults.tiff.copyWith(
        method: TiffCompressionMethod.deflate,
        deflatePreset: TiffDeflatePreset.best,
      ),
      sizeTarget: const ImageCompressionSizeTarget(
        value: 2,
        unit: ImageCompressionMaxOutputUnit.mb,
      ),
    );
    final files = codec.encode(
      ConfigTransferBundle(imageCompressionSettings: settings),
      configTypes: const <MemoFlowMigrationConfigType>{
        MemoFlowMigrationConfigType.imageCompressionSettings,
      },
    );

    expect(files.keys, {ConfigTransferCodec.imageCompressionSettingsPath});
    final encodedJson = _decodeJsonBytes(
      files[ConfigTransferCodec.imageCompressionSettingsPath]!,
    );
    expect(
      encodedJson['schemaVersion'],
      ImageCompressionSettings.currentSchemaVersion,
    );
    expect(encodedJson['outputFormat'], 'tiff');
    expect(encodedJson['mode'], 'size');
    expect(encodedJson['resize'], isA<Map>());
    expect(encodedJson['jpeg'], isA<Map>());
    expect(encodedJson['png'], isA<Map>());
    expect(encodedJson['webp'], isA<Map>());
    expect(encodedJson['tiff'], isA<Map>());
    expect(encodedJson['sizeTarget'], isA<Map>());

    final dir = await Directory.systemTemp.createTemp('config_transfer_codec_');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    final file = File(
      '${dir.path}${Platform.pathSeparator}${ConfigTransferCodec.imageCompressionSettingsPath.replaceAll('/', Platform.pathSeparator)}',
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      files[ConfigTransferCodec.imageCompressionSettingsPath]!,
      flush: true,
    );

    final decodedBundle = await codec.decodeFromDirectory(dir);
    expect(decodedBundle.imageCompressionSettings, isNotNull);
    expect(decodedBundle.imageCompressionSettings!.toJson(), settings.toJson());
  });

  test('encode fails when draft attachment file is missing', () {
    final codec = const ConfigTransferCodec();
    final bundle = ConfigTransferBundle(
      draftBox: ComposeDraftTransferBundle.fromDraftRecords(
        <ComposeDraftRecord>[
          ComposeDraftRecord(
            uid: 'draft-1',
            workspaceKey: 'workspace-1',
            snapshot: const ComposeDraftSnapshot(
              content: 'draft with missing attachment',
              visibility: 'PRIVATE',
              attachments: <ComposeDraftAttachment>[
                ComposeDraftAttachment(
                  uid: 'attachment-1',
                  filePath: 'Z:/definitely-missing/attachment.txt',
                  filename: 'attachment.txt',
                  mimeType: 'text/plain',
                  size: 10,
                ),
              ],
            ),
            createdTime: DateTime.fromMillisecondsSinceEpoch(10, isUtc: true),
            updatedTime: DateTime.fromMillisecondsSinceEpoch(20, isUtc: true),
          ),
        ],
      ),
    );

    expect(
      () => codec.encode(
        bundle,
        configTypes: const <MemoFlowMigrationConfigType>{
          MemoFlowMigrationConfigType.draftBox,
        },
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
}
