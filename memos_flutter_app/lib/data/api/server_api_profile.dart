enum MemosAttachmentRouteMode { legacy, resources, attachments }

enum MemosUserStatsRouteMode {
  modernGetStats,
  legacyStatsPath,
  legacyMemosStats,
  legacyMemoStats,
}

enum MemosNotificationRouteMode { modern, legacyV1, legacyV2 }

enum MemosMemoStateRouteField { state, rowStatus }

enum MemosServerFlavor { v0_21, v0_22, v0_23, v0_24, v0_25Plus }

enum MemosVersionSource { manualOverride, detectedProfile, fallbackDefault }

class MemosVersionNumber implements Comparable<MemosVersionNumber> {
  const MemosVersionNumber(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(MemosVersionNumber other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >=(MemosVersionNumber other) => compareTo(other) >= 0;

  @override
  String toString() => '$major.$minor.$patch';
}

class MemosServerApiProfile {
  const MemosServerApiProfile({
    required this.flavor,
    required this.defaultUseLegacyApi,
    required this.allowLegacyMemoEndpoints,
    required this.memoLegacyByDefault,
    required this.preferLegacyAuthChain,
    required this.defaultAttachmentMode,
    required this.defaultUserStatsMode,
    required this.defaultNotificationMode,
    required this.shortcutsSupportedByDefault,
    required this.requiresCreatorScopedListMemos,
    required this.supportsMemoParentQuery,
    required this.memoStateField,
  });

  final MemosServerFlavor flavor;
  final bool defaultUseLegacyApi;
  final bool allowLegacyMemoEndpoints;
  final bool memoLegacyByDefault;
  final bool preferLegacyAuthChain;
  final MemosAttachmentRouteMode defaultAttachmentMode;
  final MemosUserStatsRouteMode defaultUserStatsMode;
  final MemosNotificationRouteMode defaultNotificationMode;
  final bool? shortcutsSupportedByDefault;
  final bool requiresCreatorScopedListMemos;
  final bool supportsMemoParentQuery;
  final MemosMemoStateRouteField memoStateField;

  bool get usesLegacySearchFilterDialectByDefault =>
      memoStateField == MemosMemoStateRouteField.rowStatus;
}

class MemosVersionResolution {
  const MemosVersionResolution({
    required this.source,
    required this.effectiveVersion,
    required this.profile,
    required this.parsedVersion,
  });

  final MemosVersionSource source;
  final String effectiveVersion;
  final MemosServerApiProfile profile;
  final MemosVersionNumber? parsedVersion;
}

class MemosServerApiProfiles {
  static const String fallbackVersion = '0.25.0';
  static const MemosServerFlavor fallbackFlavor = MemosServerFlavor.v0_25Plus;

  static const MemosServerApiProfile v0_21 = MemosServerApiProfile(
    flavor: MemosServerFlavor.v0_21,
    defaultUseLegacyApi: true,
    allowLegacyMemoEndpoints: true,
    memoLegacyByDefault: true,
    preferLegacyAuthChain: true,
    defaultAttachmentMode: MemosAttachmentRouteMode.legacy,
    defaultUserStatsMode: MemosUserStatsRouteMode.legacyMemoStats,
    defaultNotificationMode: MemosNotificationRouteMode.legacyV2,
    shortcutsSupportedByDefault: false,
    requiresCreatorScopedListMemos: false,
    supportsMemoParentQuery: false,
    memoStateField: MemosMemoStateRouteField.rowStatus,
  );

  static const MemosServerApiProfile v0_22 = MemosServerApiProfile(
    flavor: MemosServerFlavor.v0_22,
    defaultUseLegacyApi: true,
    allowLegacyMemoEndpoints: true,
    memoLegacyByDefault: false,
    preferLegacyAuthChain: false,
    defaultAttachmentMode: MemosAttachmentRouteMode.resources,
    defaultUserStatsMode: MemosUserStatsRouteMode.legacyMemosStats,
    defaultNotificationMode: MemosNotificationRouteMode.legacyV1,
    shortcutsSupportedByDefault: false,
    requiresCreatorScopedListMemos: false,
    supportsMemoParentQuery: false,
    memoStateField: MemosMemoStateRouteField.rowStatus,
  );

  static const MemosServerApiProfile v0_23 = MemosServerApiProfile(
    flavor: MemosServerFlavor.v0_23,
    defaultUseLegacyApi: false,
    allowLegacyMemoEndpoints: true,
    memoLegacyByDefault: false,
    preferLegacyAuthChain: false,
    defaultAttachmentMode: MemosAttachmentRouteMode.resources,
    // 0.23 removed /api/v1/memos/stats but still supports legacy memo stats.
    defaultUserStatsMode: MemosUserStatsRouteMode.legacyMemoStats,
    defaultNotificationMode: MemosNotificationRouteMode.legacyV1,
    shortcutsSupportedByDefault: false,
    requiresCreatorScopedListMemos: true,
    supportsMemoParentQuery: false,
    memoStateField: MemosMemoStateRouteField.rowStatus,
  );

  static const MemosServerApiProfile v0_24 = MemosServerApiProfile(
    flavor: MemosServerFlavor.v0_24,
    defaultUseLegacyApi: false,
    allowLegacyMemoEndpoints: false,
    memoLegacyByDefault: false,
    preferLegacyAuthChain: false,
    defaultAttachmentMode: MemosAttachmentRouteMode.resources,
    defaultUserStatsMode: MemosUserStatsRouteMode.legacyStatsPath,
    defaultNotificationMode: MemosNotificationRouteMode.legacyV1,
    shortcutsSupportedByDefault: true,
    requiresCreatorScopedListMemos: false,
    supportsMemoParentQuery: true,
    memoStateField: MemosMemoStateRouteField.state,
  );

  static const MemosServerApiProfile v0_25Plus = MemosServerApiProfile(
    flavor: MemosServerFlavor.v0_25Plus,
    defaultUseLegacyApi: false,
    allowLegacyMemoEndpoints: false,
    memoLegacyByDefault: false,
    preferLegacyAuthChain: false,
    defaultAttachmentMode: MemosAttachmentRouteMode.attachments,
    defaultUserStatsMode: MemosUserStatsRouteMode.modernGetStats,
    defaultNotificationMode: MemosNotificationRouteMode.modern,
    shortcutsSupportedByDefault: true,
    requiresCreatorScopedListMemos: false,
    supportsMemoParentQuery: true,
    memoStateField: MemosMemoStateRouteField.state,
  );

  static MemosServerApiProfile get fallbackProfile => byFlavor(fallbackFlavor);

  static MemosServerApiProfile byFlavor(MemosServerFlavor flavor) {
    return switch (flavor) {
      MemosServerFlavor.v0_21 => v0_21,
      MemosServerFlavor.v0_22 => v0_22,
      MemosServerFlavor.v0_23 => v0_23,
      MemosServerFlavor.v0_24 => v0_24,
      MemosServerFlavor.v0_25Plus => v0_25Plus,
    };
  }

  static MemosServerApiProfile byVersionString(
    String? rawVersion, {
    MemosServerFlavor fallback = fallbackFlavor,
  }) {
    final parsed = tryParseVersion(rawVersion);
    final flavor = inferFlavor(parsed, fallback: fallback);
    return byFlavor(flavor);
  }

  static MemosVersionNumber? tryParseVersion(String? rawVersion) {
    final trimmed = (rawVersion ?? '').trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(r'(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(trimmed);
    if (match == null) return null;

    final major = int.tryParse(match.group(1) ?? '');
    final minor = int.tryParse(match.group(2) ?? '');
    final patch = int.tryParse(match.group(3) ?? '0');
    if (major == null || minor == null || patch == null) {
      return null;
    }
    return MemosVersionNumber(major, minor, patch);
  }

  static MemosServerFlavor inferFlavor(
    MemosVersionNumber? version, {
    MemosServerFlavor fallback = fallbackFlavor,
  }) {
    if (version == null) return fallback;
    if (version.major != 0) return MemosServerFlavor.v0_25Plus;
    if (version.minor >= 25) return MemosServerFlavor.v0_25Plus;
    if (version.minor >= 24) return MemosServerFlavor.v0_24;
    if (version.minor >= 23) return MemosServerFlavor.v0_23;
    if (version.minor >= 22) return MemosServerFlavor.v0_22;
    return MemosServerFlavor.v0_21;
  }

  static MemosVersionResolution resolve({
    String? manualVersionOverride,
    String? detectedVersion,
    MemosServerFlavor fallback = fallbackFlavor,
  }) {
    final manual = (manualVersionOverride ?? '').trim();
    if (manual.isNotEmpty) {
      final parsed = tryParseVersion(manual);
      final flavor = inferFlavor(parsed, fallback: fallback);
      final normalized = parsed?.toString() ?? manual;
      return MemosVersionResolution(
        source: MemosVersionSource.manualOverride,
        effectiveVersion: normalized,
        profile: byFlavor(flavor),
        parsedVersion: parsed,
      );
    }

    final detected = (detectedVersion ?? '').trim();
    if (detected.isNotEmpty) {
      final parsed = tryParseVersion(detected);
      final flavor = inferFlavor(parsed, fallback: fallback);
      final normalized = parsed?.toString() ?? detected;
      return MemosVersionResolution(
        source: MemosVersionSource.detectedProfile,
        effectiveVersion: normalized,
        profile: byFlavor(flavor),
        parsedVersion: parsed,
      );
    }

    return MemosVersionResolution(
      source: MemosVersionSource.fallbackDefault,
      effectiveVersion: fallbackVersion,
      profile: byFlavor(fallback),
      parsedVersion: tryParseVersion(fallbackVersion),
    );
  }

  static bool defaultUseLegacyApi(
    String? rawVersion, {
    MemosServerFlavor fallback = fallbackFlavor,
  }) {
    return byVersionString(rawVersion, fallback: fallback).defaultUseLegacyApi;
  }

  static String? normalizeVersionOverride(String? version) {
    final trimmed = (version ?? '').trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(r'^(\d+)\.(\d+)(?:\.(\d+))?$').firstMatch(trimmed);
    if (match == null) {
      throw const FormatException('Version must be like 0.22 or 0.22.0');
    }
    final major = int.tryParse(match.group(1) ?? '');
    final minor = int.tryParse(match.group(2) ?? '');
    final patch = int.tryParse(match.group(3) ?? '0');
    if (major == null || minor == null || patch == null) {
      throw const FormatException('Invalid version');
    }
    return '$major.$minor.$patch';
  }
}
