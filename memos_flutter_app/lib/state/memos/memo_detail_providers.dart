import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'memo_detail_controller.dart';

final memoDetailControllerProvider = Provider<MemoDetailController>((ref) {
  return MemoDetailController(ref);
});
