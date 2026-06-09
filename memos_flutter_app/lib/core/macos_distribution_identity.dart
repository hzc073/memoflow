import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum MacosDistributionChannel { production, development, qa }

const String macosDistributionChannelDefineName =
    'MEMOFLOW_MACOS_DISTRIBUTION_CHANNEL';

const String macosProductionBundleId = 'com.memoflow.hzc073';
const String macosDevelopmentBundleId = 'com.memoflow.hzc073.dev';
const String macosQaBundleId = 'com.memoflow.hzc073.qa';

const String macosProductionKeychainService =
    'com.memoflow.hzc073.secure.production';
const String macosDevelopmentKeychainService = 'com.memoflow.hzc073.secure.dev';
const String macosQaKeychainService = 'com.memoflow.hzc073.secure.qa';

const String _kMacosDistributionChannelDefine = String.fromEnvironment(
  macosDistributionChannelDefineName,
  defaultValue: '',
);

MacosDistributionChannel get currentMacosDistributionChannel =>
    resolveMacosDistributionChannel(_kMacosDistributionChannelDefine);

MacosDistributionChannel resolveMacosDistributionChannel(String? rawValue) {
  final normalized = rawValue?.trim().toLowerCase();
  return switch (normalized) {
    'production' || 'prod' || 'release' => MacosDistributionChannel.production,
    'qa' || 'test' || 'testing' => MacosDistributionChannel.qa,
    _ => MacosDistributionChannel.development,
  };
}

String macosBundleIdForDistributionChannel(MacosDistributionChannel channel) {
  return switch (channel) {
    MacosDistributionChannel.production => macosProductionBundleId,
    MacosDistributionChannel.development => macosDevelopmentBundleId,
    MacosDistributionChannel.qa => macosQaBundleId,
  };
}

String macosKeychainServiceForDistributionChannel(
  MacosDistributionChannel channel,
) {
  return switch (channel) {
    MacosDistributionChannel.production => macosProductionKeychainService,
    MacosDistributionChannel.development => macosDevelopmentKeychainService,
    MacosDistributionChannel.qa => macosQaKeychainService,
  };
}

MacOsOptions macosSecureStorageOptionsForDistributionChannel(
  MacosDistributionChannel channel,
) {
  return MacOsOptions(
    accountName: macosKeychainServiceForDistributionChannel(channel),
    useDataProtectionKeyChain: false,
  );
}

MacOsOptions macosSecureStorageOptionsForCurrentDistributionChannel() {
  return macosSecureStorageOptionsForDistributionChannel(
    currentMacosDistributionChannel,
  );
}
