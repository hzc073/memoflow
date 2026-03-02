part of 'account_security_provider.dart';

class AccountSecurityController {
  Future<void> deleteDatabaseForWorkspaceKey(String workspaceKey) async {
    await AppDatabase.deleteDatabaseFile(
      dbName: databaseNameForAccountKey(workspaceKey),
    );
  }
}