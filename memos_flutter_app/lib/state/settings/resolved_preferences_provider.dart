import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/resolved_app_settings.dart';
import '../system/local_library_provider.dart';
import '../system/session_provider.dart';
import 'device_preferences_provider.dart';
import 'preferences_migration_service.dart';
import 'workspace_preferences_provider.dart';

final resolvedAppSettingsProvider = Provider<ResolvedAppSettings>((ref) {
  final device = ref.watch(devicePreferencesProvider);
  final workspace = ref.watch(currentWorkspacePreferencesProvider);
  final session = ref.watch(appSessionProvider).valueOrNull;
  final currentLocalLibrary = ref.watch(currentLocalLibraryProvider);
  final trimmedWorkspaceKey = session?.currentKey?.trim();
  final workspaceKey =
      trimmedWorkspaceKey == null || trimmedWorkspaceKey.isEmpty
      ? currentLocalLibrary?.key
      : trimmedWorkspaceKey;
  final hasWorkspace =
      session?.currentAccount != null || currentLocalLibrary != null;
  return ResolvedAppSettings(
    device: device,
    workspace: workspace,
    workspaceKey: workspaceKey,
    hasWorkspace: hasWorkspace,
  );
});

final preferencesMigrationBootstrapProvider = Provider<void>((ref) {
  final service = ref.watch(preferencesMigrationServiceProvider);
  final session = ref.watch(appSessionProvider).valueOrNull;
  final localLibraries = ref.watch(localLibrariesProvider);
  final workspaceKeys = <String?>[
    session?.currentKey,
    ...?session?.accounts.map((account) => account.key),
    ...localLibraries.map((library) => library.key),
  ];
  Future.microtask(() => service.migrateKnownWorkspaces(workspaceKeys));
});
