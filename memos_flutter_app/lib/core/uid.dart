import 'dart:math';

final _rng = Random.secure();
const _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

String generateUid({int length = 20}) {
  if (length < 1 || length > 32) {
    throw ArgumentError.value(length, 'length', 'Must be between 1 and 32');
  }
  return List.generate(length, (_) => _alphabet[_rng.nextInt(_alphabet.length)]).join();
}

