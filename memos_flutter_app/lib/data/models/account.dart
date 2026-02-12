import 'instance_profile.dart';
import 'user.dart';

class Account {
  const Account({
    required this.key,
    required this.baseUrl,
    required this.personalAccessToken,
    required this.user,
    required this.instanceProfile,
    this.useLegacyApiOverride,
    this.serverVersionOverride,
  });

  final String key;
  final Uri baseUrl;
  final String personalAccessToken;
  final User user;
  final InstanceProfile instanceProfile;
  final bool? useLegacyApiOverride;
  final String? serverVersionOverride;

  Map<String, dynamic> toJson() => {
    'key': key,
    'baseUrl': baseUrl.toString(),
    'personalAccessToken': personalAccessToken,
    'user': user.toJson(),
    'instanceProfile': instanceProfile.toJson(),
    'useLegacyApiOverride': useLegacyApiOverride,
    'serverVersionOverride': serverVersionOverride,
  };

  factory Account.fromJson(Map<String, dynamic> json) {
    final baseUrlRaw = (json['baseUrl'] as String?) ?? '';
    final baseUrl = Uri.tryParse(baseUrlRaw) ?? Uri();

    final userJson = json['user'];
    final profileJson = json['instanceProfile'];
    final useLegacyApiOverrideRaw = json['useLegacyApiOverride'];
    final serverVersionOverrideRaw = json['serverVersionOverride'];

    bool? useLegacyApiOverride;
    if (useLegacyApiOverrideRaw is bool) {
      useLegacyApiOverride = useLegacyApiOverrideRaw;
    } else if (useLegacyApiOverrideRaw is String) {
      final normalized = useLegacyApiOverrideRaw.trim().toLowerCase();
      if (normalized == 'true') {
        useLegacyApiOverride = true;
      } else if (normalized == 'false') {
        useLegacyApiOverride = false;
      }
    }

    String? serverVersionOverride;
    if (serverVersionOverrideRaw is String) {
      final normalized = serverVersionOverrideRaw.trim();
      if (normalized.isNotEmpty) {
        serverVersionOverride = normalized;
      }
    }

    return Account(
      key: (json['key'] as String?) ?? '',
      baseUrl: baseUrl,
      personalAccessToken: (json['personalAccessToken'] as String?) ?? '',
      user: userJson is Map
          ? User.fromJson(userJson.cast<String, dynamic>())
          : const User.empty(),
      instanceProfile: profileJson is Map
          ? InstanceProfile.fromJson(profileJson.cast<String, dynamic>())
          : const InstanceProfile.empty(),
      useLegacyApiOverride: useLegacyApiOverride,
      serverVersionOverride: serverVersionOverride,
    );
  }
}
