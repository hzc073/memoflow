import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/application/attachments/compression/compression_models.dart';
import 'package:memos_flutter_app/application/attachments/compression/compression_source_probe.dart';
import 'package:memos_flutter_app/application/attachments/queued_attachment_stager.dart';

import '../../test_support.dart';

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  Future<QueuedAttachmentStager> createStager({
    CopyContentUriToLocalFile? copyContentUriToLocalFile,
    CompressionSourceProbeService? imageProbeService,
  }) async {
    final supportDir = await support.createTempDir('queued_stager_support');
    return QueuedAttachmentStager(
      resolveSupportDirectory: () async => supportDir,
      copyContentUriToLocalFile: copyContentUriToLocalFile,
      imageProbeService: imageProbeService,
    );
  }

  Future<File> createSourceFile(
    String prefix, {
    String filename = 'sample.png',
  }) async {
    final dir = await support.createTempDir(prefix);
    final file = File('${dir.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(const <int>[137, 80, 78, 71, 1, 2, 3, 4]);
    return file;
  }

  test('stageDraftAttachment copies local files into managed root', () async {
    final sourceFile = await createSourceFile('queued_stager_local');
    final stager = await createStager();

    final staged = await stager.stageDraftAttachment(
      uid: 'att-1',
      filePath: sourceFile.path,
      filename: 'sample.png',
      mimeType: 'image/png',
      size: await sourceFile.length(),
      scopeKey: 'memo-1',
    );

    expect(stager.isManagedPath(staged.filePath), isTrue);
    expect(staged.filePath, isNot(sourceFile.path));
    expect(File(staged.filePath).existsSync(), isTrue);
    expect(
      File(staged.filePath).readAsBytesSync(),
      sourceFile.readAsBytesSync(),
    );
  });

  test(
    'stageDraftAttachment copies content uri via injected callback',
    () async {
      final copied = <String, String>{};
      final stager = await createStager(
        copyContentUriToLocalFile: (sourceUri, destinationPath) async {
          copied['source'] = sourceUri;
          copied['destination'] = destinationPath;
          await File(destinationPath).writeAsString('hello');
        },
      );

      final staged = await stager.stageDraftAttachment(
        uid: 'att-1',
        filePath: 'content://media/external/file/1',
        filename: 'sample.txt',
        mimeType: 'text/plain',
        size: 0,
        scopeKey: 'memo-1',
      );

      expect(copied['source'], 'content://media/external/file/1');
      expect(copied['destination'], endsWith('.part'));
      expect(File(staged.filePath).readAsStringSync(), 'hello');
      expect(staged.size, 5);
    },
  );

  test('stageDraftAttachment is idempotent for managed files', () async {
    final sourceFile = await createSourceFile('queued_stager_idempotent');
    final stager = await createStager();

    final first = await stager.stageDraftAttachment(
      uid: 'att-1',
      filePath: sourceFile.path,
      filename: 'sample.png',
      mimeType: 'image/png',
      size: await sourceFile.length(),
      scopeKey: 'memo-1',
    );
    final second = await stager.stageDraftAttachment(
      uid: 'att-1',
      filePath: first.filePath,
      filename: first.filename,
      mimeType: first.mimeType,
      size: first.size,
      scopeKey: 'memo-1',
    );

    expect(second.filePath, first.filePath);
    expect(second.size, first.size);
  });

  test('managed content uri is not copied again when restaged', () async {
    var copyCount = 0;
    final stager = await createStager(
      copyContentUriToLocalFile: (sourceUri, destinationPath) async {
        copyCount += 1;
        await File(destinationPath).writeAsString(sourceUri);
      },
    );

    final first = await stager.stageDraftAttachment(
      uid: 'att-1',
      filePath: 'content://media/external/file/1',
      filename: 'sample.txt',
      mimeType: 'text/plain',
      size: 0,
      scopeKey: 'memo-1',
    );
    final second = await stager.stageDraftAttachment(
      uid: 'att-1',
      filePath: first.filePath,
      filename: first.filename,
      mimeType: first.mimeType,
      size: first.size,
      scopeKey: 'memo-1',
    );

    expect(copyCount, 1);
    expect(second.filePath, first.filePath);
  });

  test('stageUploadPayload returns managed files without re-staging', () async {
    var copyCount = 0;
    final stager = await createStager(
      copyContentUriToLocalFile: (sourceUri, destinationPath) async {
        copyCount += 1;
        await File(destinationPath).writeAsString(sourceUri);
      },
    );
    final staged = await stager.stageDraftAttachment(
      uid: 'att-1',
      filePath: 'content://media/external/file/1',
      filename: 'sample.txt',
      mimeType: 'text/plain',
      size: 0,
      scopeKey: 'memo-1',
    );

    final payload = await stager.stageUploadPayload({
      'uid': staged.uid,
      'memo_uid': 'memo-1',
      'file_path': staged.filePath,
      'filename': staged.filename,
      'mime_type': staged.mimeType,
      'file_size': staged.size,
    }, scopeKey: 'memo-1');

    expect(copyCount, 1);
    expect(payload['file_path'], staged.filePath);
    expect(payload['file_size'], staged.size);
  });

  test('image diagnostics are not required for stage completion', () async {
    final sourceFile = await createSourceFile('queued_stager_probe_async');
    final probeService = _BlockingProbeService();
    final stager = await createStager(imageProbeService: probeService);

    final staged = await stager
        .stageDraftAttachment(
          uid: 'att-1',
          filePath: sourceFile.path,
          filename: 'sample.png',
          mimeType: 'image/png',
          size: await sourceFile.length(),
          scopeKey: 'memo-1',
        )
        .timeout(const Duration(seconds: 2));

    expect(File(staged.filePath).existsSync(), isTrue);
    probeService.complete();
  });

  test('stageDraftAttachments preserves input order', () async {
    final completions = <String>[];
    final stager = await createStager(
      copyContentUriToLocalFile: (sourceUri, destinationPath) async {
        if (sourceUri.endsWith('/1')) {
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
        if (sourceUri.endsWith('/2')) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        completions.add(sourceUri);
        await File(destinationPath).writeAsString(sourceUri);
      },
    );

    final results = await stager.stageDraftAttachments(const [
      DraftAttachmentStageRequest(
        uid: 'att-1',
        filePath: 'content://media/external/file/1',
        filename: '1.txt',
        mimeType: 'text/plain',
        size: 0,
        scopeKey: 'memo-1',
      ),
      DraftAttachmentStageRequest(
        uid: 'att-2',
        filePath: 'content://media/external/file/2',
        filename: '2.txt',
        mimeType: 'text/plain',
        size: 0,
        scopeKey: 'memo-1',
      ),
      DraftAttachmentStageRequest(
        uid: 'att-3',
        filePath: 'content://media/external/file/3',
        filename: '3.txt',
        mimeType: 'text/plain',
        size: 0,
        scopeKey: 'memo-1',
      ),
    ]);

    expect(completions.first, isNot('content://media/external/file/1'));
    expect(results.map((item) => item.uid), ['att-1', 'att-2', 'att-3']);
    expect(results.map((item) => item.filename), ['1.txt', '2.txt', '3.txt']);
  });

  test('stageDraftAttachment fails when source file is missing', () async {
    final stager = await createStager();
    final missingPath =
        '${(await support.createTempDir('queued_stager_missing')).path}${Platform.pathSeparator}missing.png';

    await expectLater(
      () => stager.stageDraftAttachment(
        uid: 'att-1',
        filePath: missingPath,
        filename: 'missing.png',
        mimeType: 'image/png',
        size: 0,
        scopeKey: 'memo-1',
      ),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('deleteManagedFile only deletes files under managed root', () async {
    final sourceFile = await createSourceFile('queued_stager_delete');
    final externalFile = await createSourceFile(
      'queued_stager_external',
      filename: 'external.txt',
    );
    final stager = await createStager();

    final staged = await stager.stageDraftAttachment(
      uid: 'att-1',
      filePath: sourceFile.path,
      filename: 'sample.png',
      mimeType: 'image/png',
      size: await sourceFile.length(),
      scopeKey: 'memo-1',
    );

    await stager.deleteManagedFile(externalFile.path);
    expect(externalFile.existsSync(), isTrue);

    await stager.deleteManagedFile(staged.filePath);
    expect(File(staged.filePath).existsSync(), isFalse);
  });
}

class _BlockingProbeService extends CompressionSourceProbeService {
  final Completer<void> _completer = Completer<void>();

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  @override
  Future<CompressionSourceProbe> probe({
    required String path,
    required String filename,
    required String mimeType,
  }) async {
    await _completer.future;
    return CompressionSourceProbe(
      path: path,
      filename: filename,
      mimeType: mimeType,
      fileSize: 0,
      format: CompressionImageFormat.png,
      width: null,
      height: null,
      displayWidth: null,
      displayHeight: null,
      orientation: 1,
      hasAlpha: false,
      isAnimated: false,
      isImage: true,
    );
  }
}
