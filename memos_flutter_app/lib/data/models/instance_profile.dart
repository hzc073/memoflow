class InstanceProfile {
  const InstanceProfile({
    required this.version,
    required this.mode,
    required this.instanceUrl,
    required this.owner,
  });

  final String version;
  final String mode;
  final String instanceUrl;
  final String owner;

  const InstanceProfile.empty()
      : version = '',
        mode = '',
        instanceUrl = '',
        owner = '';

  factory InstanceProfile.fromJson(Map<String, dynamic> json) {
    return InstanceProfile(
      version: (json['version'] as String?) ?? '',
      mode: (json['mode'] as String?) ?? '',
      instanceUrl: (json['instanceUrl'] as String?) ?? '',
      owner: (json['owner'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'mode': mode,
        'instanceUrl': instanceUrl,
        'owner': owner,
      };
}
