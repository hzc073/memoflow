import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/sync_request.dart';
import '../../data/models/workspace_preferences.dart';
import '../settings/device_preferences_provider.dart';
import '../system/database_provider.dart';
import '../system/local_library_provider.dart';
import '../settings/workspace_preferences_provider.dart';
import '../system/session_provider.dart';
import '../sync/sync_coordinator_provider.dart';

final appSyncAdapterProvider = Provider<AppSyncAdapter>((ref) {
  return AppSyncAdapter(ref);
});

class AppSyncAdapter {
  AppSyncAdapter(this._ref);

  final Ref _ref;

  WorkspacePreferences readWorkspacePreferences() =>
      _ref.read(currentWorkspacePreferencesProvider);

  bool areStartupPreferencesLoaded() =>
      _ref.read(devicePreferencesLoadedProvider) &&
      _ref.read(workspacePreferencesLoadedProvider);

  AppSessionState? readSession() => _ref.read(appSessionProvider).valueOrNull;

  bool hasAuthenticatedAccount() => readSession()?.currentAccount != null;

  bool hasWorkspace() => hasAuthenticatedAccount() || hasLocalLibrary();

  bool hasLocalLibrary() => _ref.read(currentLocalLibraryProvider) != null;

  bool isDatabaseContextReady() {
    try {
      _ref.read(databaseProvider);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool isSyncContextReady() {
    if (!hasWorkspace()) return false;
    return isDatabaseContextReady();
  }

  Future<void> refreshCurrentUser() =>
      _ref.read(appSessionProvider.notifier).refreshCurrentUser();

  Future<void> requestSync(SyncRequest request) =>
      _ref.read(syncCoordinatorProvider.notifier).requestSync(request);
}
