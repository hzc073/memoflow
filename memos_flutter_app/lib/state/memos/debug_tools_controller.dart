part of 'debug_tools_providers.dart';

class DebugToolsController {
  String buildApiRouteVersionLabel({
    required String? manualVersionOverride,
    required String? detectedVersion,
  }) {
    if (manualVersionOverride == null && detectedVersion == null) return '-';
    final resolution = MemosServerApiProfiles.resolve(
      manualVersionOverride: manualVersionOverride,
      detectedVersion: detectedVersion ?? '',
    );
    return _apiRouteVersionLabel(resolution);
  }

  String _apiVersionBandLabel(MemosVersionNumber? version) {
    if (version == null) return '-';
    if (version.major == 0 && version.minor >= 20 && version.minor < 30) {
      return '0.2x';
    }
    return '${version.major}.${version.minor}x';
  }

  String _apiRouteVersionLabel(MemosVersionResolution? resolution) {
    if (resolution == null) return '-';
    final band = _apiVersionBandLabel(resolution.parsedVersion);
    final effective = resolution.effectiveVersion.trim();
    final flavor = resolution.profile.flavor.name;
    if (effective.isEmpty) return '$band | $flavor';
    return '$band | $effective | $flavor';
  }
}