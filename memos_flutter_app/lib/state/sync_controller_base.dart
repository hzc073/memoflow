import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class SyncControllerBase extends StateNotifier<AsyncValue<void>> {
  SyncControllerBase(super.state);

  Future<void> syncNow();
}
