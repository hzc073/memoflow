class Attachment {
  const Attachment({
    required this.name,
    required this.filename,
    required this.type,
    required this.size,
    required this.externalLink,
  });

  final String name;
  final String filename;
  final String type;
  final int size;
  final String externalLink;

  String get uid {
    if (name.startsWith('attachments/')) return name.substring('attachments/'.length);
    if (name.startsWith('resources/')) return name.substring('resources/'.length);
    return name;
  }

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      name: (json['name'] as String?) ?? '',
      filename: (json['filename'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      size: _toInt(json['size']),
      externalLink: (json['externalLink'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'filename': filename,
      'type': type,
      'size': size,
      'externalLink': externalLink,
    };
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
