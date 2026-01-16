import 'instance_profile.dart';
import 'user.dart';

class Account {
  const Account({
    required this.key,
    required this.baseUrl,
    required this.personalAccessToken,
    required this.user,
    required this.instanceProfile,
  });

  final String key;
  final Uri baseUrl;
  final String personalAccessToken;
  final User user;
  final InstanceProfile instanceProfile;

  Map<String, dynamic> toJson() => {
        'key': key,
        'baseUrl': baseUrl.toString(),
        'personalAccessToken': personalAccessToken,
        'user': user.toJson(),
        'instanceProfile': instanceProfile.toJson(),
      };

  factory Account.fromJson(Map<String, dynamic> json) {
    final baseUrlRaw = (json['baseUrl'] as String?) ?? '';
    final baseUrl = Uri.tryParse(baseUrlRaw) ?? Uri();

    final userJson = json['user'];
    final profileJson = json['instanceProfile'];

    return Account(
      key: (json['key'] as String?) ?? '',
      baseUrl: baseUrl,
      personalAccessToken: (json['personalAccessToken'] as String?) ?? '',
      user: userJson is Map ? User.fromJson(userJson.cast<String, dynamic>()) : const User.empty(),
      instanceProfile:
          profileJson is Map ? InstanceProfile.fromJson(profileJson.cast<String, dynamic>()) : const InstanceProfile.empty(),
    );
  }
}

