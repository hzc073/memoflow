import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/sync/sync_request.dart';
import '../../core/storage_read.dart';
import '../../core/theme_colors.dart';
import '../../data/logs/log_manager.dart';
import '../../data/models/app_preferences.dart';
import '../../data/models/home_navigation_preferences.dart';
import '../../data/models/memo_toolbar_preferences.dart';
import '../../data/models/workspace_preferences.dart';
import '../../features/home/home_navigation_resolver.dart';
import '../sync/sync_coordinator_provider.dart';
import '../system/session_provider.dart';
import '../system/storage_error_provider.dart';
import 'preferences_migration_service.dart';

final currentWorkspaceKeyProvider = Provider<String?>((ref) {
  final raw = ref.watch(
    appSessionProvider.select((state) => state.valueOrNull?.currentKey),
  );
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
});

final workspacePreferencesRepositoryProvider =
    Provider<WorkspacePreferencesRepository>((ref) {
      return WorkspacePreferencesRepository(
        ref.watch(preferencesMigrationServiceProvider),
        workspaceKey: ref.watch(currentWorkspaceKeyProvider),
      );
    });

final workspacePreferencesLoadedProvider = StateProvider<bool>((ref) => false);

final currentWorkspacePreferencesProvider = StateNotifierProvider<
  WorkspacePreferencesController,
  WorkspacePreferences
>((ref) {
  final loadedState = ref.read(workspacePreferencesLoadedProvider.notifier);
  Future.microtask(() => loadedState.state = false);
  return WorkspacePreferencesController(
    ref,
    ref.watch(workspacePreferencesRepositoryProvider),
    onLoaded: () => loadedState.state = true,
  );
});

class WorkspacePreferencesController extends StateNotifier<WorkspacePreferences> {
  WorkspacePreferencesController(this._ref, this._repo, {void Function()? onLoaded})
    : _onLoaded = onLoaded,
      super(WorkspacePreferences.defaults) {
    unawaited(_loadFromStorage());
  }

  final Ref _ref;
  final WorkspacePreferencesRepository _repo;
  final void Function()? _onLoaded;
  Future<void> _writeChain = Future<void>.value();

  Future<void> reloadFromStorage() async {
    await _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final stateBeforeLoad = state;
    try {
      final result = await _repo.readWithStatus();
      if (!mounted) return;
      if (!identical(state, stateBeforeLoad)) return;
      if (result.isError) {
        final error = StorageLoadError(
          source: 'workspace_preferences',
          error: result.error!,
          stackTrace: result.stackTrace ?? StackTrace.current,
        );
        LogManager.instance.error(
          'Failed to load workspace preferences.',
          error: error.error,
          stackTrace: error.stackTrace,
        );
        _ref.read(workspacePreferencesStorageErrorProvider.notifier).state =
            error;
        return;
      }
      _ref.read(workspacePreferencesStorageErrorProvider.notifier).state = null;
      state = result.data ?? WorkspacePreferences.defaults;
    } catch (error, stackTrace) {
      LogManager.instance.error(
        'Failed to load workspace preferences.',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      if (!identical(state, stateBeforeLoad)) return;
      _ref.read(workspacePreferencesStorageErrorProvider.notifier).state =
          StorageLoadError(
            source: 'workspace_preferences',
            error: error,
            stackTrace: stackTrace,
          );
      return;
    } finally {
      if (mounted) {
        _onLoaded?.call();
      }
    }
  }

  void _setAndPersist(WorkspacePreferences next, {bool triggerSync = true}) {
    final effective = _repo.hasWorkspaceKey ? next : WorkspacePreferences.defaults;
    state = effective;
    _writeChain = _writeChain.then((_) async {
      try {
        await _repo.write(effective);
      } catch (error, stackTrace) {
        LogManager.instance.warn(
          'Failed to persist workspace preferences.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
    if (triggerSync) {
      unawaited(
        _ref
            .read(syncCoordinatorProvider.notifier)
            .requestSync(
              const SyncRequest(
                kind: SyncRequestKind.webDavSync,
                reason: SyncRequestReason.settings,
              ),
            ),
      );
    }
  }

  Future<void> waitForPendingWrites() => _writeChain;

  Future<void> setAll(
    WorkspacePreferences next, {
    bool triggerSync = true,
  }) async => _setAndPersist(next, triggerSync: triggerSync);

  void setCollapseLongContent(bool value) =>
      _setAndPersist(state.copyWith(collapseLongContent: value));
  void setCollapseReferences(bool value) =>
      _setAndPersist(state.copyWith(collapseReferences: value));
  void setShowEngagementInAllMemoDetails(bool value) => _setAndPersist(
    state.copyWith(showEngagementInAllMemoDetails: value),
  );
  void setAutoSyncOnStartAndResume(bool value) =>
      _setAndPersist(state.copyWith(autoSyncOnStartAndResume: value));
  void setDefaultUseLegacyApi(bool value) =>
      _setAndPersist(state.copyWith(defaultUseLegacyApi: value));
  void setShowDrawerExplore(bool value) =>
      _setAndPersist(state.copyWith(showDrawerExplore: value));
  void setShowDrawerDailyReview(bool value) =>
      _setAndPersist(state.copyWith(showDrawerDailyReview: value));
  void setShowDrawerAiSummary(bool value) =>
      _setAndPersist(state.copyWith(showDrawerAiSummary: value));
  void setShowDrawerResources(bool value) =>
      _setAndPersist(state.copyWith(showDrawerResources: value));
  void setShowDrawerArchive(bool value) =>
      _setAndPersist(state.copyWith(showDrawerArchive: value));
  void setHomeQuickActions({
    required HomeQuickAction primary,
    required HomeQuickAction secondary,
    required HomeQuickAction tertiary,
  }) {
    _setAndPersist(
      state.copyWith(
        homeQuickActionPrimary: primary,
        homeQuickActionSecondary: secondary,
        homeQuickActionTertiary: tertiary,
      ),
    );
  }

  void setHomeNavigationMode(HomeNavigationMode mode) {
    final current = state.homeNavigationPreferences;
    final hasAccount = _ref.read(appSessionProvider).valueOrNull?.currentAccount !=
        null;
    _setAndPersist(
      state.copyWith(
        homeNavigationPreferences: sanitizeHomeNavigationPreferences(
          current.copyWith(mode: mode),
          hasAccount: hasAccount,
        ),
      ),
    );
  }

  void setHomeNavigationSlots({
    required HomeRootDestination leftPrimary,
    required HomeRootDestination leftSecondary,
    required HomeRootDestination rightPrimary,
    required HomeRootDestination rightSecondary,
  }) {
    final hasAccount = _ref.read(appSessionProvider).valueOrNull?.currentAccount !=
        null;
    _setAndPersist(
      state.copyWith(
        homeNavigationPreferences: sanitizeHomeNavigationPreferences(
          state.homeNavigationPreferences.copyWith(
            leftPrimary: leftPrimary,
            leftSecondary: leftSecondary,
            rightPrimary: rightPrimary,
            rightSecondary: rightSecondary,
          ),
          hasAccount: hasAccount,
        ),
      ),
    );
  }

  void setHomeNavigationSlot(
    HomeNavigationSlot slot,
    HomeRootDestination destination,
  ) {
    final current = state.homeNavigationPreferences;
    final next = switch (slot) {
      HomeNavigationSlot.leftPrimary => current.copyWith(
        leftPrimary: destination,
      ),
      HomeNavigationSlot.leftSecondary => current.copyWith(
        leftSecondary: destination,
      ),
      HomeNavigationSlot.rightPrimary => current.copyWith(
        rightPrimary: destination,
      ),
      HomeNavigationSlot.rightSecondary => current.copyWith(
        rightSecondary: destination,
      ),
    };
    final hasAccount = _ref.read(appSessionProvider).valueOrNull?.currentAccount !=
        null;
    _setAndPersist(
      state.copyWith(
        homeNavigationPreferences: sanitizeHomeNavigationPreferences(
          next,
          hasAccount: hasAccount,
        ),
      ),
    );
  }

  void setAiSummaryAllowPrivateMemos(bool value) =>
      _setAndPersist(state.copyWith(aiSummaryAllowPrivateMemos: value));
  void setMemoToolbarPreferences(MemoToolbarPreferences value) =>
      _setAndPersist(state.copyWith(memoToolbarPreferences: value));
  void resetMemoToolbarPreferences() => _setAndPersist(
    state.copyWith(memoToolbarPreferences: MemoToolbarPreferences.defaults),
  );
  void setThemeColorOverride(AppThemeColor? value) =>
      _setAndPersist(state.copyWith(themeColorOverride: value));
  void setCustomThemeOverride(CustomThemeSettings? value) =>
      _setAndPersist(state.copyWith(customThemeOverride: value));
  void clearThemeOverrides() {
    _setAndPersist(
      state.copyWith(
        themeColorOverride: null,
        customThemeOverride: null,
      ),
    );
  }
}

class WorkspacePreferencesRepository {
  WorkspacePreferencesRepository(
    this._migrationService, {
    required String? workspaceKey,
  }) : _workspaceKey = workspaceKey?.trim();

  final PreferencesMigrationService _migrationService;
  final String? _workspaceKey;

  bool get hasWorkspaceKey {
    final key = _workspaceKey;
    return key != null && key.trim().isNotEmpty;
  }

  Future<StorageReadResult<WorkspacePreferences>> readWithStatus() =>
      _migrationService.readWorkspaceWithStatus(_workspaceKey);

  Future<WorkspacePreferences> read() =>
      _migrationService.readWorkspace(_workspaceKey);

  Future<void> write(WorkspacePreferences prefs) =>
      _migrationService.writeWorkspace(_workspaceKey, prefs);
}
