import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:memos_flutter_app/data/local_library/local_library_paths.dart';
import 'package:memos_flutter_app/data/models/account.dart';
import 'package:memos_flutter_app/data/models/instance_profile.dart';
import 'package:memos_flutter_app/data/models/local_library.dart';
import 'package:memos_flutter_app/data/repositories/local_library_repository.dart';
import 'package:memos_flutter_app/state/system/local_library_provider.dart';
import 'package:memos_flutter_app/state/system/session_provider.dart';

import '../../test_support.dart';

void main() {
  late TestSupport support;
  late FlutterSecureStorage storage;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    support = await initializeTestSupport();
    storage = const FlutterSecureStorage();
  });

  tearDown(() async {
    await support.dispose();
  });

  test(
    'rebased migrated library is exposed as current local library',
    () async {
      final currentPath = await resolveManagedWorkspacePath(
        'provider_workspace',
      );
      await storage.write(
        key: 'local_library_state_v1',
        value: jsonEncode(
          LocalLibraryState(
            libraries: [
              LocalLibrary(
                key: 'provider_workspace',
                name: 'Provider Workspace',
                storageKind: LocalLibraryStorageKind.managedPrivate,
                rootPath: p.join('/old', 'ios', 'container'),
              ),
            ],
          ).toJson(),
        ),
      );

      final session = _TestSessionController(currentKey: 'provider_workspace');
      final container = ProviderContainer(
        overrides: [
          appSessionProvider.overrideWith((ref) => session),
          localLibraryRepositoryProvider.overrideWith(
            (ref) => LocalLibraryRepository(storage),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(localLibrariesProvider.notifier);
      await controller.reloadFromStorage();

      final current = container.read(currentLocalLibraryProvider);
      expect(current, isNotNull);
      expect(current!.key, 'provider_workspace');
      expect(current.rootPath, currentPath);
    },
  );

  test('stale legacy local current key is cleared after load', () async {
    await storage.write(
      key: 'local_library_state_v1',
      value: jsonEncode(
        LocalLibraryState(
          libraries: [
            LocalLibrary(
              key: 'stale_provider_workspace',
              name: 'Stale Provider Workspace',
              storageKind: LocalLibraryStorageKind.managedPrivate,
              rootPath: p.join('/old', 'ios', 'container'),
            ),
          ],
        ).toJson(),
      ),
    );

    final session = _TestSessionController(
      currentKey: 'stale_provider_workspace',
    );
    final container = ProviderContainer(
      overrides: [
        appSessionProvider.overrideWith((ref) => session),
        localLibraryRepositoryProvider.overrideWith(
          (ref) => LocalLibraryRepository(storage),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(localLibrariesProvider.notifier);
    await controller.reloadFromStorage();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(localLibrariesProvider), isEmpty);
    expect(container.read(appSessionProvider).valueOrNull?.currentKey, isNull);

    final stalePath = await resolveManagedWorkspacePath(
      'stale_provider_workspace',
      create: false,
    );
    expect(await Directory(stalePath).exists(), isFalse);
  });
}

class _TestSessionController extends AppSessionController {
  _TestSessionController({required String? currentKey})
    : super(
        AsyncValue.data(
          AppSessionState(accounts: const [], currentKey: currentKey),
        ),
      );

  @override
  Future<void> setCurrentKey(String? key) async {
    state = AsyncValue.data(
      AppSessionState(accounts: const [], currentKey: key),
    );
  }

  @override
  Future<void> addAccountWithPat({
    required Uri baseUrl,
    required String personalAccessToken,
    bool? useLegacyApiOverride,
    String? serverVersionOverride,
  }) async {}

  @override
  Future<void> addAccountWithPassword({
    required Uri baseUrl,
    required String username,
    required String password,
    required bool useLegacyApi,
    String? serverVersionOverride,
  }) async {}

  @override
  Future<void> removeAccount(String accountKey) async {}

  @override
  Future<void> switchAccount(String accountKey) async {}

  @override
  Future<void> switchWorkspace(String workspaceKey) async {}

  @override
  Future<void> reloadFromStorage() async {}

  @override
  Future<void> refreshCurrentUser({bool ignoreErrors = true}) async {}

  @override
  bool resolveUseLegacyApiForAccount({
    required Account account,
    required bool globalDefault,
  }) => globalDefault;

  @override
  InstanceProfile resolveEffectiveInstanceProfileForAccount({
    required Account account,
  }) => account.instanceProfile;

  @override
  String resolveEffectiveServerVersionForAccount({required Account account}) =>
      account.serverVersionOverride ?? account.instanceProfile.version;

  @override
  Future<void> setCurrentAccountUseLegacyApiOverride(bool value) async {}

  @override
  Future<void> setCurrentAccountServerVersionOverride(String? version) async {}

  @override
  Future<InstanceProfile> detectCurrentAccountInstanceProfile() async {
    return const InstanceProfile.empty();
  }
}
