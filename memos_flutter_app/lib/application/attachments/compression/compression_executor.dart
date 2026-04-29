import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

typedef CompressionWork<T> = FutureOr<T> Function();

abstract class CompressionExecutor {
  Future<T> run<T>({String? key, required CompressionWork<T> work});

  Future<T> runIsolated<T>({String? key, required CompressionWork<T> work});
}

class ImmediateCompressionExecutor implements CompressionExecutor {
  const ImmediateCompressionExecutor();

  @override
  Future<T> run<T>({String? key, required CompressionWork<T> work}) {
    return Future<T>.sync(work);
  }

  @override
  Future<T> runIsolated<T>({String? key, required CompressionWork<T> work}) {
    return Future<T>.sync(work);
  }
}

class BoundedCompressionExecutor implements CompressionExecutor {
  BoundedCompressionExecutor({int maxConcurrentJobs = 1})
    : maxConcurrentJobs = maxConcurrentJobs < 1 ? 1 : maxConcurrentJobs;

  final int maxConcurrentJobs;
  final Queue<_QueuedCompressionJob<dynamic>> _queue =
      Queue<_QueuedCompressionJob<dynamic>>();
  final Map<String, Future<dynamic>> _inFlight = <String, Future<dynamic>>{};
  int _running = 0;

  @override
  Future<T> run<T>({String? key, required CompressionWork<T> work}) {
    final normalizedKey = key?.trim();
    if (normalizedKey != null && normalizedKey.isNotEmpty) {
      final existing = _inFlight[normalizedKey];
      if (existing != null) {
        return existing.then((value) => value as T);
      }
    }

    final completer = Completer<T>();
    final future = completer.future;
    if (normalizedKey != null && normalizedKey.isNotEmpty) {
      _inFlight[normalizedKey] = future;
      future.then(
        (_) => _removeInFlight(normalizedKey, future),
        onError: (_, _) => _removeInFlight(normalizedKey, future),
      );
    }

    _queue.add(_QueuedCompressionJob<T>(completer: completer, work: work));
    _drain();
    return future;
  }

  @override
  Future<T> runIsolated<T>({String? key, required CompressionWork<T> work}) {
    return run<T>(key: key, work: () => Isolate.run<T>(work));
  }

  void _removeInFlight(String key, Future<dynamic> future) {
    if (identical(_inFlight[key], future)) {
      _inFlight.remove(key);
    }
  }

  void _drain() {
    while (_running < maxConcurrentJobs && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      _running += 1;
      unawaited(_runJob(job));
    }
  }

  Future<void> _runJob<T>(_QueuedCompressionJob<T> job) async {
    try {
      final result = await Future<T>.sync(job.work);
      if (!job.completer.isCompleted) {
        job.completer.complete(result);
      }
    } catch (error, stackTrace) {
      if (!job.completer.isCompleted) {
        job.completer.completeError(error, stackTrace);
      }
    } finally {
      _running -= 1;
      _drain();
    }
  }
}

class _QueuedCompressionJob<T> {
  const _QueuedCompressionJob({required this.completer, required this.work});

  final Completer<T> completer;
  final CompressionWork<T> work;
}
