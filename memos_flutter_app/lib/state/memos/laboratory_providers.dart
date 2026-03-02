import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/sync_request.dart';
import '../../data/api/memo_api_facade.dart';
import '../../data/api/memo_api_probe.dart';
import '../../data/api/memo_api_version.dart';
import '../../data/models/account.dart';
import '../sync_coordinator_provider.dart';

part 'laboratory_controller.dart';

final laboratoryControllerProvider = Provider<LaboratoryController>((ref) {
  return LaboratoryController(ref);
});