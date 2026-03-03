part of memos_api;

enum _NotificationApiMode { modern, legacyV1, legacyV2 }

enum _UserStatsApiMode {
  modernGetStats,
  legacyStatsPath,
  legacyMemosStats,
  legacyMemoStats,
}

enum _AttachmentApiMode { attachments, resources, legacy }

enum _ServerApiFlavor { unknown, v0_25Plus, v0_24, v0_23, v0_22, v0_21 }

enum _CurrentUserEndpoint {
  authSessionCurrent,
  authMe,
  authStatusPost,
  authStatusGet,
  authStatusV2,
  userMeV1,
  usersMeV1,
  userMeLegacy,
}

class _ApiCapabilities {
  const _ApiCapabilities({
    required this.allowLegacyMemoEndpoints,
    required this.memoLegacyByDefault,
    required this.preferLegacyAuthChain,
    required this.forceLegacyMemoByPreference,
    required this.defaultAttachmentMode,
    required this.defaultUserStatsMode,
    required this.defaultNotificationMode,
    required this.shortcutsSupportedByDefault,
  });

  final bool allowLegacyMemoEndpoints;
  final bool memoLegacyByDefault;
  final bool preferLegacyAuthChain;
  final bool forceLegacyMemoByPreference;
  final _AttachmentApiMode? defaultAttachmentMode;
  final _UserStatsApiMode? defaultUserStatsMode;
  final _NotificationApiMode? defaultNotificationMode;
  final bool? shortcutsSupportedByDefault;

  static _ApiCapabilities resolve({
    required _ServerApiFlavor flavor,
    required bool useLegacyApi,
  }) {
    final forceLegacyMemoByPreference =
        useLegacyApi && flavor == _ServerApiFlavor.v0_21;
    if (forceLegacyMemoByPreference) {
      return const _ApiCapabilities(
        allowLegacyMemoEndpoints: true,
        memoLegacyByDefault: true,
        preferLegacyAuthChain: true,
        forceLegacyMemoByPreference: true,
        defaultAttachmentMode: _AttachmentApiMode.legacy,
        defaultUserStatsMode: _UserStatsApiMode.legacyMemoStats,
        defaultNotificationMode: _NotificationApiMode.legacyV2,
        shortcutsSupportedByDefault: false,
      );
    }

    final profile = MemosServerApiProfiles.byFlavor(
      _serverFlavorToPublicFlavor(flavor),
    );
    return _ApiCapabilities(
      allowLegacyMemoEndpoints: profile.allowLegacyMemoEndpoints,
      memoLegacyByDefault: profile.memoLegacyByDefault,
      preferLegacyAuthChain: profile.preferLegacyAuthChain,
      forceLegacyMemoByPreference: false,
      defaultAttachmentMode: _attachmentModeFromProfile(
        profile.defaultAttachmentMode,
      ),
      defaultUserStatsMode: _userStatsModeFromProfile(
        profile.defaultUserStatsMode,
      ),
      defaultNotificationMode: _notificationModeFromProfile(
        profile.defaultNotificationMode,
      ),
      shortcutsSupportedByDefault: profile.shortcutsSupportedByDefault,
    );
  }

  static MemosServerFlavor _serverFlavorToPublicFlavor(
    _ServerApiFlavor flavor,
  ) {
    return switch (flavor) {
      _ServerApiFlavor.v0_21 => MemosServerFlavor.v0_21,
      _ServerApiFlavor.v0_22 => MemosServerFlavor.v0_22,
      _ServerApiFlavor.v0_23 => MemosServerFlavor.v0_23,
      _ServerApiFlavor.v0_24 => MemosServerFlavor.v0_24,
      _ServerApiFlavor.v0_25Plus ||
      _ServerApiFlavor.unknown => MemosServerFlavor.v0_25Plus,
    };
  }

  static _AttachmentApiMode _attachmentModeFromProfile(
    MemosAttachmentRouteMode mode,
  ) {
    return switch (mode) {
      MemosAttachmentRouteMode.legacy => _AttachmentApiMode.legacy,
      MemosAttachmentRouteMode.resources => _AttachmentApiMode.resources,
      MemosAttachmentRouteMode.attachments => _AttachmentApiMode.attachments,
    };
  }

  static _UserStatsApiMode _userStatsModeFromProfile(
    MemosUserStatsRouteMode mode,
  ) {
    return switch (mode) {
      MemosUserStatsRouteMode.modernGetStats =>
        _UserStatsApiMode.modernGetStats,
      MemosUserStatsRouteMode.legacyStatsPath =>
        _UserStatsApiMode.legacyStatsPath,
      MemosUserStatsRouteMode.legacyMemosStats =>
        _UserStatsApiMode.legacyMemosStats,
      MemosUserStatsRouteMode.legacyMemoStats =>
        _UserStatsApiMode.legacyMemoStats,
    };
  }

  static _NotificationApiMode _notificationModeFromProfile(
    MemosNotificationRouteMode mode,
  ) {
    return switch (mode) {
      MemosNotificationRouteMode.modern => _NotificationApiMode.modern,
      MemosNotificationRouteMode.legacyV1 => _NotificationApiMode.legacyV1,
      MemosNotificationRouteMode.legacyV2 => _NotificationApiMode.legacyV2,
    };
  }
}

class _ServerVersion implements Comparable<_ServerVersion> {
  const _ServerVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static _ServerVersion? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(r'(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(trimmed);
    if (match == null) return null;
    final major = int.tryParse(match.group(1) ?? '');
    final minor = int.tryParse(match.group(2) ?? '');
    final patch = int.tryParse(match.group(3) ?? '0');
    if (major == null || minor == null || patch == null) return null;
    return _ServerVersion(major, minor, patch);
  }

  @override
  int compareTo(_ServerVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >=(_ServerVersion other) => compareTo(other) >= 0;
}
