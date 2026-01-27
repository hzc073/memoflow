import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/updates/update_config_service.dart';

final updateConfigServiceProvider = Provider<UpdateConfigService>((ref) {
  return UpdateConfigService();
});
