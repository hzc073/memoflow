import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/macos_distribution_identity.dart';
import 'package:memos_flutter_app/data/repositories/accounts_repository.dart';

class _MemorySecureStorage extends FlutterSecureStorage {
  _MemorySecureStorage();

  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
      return;
    }
    _values[key] = value;
  }
}

void main() {
  const legacyDefaultService = 'flutter_secure_storage_service';

  test('resolves explicit macOS distribution channels', () {
    expect(
      resolveMacosDistributionChannel('production'),
      MacosDistributionChannel.production,
    );
    expect(
      resolveMacosDistributionChannel('prod'),
      MacosDistributionChannel.production,
    );
    expect(
      resolveMacosDistributionChannel('release'),
      MacosDistributionChannel.production,
    );
    expect(resolveMacosDistributionChannel('qa'), MacosDistributionChannel.qa);
    expect(
      resolveMacosDistributionChannel('test'),
      MacosDistributionChannel.qa,
    );
  });

  test(
    'defaults unset or unknown macOS distribution channel to development',
    () {
      expect(
        resolveMacosDistributionChannel(null),
        MacosDistributionChannel.development,
      );
      expect(
        resolveMacosDistributionChannel(''),
        MacosDistributionChannel.development,
      );
      expect(
        resolveMacosDistributionChannel('unexpected'),
        MacosDistributionChannel.development,
      );
    },
  );

  test('maps channels to isolated bundle ids and keychain services', () {
    expect(
      macosBundleIdForDistributionChannel(MacosDistributionChannel.production),
      'com.memoflow.hzc073',
    );
    expect(
      macosKeychainServiceForDistributionChannel(
        MacosDistributionChannel.production,
      ),
      'com.memoflow.hzc073.secure.production',
    );
    expect(
      macosBundleIdForDistributionChannel(MacosDistributionChannel.development),
      'com.memoflow.hzc073.dev',
    );
    expect(
      macosKeychainServiceForDistributionChannel(
        MacosDistributionChannel.development,
      ),
      'com.memoflow.hzc073.secure.dev',
    );
    expect(
      macosBundleIdForDistributionChannel(MacosDistributionChannel.qa),
      'com.memoflow.hzc073.qa',
    );
    expect(
      macosKeychainServiceForDistributionChannel(MacosDistributionChannel.qa),
      'com.memoflow.hzc073.secure.qa',
    );
  });

  test('production storage options do not use legacy default service', () {
    final options = macosSecureStorageOptionsForDistributionChannel(
      MacosDistributionChannel.production,
    );
    final map = options.toMap();

    expect(map['accountName'], 'com.memoflow.hzc073.secure.production');
    expect(map['accountName'], isNot(legacyDefaultService));
    expect(map['useDataProtectionKeyChain'], 'false');
  });

  test(
    'first release starts with empty accounts when production service is empty',
    () async {
      final repository = AccountsRepository(_MemorySecureStorage());

      final state = await repository.read();

      expect(state.accounts, isEmpty);
      expect(state.currentKey, isNull);
    },
  );
}
