enum MemoApiVersion { v021, v022, v023, v024, v025, v026 }

const List<MemoApiVersion> kMemoApiVersionsProbeOrder = <MemoApiVersion>[
  MemoApiVersion.v021,
  MemoApiVersion.v022,
  MemoApiVersion.v023,
  MemoApiVersion.v024,
  MemoApiVersion.v025,
  MemoApiVersion.v026,
];

extension MemoApiVersionX on MemoApiVersion {
  String get versionString {
    return switch (this) {
      MemoApiVersion.v021 => '0.21.0',
      MemoApiVersion.v022 => '0.22.0',
      MemoApiVersion.v023 => '0.23.0',
      MemoApiVersion.v024 => '0.24.0',
      MemoApiVersion.v025 => '0.25.0',
      MemoApiVersion.v026 => '0.26.0',
    };
  }

  bool get defaultUseLegacyApi {
    return this == MemoApiVersion.v021 || this == MemoApiVersion.v022;
  }

  String get label => 'v$versionString';
}

MemoApiVersion? parseMemoApiVersion(String? raw) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(r'^(\d+)\.(\d+)(?:\.(\d+))?$').firstMatch(trimmed);
  if (match == null) return null;
  final major = int.tryParse(match.group(1) ?? '');
  final minor = int.tryParse(match.group(2) ?? '');
  if (major != 0 || minor == null) return null;
  return switch (minor) {
    21 => MemoApiVersion.v021,
    22 => MemoApiVersion.v022,
    23 => MemoApiVersion.v023,
    24 => MemoApiVersion.v024,
    25 => MemoApiVersion.v025,
    26 => MemoApiVersion.v026,
    _ => null,
  };
}

String normalizeMemoApiVersion(String? raw) {
  final parsed = parseMemoApiVersion(raw);
  if (parsed == null) return '';
  return parsed.versionString;
}
