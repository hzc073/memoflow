enum ServerSettingSource {
  legacySystemStatus,
  legacySystemSetting,
  workspaceMemoRelatedSetting,
  workspaceStorageSetting,
  instanceMemoRelatedSetting,
  instanceStorageSetting,
}

enum ServerSettingUnavailableReason {
  localLibrary,
  unsupportedVersion,
  permissionDenied,
  endpointUnavailable,
  requestFailed,
  invalidResponse,
  nonPositiveLimit,
}

class ServerSettingValue<T extends Object> {
  const ServerSettingValue.known({
    required this.value,
    required this.source,
    this.editable = true,
  }) : unavailableReason = null,
       supported = true;

  const ServerSettingValue.unavailable({
    required this.unavailableReason,
    this.source,
    this.supported = true,
  }) : value = null,
       editable = false;

  const ServerSettingValue.unsupported()
    : value = null,
      source = null,
      editable = false,
      supported = false,
      unavailableReason = ServerSettingUnavailableReason.unsupportedVersion;

  final T? value;
  final ServerSettingSource? source;
  final bool editable;
  final bool supported;
  final ServerSettingUnavailableReason? unavailableReason;

  bool get isKnown => value != null;
  bool get isUnavailable => value == null;

  ServerSettingValue<T> asReadOnly() {
    if (!isKnown) return this;
    return ServerSettingValue<T>.known(
      value: value as T,
      source: source!,
      editable: false,
    );
  }
}

class ServerSettingsSnapshot {
  const ServerSettingsSnapshot({
    required this.memoContentLimitBytes,
    required this.attachmentUploadLimitMiB,
  });

  const ServerSettingsSnapshot.localLibrary()
    : memoContentLimitBytes = const ServerSettingValue<int>.unavailable(
        unavailableReason: ServerSettingUnavailableReason.localLibrary,
      ),
      attachmentUploadLimitMiB = const ServerSettingValue<int>.unavailable(
        unavailableReason: ServerSettingUnavailableReason.localLibrary,
      );

  final ServerSettingValue<int> memoContentLimitBytes;
  final ServerSettingValue<int> attachmentUploadLimitMiB;

  ServerSettingsSnapshot copyWith({
    ServerSettingValue<int>? memoContentLimitBytes,
    ServerSettingValue<int>? attachmentUploadLimitMiB,
  }) {
    return ServerSettingsSnapshot(
      memoContentLimitBytes:
          memoContentLimitBytes ?? this.memoContentLimitBytes,
      attachmentUploadLimitMiB:
          attachmentUploadLimitMiB ?? this.attachmentUploadLimitMiB,
    );
  }
}
