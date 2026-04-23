import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/db/db_write_protocol.dart';
import 'package:memos_flutter_app/data/db/desktop_db_write_gateway.dart';
import 'package:memos_flutter_app/data/ai/ai_analysis_models.dart';
import 'package:memos_flutter_app/data/ai/ai_analysis_repository.dart';
import 'package:memos_flutter_app/data/db/app_database.dart';

import '../../test_support.dart';

void main() {
  late TestSupport support;

  setUpAll(() async {
    support = await initializeTestSupport();
  });

  tearDownAll(() async {
    await support.dispose();
  });

  test(
    'analysis history preserves whether public memos were included',
    () async {
      final dbName = uniqueDbName('ai_analysis_history_scope');
      final db = AppDatabase(dbName: dbName);
      final repository = AiAnalysisRepository(db);

      addTearDown(() async {
        await db.close();
        await deleteTestDatabase(dbName);
      });

      final taskId = await repository.createAnalysisTask(
        taskUid: 'task-private-only',
        analysisType: AiAnalysisType.emotionMap,
        status: AiTaskStatus.completed,
        rangeStart: DateTime.utc(2026, 3, 1).millisecondsSinceEpoch ~/ 1000,
        rangeEndExclusive:
            DateTime.utc(2026, 3, 8).millisecondsSinceEpoch ~/ 1000,
        includePublic: false,
        includePrivate: true,
        includeProtected: false,
        promptTemplate: 'Reflect on the week with care.',
        generationProfileKey: 'gen-default',
        embeddingProfileKey: 'embed-default',
        retrievalProfile: const <String, dynamic>{'include_public': false},
      );

      await repository.saveAnalysisResult(
        taskId: taskId,
        result: const AiStructuredAnalysisResult(
          schemaVersion: 1,
          analysisType: AiAnalysisType.emotionMap,
          summary: 'A private-only reflection.',
          sections: <AiAnalysisSectionData>[
            AiAnalysisSectionData(
              sectionKey: 'main',
              title: '',
              body: 'This week felt quieter and more internal.',
              evidenceKeys: <String>[],
            ),
          ],
          evidences: <AiAnalysisEvidenceData>[],
          followUpSuggestions: <String>[],
          rawResponseText: '{}',
        ),
      );

      final history = await repository.listAnalysisReportHistory(
        analysisType: AiAnalysisType.emotionMap,
      );

      expect(history, hasLength(1));
      expect(history.single.includePublic, isFalse);
      expect(history.single.includePrivate, isTrue);
      expect(history.single.includeProtected, isFalse);
    },
  );

  test('analysis history returns all rows when limit is null', () async {
    final dbName = uniqueDbName('ai_analysis_history_all_rows');
    final db = AppDatabase(dbName: dbName);
    final repository = AiAnalysisRepository(db);

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    for (var index = 0; index < 3; index++) {
      final taskId = await repository.createAnalysisTask(
        taskUid: 'task-all-$index',
        analysisType: AiAnalysisType.emotionMap,
        status: AiTaskStatus.completed,
        rangeStart:
            DateTime.utc(2026, 3, 1 + index).millisecondsSinceEpoch ~/ 1000,
        rangeEndExclusive:
            DateTime.utc(2026, 3, 2 + index).millisecondsSinceEpoch ~/ 1000,
        includePublic: true,
        includePrivate: true,
        includeProtected: false,
        promptTemplate: 'Prompt $index',
        generationProfileKey: 'gen-default',
        embeddingProfileKey: 'embed-default',
        retrievalProfile: const <String, dynamic>{'include_public': true},
      );
      await repository.saveAnalysisResult(
        taskId: taskId,
        result: AiStructuredAnalysisResult(
          schemaVersion: 1,
          analysisType: AiAnalysisType.emotionMap,
          summary: 'Summary $index',
          sections: const <AiAnalysisSectionData>[],
          evidences: const <AiAnalysisEvidenceData>[],
          followUpSuggestions: const <String>[],
          rawResponseText: '{}',
        ),
      );
    }

    final unlimited = await repository.listAnalysisReportHistory(
      analysisType: AiAnalysisType.emotionMap,
      limit: null,
    );
    final limited = await repository.listAnalysisReportHistory(
      analysisType: AiAnalysisType.emotionMap,
      limit: 2,
    );

    expect(unlimited, hasLength(3));
    expect(limited, hasLength(2));
    expect(
      unlimited.map((entry) => entry.summary),
      containsAll(<String>['Summary 0', 'Summary 1', 'Summary 2']),
    );
  });

  test('analysis history preserves template metadata snapshots', () async {
    final dbName = uniqueDbName('ai_analysis_history_template_meta');
    final db = AppDatabase(dbName: dbName);
    final repository = AiAnalysisRepository(db);

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    final taskId = await repository.createAnalysisTask(
      taskUid: 'task-template-meta',
      analysisType: AiAnalysisType.emotionMap,
      status: AiTaskStatus.completed,
      rangeStart: DateTime.utc(2026, 3, 1).millisecondsSinceEpoch ~/ 1000,
      rangeEndExclusive:
          DateTime.utc(2026, 3, 8).millisecondsSinceEpoch ~/ 1000,
      includePublic: true,
      includePrivate: true,
      includeProtected: false,
      promptTemplate: 'Analyze my week.',
      templateKind: AiAnalysisTemplateKind.custom,
      templateId: 'tpl_weekly',
      templateTitleSnapshot: 'Weekly Lens',
      templateIconKeySnapshot: 'star',
      generationProfileKey: 'gen-default',
      embeddingProfileKey: 'embed-default',
      retrievalProfile: const <String, dynamic>{'include_public': true},
    );

    await repository.saveAnalysisResult(
      taskId: taskId,
      result: const AiStructuredAnalysisResult(
        schemaVersion: 1,
        analysisType: AiAnalysisType.emotionMap,
        summary: 'A weekly reflection.',
        sections: <AiAnalysisSectionData>[],
        evidences: <AiAnalysisEvidenceData>[],
        followUpSuggestions: <String>[],
        rawResponseText: '{}',
      ),
    );

    final history = await repository.listAnalysisReportHistory(
      analysisType: AiAnalysisType.emotionMap,
    );

    expect(history.single.templateKind, AiAnalysisTemplateKind.custom);
    expect(history.single.templateId, 'tpl_weekly');
    expect(history.single.templateTitleSnapshot, 'Weekly Lens');
    expect(history.single.templateIconKeySnapshot, 'star');
  });

  test('createAnalysisTask uses write gateway when configured', () async {
    final dbName = uniqueDbName('ai_analysis_gateway_proxy');
    final db = AppDatabase(dbName: dbName, workspaceKey: 'workspace-ai-proxy');
    final gateway = _CapturingRemoteGateway(responseValue: 42);
    final repository = AiAnalysisRepository(db, writeGateway: gateway);

    addTearDown(() async {
      await db.close();
      await deleteTestDatabase(dbName);
    });

    final taskId = await repository.createAnalysisTask(
      taskUid: 'task-proxy',
      analysisType: AiAnalysisType.emotionMap,
      status: AiTaskStatus.queued,
      rangeStart: 100,
      rangeEndExclusive: 200,
      includePublic: true,
      includePrivate: true,
      includeProtected: false,
      promptTemplate: 'Proxy prompt',
      generationProfileKey: 'gen-proxy',
      embeddingProfileKey: 'embed-proxy',
      retrievalProfile: const <String, dynamic>{'sample': true},
    );

    expect(taskId, 42);
    expect(gateway.localExecuteCalled, isFalse);
    expect(gateway.workspaceKey, 'workspace-ai-proxy');
    expect(gateway.dbName, dbName);
    expect(gateway.commandType, aiAnalysisRepositoryWriteCommandType);
    expect(gateway.operation, 'createAnalysisTask');
    expect(gateway.payload['taskUid'], 'task-proxy');
    expect(gateway.payload['templateKind'], 'legacy');
    expect(gateway.payload['retrievalProfile'], const <String, dynamic>{
      'sample': true,
    });

    final rows = await (await db.db).query('ai_analysis_tasks');
    expect(rows, isEmpty);
  });
}

class _CapturingRemoteGateway implements DesktopDbWriteGateway {
  _CapturingRemoteGateway({this.responseValue});

  final Object? responseValue;

  bool localExecuteCalled = false;
  String? workspaceKey;
  String? dbName;
  String? commandType;
  String? operation;
  Map<String, dynamic> payload = const <String, dynamic>{};

  @override
  bool get isRemote => true;

  @override
  Future<T> execute<T>({
    required String workspaceKey,
    required String dbName,
    required String commandType,
    required String operation,
    required Map<String, dynamic> payload,
    required Future<Object?> Function() localExecute,
    required T Function(Object? raw) decode,
  }) async {
    this.workspaceKey = workspaceKey;
    this.dbName = dbName;
    this.commandType = commandType;
    this.operation = operation;
    this.payload = Map<String, dynamic>.from(payload);
    return decode(responseValue);
  }
}
