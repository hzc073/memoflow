import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-shot trigger to force home initial loading overlay on next home entry.
final homeLoadingOverlayForceProvider = StateProvider<bool>((ref) => false);
