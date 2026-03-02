part of 'onboarding_providers.dart';

class OnboardingController {
  Future<void> deleteStaleLocalLibraryDatabase({
    required String workspaceKey,
  }) async {
    await AppDatabase.deleteDatabaseFile(
      dbName: databaseNameForAccountKey(workspaceKey),
    );
  }
}