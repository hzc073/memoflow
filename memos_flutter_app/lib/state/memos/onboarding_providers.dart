import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../database_provider.dart';

part 'onboarding_controller.dart';

final onboardingControllerProvider = Provider<OnboardingController>((ref) {
  return OnboardingController();
});