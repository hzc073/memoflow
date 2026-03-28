import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import 'memoflow_migration_models.dart';
import 'memoflow_migration_protocol.dart';

class MemoFlowMigrationDiscoveryService {
  const MemoFlowMigrationDiscoveryService({
    BonsoirDiscovery Function({required String type})? discoveryFactory,
  }) : _discoveryFactory = discoveryFactory;

  final BonsoirDiscovery Function({required String type})? _discoveryFactory;

  Future<List<MemoFlowMigrationSessionDescriptor>> discover({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final discovery =
        (_discoveryFactory ?? _defaultDiscoveryFactory)(
          type: memoFlowMigrationServiceType,
        );
    final candidates = <String, _DiscoveredReceiverCandidate>{};

    void mergeService(BonsoirService service) {
      final key = _serviceKey(service);
      final next = (candidates[key] ?? const _DiscoveredReceiverCandidate())
          .merge(service);
      candidates[key] = next;
    }

    await discovery.initialize();
    final subscription = discovery.eventStream?.listen((event) async {
      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent():
          mergeService(event.service);
          try {
            await discovery.serviceResolver.resolveService(event.service);
          } catch (_) {}
        case BonsoirDiscoveryServiceResolvedEvent():
          mergeService(event.service);
        case BonsoirDiscoveryServiceUpdatedEvent():
          mergeService(event.service);
        case BonsoirDiscoveryServiceLostEvent():
          candidates.remove(_serviceKey(event.service));
        default:
          break;
      }
    });

    try {
      await discovery.start();
      await Future<void>.delayed(timeout);
    } finally {
      await discovery.stop();
      await subscription?.cancel();
    }

    final results = candidates.values
        .map((candidate) => candidate.toDescriptor())
        .whereType<MemoFlowMigrationSessionDescriptor>()
        .toList(growable: false)
      ..sort((a, b) => a.receiverDeviceName.compareTo(b.receiverDeviceName));
    return results;
  }

  static BonsoirDiscovery _defaultDiscoveryFactory({
    required String type,
  }) {
    return BonsoirDiscovery(type: type);
  }

  String _serviceKey(BonsoirService service) {
    final sessionId = service.attributes['sid']?.trim() ?? '';
    if (sessionId.isNotEmpty) {
      return sessionId;
    }
    return '${service.name.trim().toLowerCase()}|'
        '${service.type.trim().toLowerCase()}|'
        '${service.port}';
  }
}

class _DiscoveredReceiverCandidate {
  const _DiscoveredReceiverCandidate({
    this.sessionId = '',
    this.pairingCode = '',
    this.host = '',
    this.port = 0,
    this.receiverDeviceName = '',
    this.receiverPlatform = '',
    this.protocolVersion = '',
  });

  final String sessionId;
  final String pairingCode;
  final String host;
  final int port;
  final String receiverDeviceName;
  final String receiverPlatform;
  final String protocolVersion;

  _DiscoveredReceiverCandidate merge(BonsoirService service) {
    final attributes = service.attributes;
    final attrHost = _normalizeHost(attributes['host']);
    final resolvedHost = _normalizeHost(service.host);

    return _DiscoveredReceiverCandidate(
      sessionId: _firstNonEmpty(
        attributes['sid']?.trim(),
        sessionId,
      ),
      pairingCode: _firstNonEmpty(
        attributes['code']?.trim(),
        pairingCode,
      ),
      host: _firstNonEmpty(
        attrHost,
        resolvedHost,
        host,
      ),
      port: service.port > 0 ? service.port : port,
      receiverDeviceName: _firstNonEmpty(
        attributes['name']?.trim(),
        service.name.trim(),
        receiverDeviceName,
      ),
      receiverPlatform: _firstNonEmpty(
        attributes['plat']?.trim(),
        receiverPlatform,
      ),
      protocolVersion: _firstNonEmpty(
        attributes['ver']?.trim(),
        protocolVersion,
        memoFlowMigrationProtocolVersion,
      ),
    );
  }

  MemoFlowMigrationSessionDescriptor? toDescriptor() {
    if (sessionId.isEmpty || pairingCode.isEmpty || host.isEmpty || port <= 0) {
      return null;
    }
    return MemoFlowMigrationSessionDescriptor(
      sessionId: sessionId,
      pairingCode: pairingCode,
      host: host,
      port: port,
      receiverDeviceName: receiverDeviceName,
      receiverPlatform: receiverPlatform,
      protocolVersion: protocolVersion.isEmpty
          ? memoFlowMigrationProtocolVersion
          : protocolVersion,
    );
  }

  static String _normalizeHost(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  static String _firstNonEmpty(String? first, [String? second, String? third]) {
    for (final value in <String?>[first, second, third]) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }
}
