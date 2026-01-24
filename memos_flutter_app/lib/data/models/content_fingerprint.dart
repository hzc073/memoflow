const int _fnvOffset64 = 0xcbf29ce484222325;
const int _fnvPrime64 = 0x100000001b3;
const int _fnvMask64 = 0xFFFFFFFFFFFFFFFF;

String computeContentFingerprint(String content) {
  var hash = _fnvOffset64;
  for (final unit in content.codeUnits) {
    hash ^= unit & 0xFF;
    hash = (hash * _fnvPrime64) & _fnvMask64;
    hash ^= (unit >> 8) & 0xFF;
    hash = (hash * _fnvPrime64) & _fnvMask64;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
