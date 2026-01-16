import 'dart:convert';

/// Stable, fast hash for identifiers that end up in filenames.
String fnv1a64Hex(String input) {
  const int fnvPrime = 0x100000001b3;
  const int offsetBasis = 0xcbf29ce484222325;

  var hash = offsetBasis;
  for (final b in utf8.encode(input)) {
    hash ^= b;
    hash = (hash * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

