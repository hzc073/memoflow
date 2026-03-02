import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'link_memo_controller.dart';

final linkMemoControllerProvider = Provider<LinkMemoController>((ref) {
  return LinkMemoController(ref);
});
