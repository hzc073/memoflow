import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/server_api_profile.dart';

part 'debug_tools_controller.dart';

final debugToolsControllerProvider = Provider<DebugToolsController>((ref) {
  return DebugToolsController();
});