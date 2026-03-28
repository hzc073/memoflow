import 'dart:convert';
import 'dart:io';

enum MemoFlowMigrationRole { sender, receiver }

enum MemoFlowMigrationReceiveMode { newWorkspace, overwriteCurrent }

enum MemoFlowMigrationTransferStage {
  idle,
  waitingProposal,
  awaitingAccept,
  awaitingUpload,
  receiving,
  validating,
  importingFiles,
  scanning,
  applyingConfig,
  completed,
  failed,
  cancelled,
}

enum MemoFlowMigrationConfigType {
  preferences,
  reminderSettings,
  templateSettings,
  locationSettings,
  imageCompressionSettings,
  aiSettings,
  imageBedSettings,
  appLock,
  webdavSettings,
}

extension MemoFlowMigrationConfigTypeX on MemoFlowMigrationConfigType {
  bool get isSensitive {
    return switch (this) {
      MemoFlowMigrationConfigType.aiSettings ||
      MemoFlowMigrationConfigType.imageBedSettings ||
      MemoFlowMigrationConfigType.appLock ||
      MemoFlowMigrationConfigType.webdavSettings => true,
      _ => false,
    };
  }

  static MemoFlowMigrationConfigType? tryParse(String raw) {
    final trimmed = raw.trim();
    for (final type in MemoFlowMigrationConfigType.values) {
      if (type.name == trimmed) return type;
    }
    return null;
  }
}

const memoFlowMigrationSafeConfigDefaults = <MemoFlowMigrationConfigType>{
  MemoFlowMigrationConfigType.preferences,
  MemoFlowMigrationConfigType.reminderSettings,
  MemoFlowMigrationConfigType.templateSettings,
  MemoFlowMigrationConfigType.locationSettings,
  MemoFlowMigrationConfigType.imageCompressionSettings,
};

const memoFlowMigrationSensitiveConfigDefaults = <MemoFlowMigrationConfigType>{
  MemoFlowMigrationConfigType.aiSettings,
  MemoFlowMigrationConfigType.imageBedSettings,
  MemoFlowMigrationConfigType.appLock,
  MemoFlowMigrationConfigType.webdavSettings,
};

class MemoFlowMigrationSessionDescriptor {
  const MemoFlowMigrationSessionDescriptor({
    required this.sessionId,
    required this.pairingCode,
    required this.host,
    required this.port,
    required this.receiverDeviceName,
    required this.receiverPlatform,
    required this.protocolVersion,
  });

  final String sessionId;
  final String pairingCode;
  final String host;
  final int port;
  final String receiverDeviceName;
  final String receiverPlatform;
  final String protocolVersion;

  String get address => '$host:$port';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sessionId': sessionId,
    'pairingCode': pairingCode,
    'host': host,
    'port': port,
    'receiverDeviceName': receiverDeviceName,
    'receiverPlatform': receiverPlatform,
    'protocolVersion': protocolVersion,
  };

  factory MemoFlowMigrationSessionDescriptor.fromJson(
    Map<String, dynamic> json,
  ) {
    return MemoFlowMigrationSessionDescriptor(
      sessionId: _readString(json, 'sessionId'),
      pairingCode: _readString(json, 'pairingCode'),
      host: _readString(json, 'host'),
      port: _readInt(json, 'port', fallback: 0),
      receiverDeviceName: _readString(json, 'receiverDeviceName'),
      receiverPlatform: _readString(json, 'receiverPlatform'),
      protocolVersion: _readString(json, 'protocolVersion'),
    );
  }
}

class MemoFlowMigrationPackageManifest {
  const MemoFlowMigrationPackageManifest({
    required this.schemaVersion,
    required this.protocolVersion,
    required this.exportedAt,
    required this.senderDeviceName,
    required this.senderPlatform,
    required this.sourceWorkspaceName,
    required this.includeMemos,
    required this.includeSettings,
    required this.memoCount,
    required this.attachmentCount,
    required this.totalBytes,
    required this.sha256,
    required this.configTypes,
  });

  final int schemaVersion;
  final String protocolVersion;
  final DateTime exportedAt;
  final String senderDeviceName;
  final String senderPlatform;
  final String sourceWorkspaceName;
  final bool includeMemos;
  final bool includeSettings;
  final int memoCount;
  final int attachmentCount;
  final int totalBytes;
  final String sha256;
  final Set<MemoFlowMigrationConfigType> configTypes;

  bool get hasSensitiveConfig => configTypes.any((type) => type.isSensitive);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'protocolVersion': protocolVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'senderDeviceName': senderDeviceName,
    'senderPlatform': senderPlatform,
    'sourceWorkspaceName': sourceWorkspaceName,
    'includeMemos': includeMemos,
    'includeSettings': includeSettings,
    'memoCount': memoCount,
    'attachmentCount': attachmentCount,
    'totalBytes': totalBytes,
    'sha256': sha256,
    'configTypes': configTypes.map((type) => type.name).toList(growable: false),
  };

  MemoFlowMigrationPackageManifest copyWith({
    int? schemaVersion,
    String? protocolVersion,
    DateTime? exportedAt,
    String? senderDeviceName,
    String? senderPlatform,
    String? sourceWorkspaceName,
    bool? includeMemos,
    bool? includeSettings,
    int? memoCount,
    int? attachmentCount,
    int? totalBytes,
    String? sha256,
    Set<MemoFlowMigrationConfigType>? configTypes,
  }) {
    return MemoFlowMigrationPackageManifest(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      exportedAt: exportedAt ?? this.exportedAt,
      senderDeviceName: senderDeviceName ?? this.senderDeviceName,
      senderPlatform: senderPlatform ?? this.senderPlatform,
      sourceWorkspaceName: sourceWorkspaceName ?? this.sourceWorkspaceName,
      includeMemos: includeMemos ?? this.includeMemos,
      includeSettings: includeSettings ?? this.includeSettings,
      memoCount: memoCount ?? this.memoCount,
      attachmentCount: attachmentCount ?? this.attachmentCount,
      totalBytes: totalBytes ?? this.totalBytes,
      sha256: sha256 ?? this.sha256,
      configTypes: configTypes ?? this.configTypes,
    );
  }

  factory MemoFlowMigrationPackageManifest.fromJson(Map<String, dynamic> json) {
    final rawTypes = json['configTypes'];
    final configTypes = <MemoFlowMigrationConfigType>{};
    if (rawTypes is List) {
      for (final item in rawTypes) {
        if (item is String) {
          final parsed = MemoFlowMigrationConfigTypeX.tryParse(item);
          if (parsed != null) configTypes.add(parsed);
        }
      }
    }
    return MemoFlowMigrationPackageManifest(
      schemaVersion: _readInt(json, 'schemaVersion', fallback: 1),
      protocolVersion: _readString(json, 'protocolVersion'),
      exportedAt: _readDateTime(json, 'exportedAt') ?? DateTime.now().toUtc(),
      senderDeviceName: _readString(json, 'senderDeviceName'),
      senderPlatform: _readString(json, 'senderPlatform'),
      sourceWorkspaceName: _readString(json, 'sourceWorkspaceName'),
      includeMemos: _readBool(json, 'includeMemos'),
      includeSettings: _readBool(json, 'includeSettings'),
      memoCount: _readInt(json, 'memoCount', fallback: 0),
      attachmentCount: _readInt(json, 'attachmentCount', fallback: 0),
      totalBytes: _readInt(json, 'totalBytes', fallback: 0),
      sha256: _readString(json, 'sha256'),
      configTypes: configTypes,
    );
  }
}

class MemoFlowMigrationProposal {
  const MemoFlowMigrationProposal({
    required this.proposalId,
    required this.sessionId,
    required this.pairingCode,
    required this.senderDeviceName,
    required this.senderPlatform,
    required this.manifest,
  });

  final String proposalId;
  final String sessionId;
  final String pairingCode;
  final String senderDeviceName;
  final String senderPlatform;
  final MemoFlowMigrationPackageManifest manifest;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'proposalId': proposalId,
    'sessionId': sessionId,
    'pairingCode': pairingCode,
    'senderDeviceName': senderDeviceName,
    'senderPlatform': senderPlatform,
    'manifest': manifest.toJson(),
  };

  factory MemoFlowMigrationProposal.fromJson(Map<String, dynamic> json) {
    final manifestRaw = json['manifest'];
    return MemoFlowMigrationProposal(
      proposalId: _readString(json, 'proposalId'),
      sessionId: _readString(json, 'sessionId'),
      pairingCode: _readString(json, 'pairingCode'),
      senderDeviceName: _readString(json, 'senderDeviceName'),
      senderPlatform: _readString(json, 'senderPlatform'),
      manifest: manifestRaw is Map<String, dynamic>
          ? MemoFlowMigrationPackageManifest.fromJson(manifestRaw)
          : manifestRaw is Map
          ? MemoFlowMigrationPackageManifest.fromJson(
              manifestRaw.cast<String, dynamic>(),
            )
          : MemoFlowMigrationPackageManifest(
              schemaVersion: 1,
              protocolVersion: 'migration-v1',
              exportedAt: DateTime.now().toUtc(),
              senderDeviceName: '',
              senderPlatform: '',
              sourceWorkspaceName: '',
              includeMemos: false,
              includeSettings: false,
              memoCount: 0,
              attachmentCount: 0,
              totalBytes: 0,
              sha256: '',
              configTypes: const <MemoFlowMigrationConfigType>{},
            ),
    );
  }
}

class MemoFlowMigrationAcceptance {
  const MemoFlowMigrationAcceptance({
    required this.proposalId,
    required this.receiveMode,
    required this.acceptedSensitiveConfigTypes,
    required this.uploadToken,
  });

  final String proposalId;
  final MemoFlowMigrationReceiveMode receiveMode;
  final Set<MemoFlowMigrationConfigType> acceptedSensitiveConfigTypes;
  final String uploadToken;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'proposalId': proposalId,
    'receiveMode': receiveMode.name,
    'acceptedSensitiveConfigTypes': acceptedSensitiveConfigTypes
        .map((type) => type.name)
        .toList(growable: false),
    'uploadToken': uploadToken,
  };
}

class MemoFlowMigrationResult {
  const MemoFlowMigrationResult({
    required this.sourceDeviceName,
    required this.receiveMode,
    required this.memoCount,
    required this.attachmentCount,
    required this.appliedConfigTypes,
    required this.skippedConfigTypes,
    this.workspaceName,
    this.workspaceKey,
  });

  final String sourceDeviceName;
  final MemoFlowMigrationReceiveMode receiveMode;
  final int memoCount;
  final int attachmentCount;
  final Set<MemoFlowMigrationConfigType> appliedConfigTypes;
  final Set<MemoFlowMigrationConfigType> skippedConfigTypes;
  final String? workspaceName;
  final String? workspaceKey;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceDeviceName': sourceDeviceName,
    'receiveMode': receiveMode.name,
    'memoCount': memoCount,
    'attachmentCount': attachmentCount,
    'appliedConfigTypes': appliedConfigTypes
        .map((type) => type.name)
        .toList(growable: false),
    'skippedConfigTypes': skippedConfigTypes
        .map((type) => type.name)
        .toList(growable: false),
    'workspaceName': workspaceName,
    'workspaceKey': workspaceKey,
  };

  factory MemoFlowMigrationResult.fromJson(Map<String, dynamic> json) {
    Set<MemoFlowMigrationConfigType> readTypes(String key) {
      final raw = json[key];
      final result = <MemoFlowMigrationConfigType>{};
      if (raw is! List) return result;
      for (final item in raw) {
        if (item is String) {
          final parsed = MemoFlowMigrationConfigTypeX.tryParse(item);
          if (parsed != null) result.add(parsed);
        }
      }
      return result;
    }

    final receiveMode = MemoFlowMigrationReceiveMode.values.firstWhere(
      (value) => value.name == _readString(json, 'receiveMode'),
      orElse: () => MemoFlowMigrationReceiveMode.newWorkspace,
    );
    return MemoFlowMigrationResult(
      sourceDeviceName: _readString(json, 'sourceDeviceName'),
      receiveMode: receiveMode,
      memoCount: _readInt(json, 'memoCount', fallback: 0),
      attachmentCount: _readInt(json, 'attachmentCount', fallback: 0),
      appliedConfigTypes: readTypes('appliedConfigTypes'),
      skippedConfigTypes: readTypes('skippedConfigTypes'),
      workspaceName: _readNullableString(json, 'workspaceName'),
      workspaceKey: _readNullableString(json, 'workspaceKey'),
    );
  }
}

class MemoFlowMigrationUploadResponse {
  const MemoFlowMigrationUploadResponse({
    required this.receivedBytes,
    this.result,
  });

  final int receivedBytes;
  final MemoFlowMigrationResult? result;

  factory MemoFlowMigrationUploadResponse.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    return MemoFlowMigrationUploadResponse(
      receivedBytes: _readInt(json, 'receivedBytes', fallback: 0),
      result: rawResult is Map<String, dynamic>
          ? MemoFlowMigrationResult.fromJson(rawResult)
          : rawResult is Map
          ? MemoFlowMigrationResult.fromJson(rawResult.cast<String, dynamic>())
          : null,
    );
  }
}

class MemoFlowMigrationStatusSnapshot {
  const MemoFlowMigrationStatusSnapshot({
    required this.sessionId,
    required this.proposalId,
    required this.stage,
    this.message,
    this.uploadToken,
    this.receivedBytes,
    this.error,
    this.result,
  });

  final String sessionId;
  final String proposalId;
  final MemoFlowMigrationTransferStage stage;
  final String? message;
  final String? uploadToken;
  final int? receivedBytes;
  final String? error;
  final MemoFlowMigrationResult? result;

  bool get isTerminal {
    return switch (stage) {
      MemoFlowMigrationTransferStage.completed ||
      MemoFlowMigrationTransferStage.failed ||
      MemoFlowMigrationTransferStage.cancelled => true,
      _ => false,
    };
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sessionId': sessionId,
    'proposalId': proposalId,
    'stage': stage.name,
    'message': message,
    'uploadToken': uploadToken,
    'receivedBytes': receivedBytes,
    'error': error,
    if (result != null) 'result': result!.toJson(),
  };

  factory MemoFlowMigrationStatusSnapshot.fromJson(Map<String, dynamic> json) {
    final stage = MemoFlowMigrationTransferStage.values.firstWhere(
      (value) => value.name == _readString(json, 'stage'),
      orElse: () => MemoFlowMigrationTransferStage.idle,
    );
    final rawResult = json['result'];
    return MemoFlowMigrationStatusSnapshot(
      sessionId: _readString(json, 'sessionId'),
      proposalId: _readString(json, 'proposalId'),
      stage: stage,
      message: _readNullableString(json, 'message'),
      uploadToken: _readNullableString(json, 'uploadToken'),
      receivedBytes: json['receivedBytes'] is num
          ? (json['receivedBytes'] as num).toInt()
          : null,
      error: _readNullableString(json, 'error'),
      result: rawResult is Map<String, dynamic>
          ? MemoFlowMigrationResult.fromJson(rawResult)
          : rawResult is Map
          ? MemoFlowMigrationResult.fromJson(rawResult.cast<String, dynamic>())
          : null,
    );
  }
}

class MemoFlowMigrationPackageBuildResult {
  const MemoFlowMigrationPackageBuildResult({
    required this.packageFile,
    required this.manifest,
  });

  final File packageFile;
  final MemoFlowMigrationPackageManifest manifest;
}

String encodeJsonObject(Map<String, dynamic> value) {
  return const JsonEncoder.withIndent('  ').convert(value);
}

String _readString(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is String) return raw.trim();
  return '';
}

String? _readNullableString(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is String) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

int _readInt(Map<String, dynamic> json, String key, {required int fallback}) {
  final raw = json[key];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
  return fallback;
}

bool _readBool(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) return raw.trim().toLowerCase() == 'true';
  return false;
}

DateTime? _readDateTime(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is String) return DateTime.tryParse(raw)?.toUtc();
  return null;
}
