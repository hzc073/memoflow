import 'package:flutter_riverpod/flutter_riverpod.dart';

final webDavSyncTriggerProvider = StateNotifierProvider<WebDavSyncTrigger, int>((ref) {
  return WebDavSyncTrigger();
});

class WebDavSyncTrigger extends StateNotifier<int> {
  WebDavSyncTrigger() : super(0);

  void bump() => state++;
}
