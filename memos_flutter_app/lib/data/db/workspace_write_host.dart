import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

import '../../core/desktop_db_write_channel.dart';
import '../logs/log_manager.dart';
import 'db_write_protocol.dart';
import 'serialized_workspace_write_runner.dart';

abstract class WorkspaceWriteHost {
  Future<T> execute<T>({
    required DbWriteEnvelope envelope,
    required Future<Object?> Function() localExecute,
    required T Function(Object? raw) decode,
  });
}

class SerializingWorkspaceWriteHost implements WorkspaceWriteHost {
  static const int _debugQueueWaitLogThresholdMs = 200;
  static const int _debugExecutionLogThresholdMs = 500;

  SerializingWorkspaceWriteHost({
    required SerializedWorkspaceWriteRunner runner,
    required DesktopDbChangeBroadcaster broadcaster,
  }) : _runner = runner,
       _broadcaster = broadcaster;

  final SerializedWorkspaceWriteRunner _runner;
  final DesktopDbChangeBroadcaster _broadcaster;

  @override
  Future<T> execute<T>({
    required DbWriteEnvelope envelope,
    required Future<Object?> Function() localExecute,
    required T Function(Object? raw) decode,
  }) async {
    final queueKey = '${envelope.workspaceKey}|${envelope.dbName}';
    final totalStopwatch = Stopwatch()..start();
    final executionStopwatch = Stopwatch();
    var queueWaitMs = 0;

    try {
      final result = await _runner.run<Object?>(queueKey, () async {
        queueWaitMs = totalStopwatch.elapsedMilliseconds;
        executionStopwatch.start();
        try {
          return await localExecute();
        } finally {
          executionStopwatch.stop();
        }
      });
      await _broadcaster.broadcast(
        DesktopDbChangeEvent(
          workspaceKey: envelope.workspaceKey,
          dbName: envelope.dbName,
          changeId: envelope.requestId,
          category: '${envelope.commandType}.${envelope.operation}',
          originWindowId: envelope.originWindowId,
        ),
      );
      final decoded = decode(result);
      final executionMs = executionStopwatch.elapsedMilliseconds;
      final totalMs = totalStopwatch.elapsedMilliseconds;
      final shouldLogCompletedWrite =
          !kDebugMode ||
          queueWaitMs >= _debugQueueWaitLogThresholdMs ||
          executionMs >= _debugExecutionLogThresholdMs;
      if (shouldLogCompletedWrite) {
        LogManager.instance.info(
          'Desktop DB write: completed',
          context: <String, Object?>{
            'requestId': envelope.requestId,
            'workspaceKey': envelope.workspaceKey,
            'dbName': envelope.dbName,
            'originRole': envelope.originRole,
            'originWindowId': envelope.originWindowId,
            'commandType': envelope.commandType,
            'operation': envelope.operation,
            'queueWaitMs': queueWaitMs,
            'executionMs': executionMs,
            'totalMs': totalMs,
          },
        );
      }
      return decoded;
    } catch (error, stackTrace) {
      LogManager.instance.warn(
        'Desktop DB write: failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'requestId': envelope.requestId,
          'workspaceKey': envelope.workspaceKey,
          'dbName': envelope.dbName,
          'originRole': envelope.originRole,
          'originWindowId': envelope.originWindowId,
          'commandType': envelope.commandType,
          'operation': envelope.operation,
          'queueWaitMs': queueWaitMs,
          'executionMs': executionStopwatch.elapsedMilliseconds,
          'totalMs': totalStopwatch.elapsedMilliseconds,
        },
      );
      rethrow;
    } finally {
      totalStopwatch.stop();
    }
  }
}

class DesktopDbChangeBroadcaster {
  const DesktopDbChangeBroadcaster();

  Future<void> broadcast(DesktopDbChangeEvent event) async {
    if (kIsWeb) return;
    try {
      final ids = await DesktopMultiWindow.getAllSubWindowIds();
      for (final id in ids) {
        if (id == event.originWindowId) continue;
        try {
          await DesktopMultiWindow.invokeMethod(
            id,
            desktopDbChangedMethod,
            event.toJson(),
          );
        } catch (_) {}
      }
    } catch (_) {}
  }
}
