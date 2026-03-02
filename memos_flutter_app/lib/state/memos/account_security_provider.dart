import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../database_provider.dart';

part 'account_security_controller.dart';

final accountSecurityControllerProvider = Provider<AccountSecurityController>((ref) {
  return AccountSecurityController();
});