import 'package:flutter_riverpod/flutter_riverpod.dart';

final loginBaseUrlDraftProvider = StateProvider<String>((ref) {
  return 'http://localhost:5230';
});

