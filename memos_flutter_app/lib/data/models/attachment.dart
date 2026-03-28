enum AttachmentCategory { image, audio, document, other }

class Attachment {
  const Attachment({
    required this.name,
    required this.filename,
    required this.type,
    required this.size,
    required this.externalLink,
    this.width,
    this.height,
    this.hash,
  });

  final String name;
  final String filename;
  final String type;
  final int size;
  final String externalLink;
  final int? width;
  final int? height;
  final String? hash;

  String get uid {
    if (name.startsWith('attachments/')) {
      return name.substring('attachments/'.length);
    }
    if (name.startsWith('resources/')) {
      return name.substring('resources/'.length);
    }
    return name;
  }

  factory Attachment.fromJson(Map<String, dynamic> json) {
    int? readOptionalInt(String key) {
      final raw = _toInt(json[key]);
      return raw > 0 ? raw : null;
    }

    String? readOptionalString(String key) {
      final raw = json[key];
      if (raw is String) {
        final trimmed = raw.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return null;
    }

    return Attachment(
      name: (json['name'] as String?) ?? '',
      filename: (json['filename'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      size: _toInt(json['size']),
      externalLink: (json['externalLink'] as String?) ?? '',
      width: readOptionalInt('width'),
      height: readOptionalInt('height'),
      hash: readOptionalString('hash'),
    );
  }

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'name': name,
      'filename': filename,
      'type': type,
      'size': size,
      'externalLink': externalLink,
    };
    if (width != null) payload['width'] = width;
    if (height != null) payload['height'] = height;
    if (hash != null) payload['hash'] = hash;
    return payload;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

extension AttachmentTypeClassification on Attachment {
  String get displayName {
    final trimmedFilename = filename.trim();
    if (trimmedFilename.isNotEmpty) return trimmedFilename;

    final trimmedUid = uid.trim();
    if (trimmedUid.isNotEmpty) return trimmedUid;
    return name.trim();
  }

  AttachmentCategory get searchCategory {
    if (isImage) return AttachmentCategory.image;
    if (isAudio) return AttachmentCategory.audio;
    if (isDocument) return AttachmentCategory.document;
    return AttachmentCategory.other;
  }

  bool get isImage {
    if (_normalizedType.startsWith('image/')) return true;
    return _matchesExtension(const <String>[
      '.avif',
      '.bmp',
      '.gif',
      '.heic',
      '.jpeg',
      '.jpg',
      '.png',
      '.svg',
      '.webp',
    ]);
  }

  bool get isAudio {
    if (_normalizedType.startsWith('audio/')) return true;
    if (_normalizedType == 'audio') return true;
    return _matchesExtension(const <String>[
      '.aac',
      '.amr',
      '.flac',
      '.m4a',
      '.mp3',
      '.ogg',
      '.opus',
      '.wav',
      '.wma',
    ]);
  }

  bool get isDocument {
    const documentMimeTypes = <String>{
      'application/pdf',
      'pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'application/rtf',
      'text/rtf',
      'text/plain',
      'text/markdown',
      'text/csv',
      'text/tab-separated-values',
      'application/csv',
      'application/xml',
      'text/xml',
      'application/vnd.oasis.opendocument.text',
      'application/vnd.oasis.opendocument.spreadsheet',
      'application/vnd.oasis.opendocument.presentation',
      'application/ofd',
      'application/vnd.ofd',
      'application/x-ofd',
    };
    if (documentMimeTypes.contains(_normalizedType)) return true;
    return _matchesExtension(const <String>[
      '.pdf',
      '.doc',
      '.docx',
      '.xls',
      '.xlsx',
      '.ppt',
      '.pptx',
      '.rtf',
      '.txt',
      '.md',
      '.markdown',
      '.csv',
      '.tsv',
      '.odt',
      '.ods',
      '.odp',
      '.pages',
      '.numbers',
      '.key',
      '.xml',
      '.ofd',
    ]);
  }

  bool get isVideo {
    if (_normalizedType.startsWith('video/')) return true;
    if (_normalizedType == 'video') return true;
    return _matchesExtension(const <String>[
      '.3gp',
      '.avi',
      '.m4v',
      '.mkv',
      '.mov',
      '.mp4',
      '.mpeg',
      '.mpg',
      '.webm',
    ]);
  }

  String get _normalizedType => type.trim().toLowerCase();

  String get _normalizedFilename => filename.trim().toLowerCase();

  bool _matchesExtension(List<String> extensions) {
    if (_normalizedFilename.isEmpty) return false;
    for (final ext in extensions) {
      if (_normalizedFilename.endsWith(ext)) return true;
    }
    return false;
  }
}
