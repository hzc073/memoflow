import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/memoflow_bridge_settings.dart';
import '../data/settings/memoflow_bridge_settings_repository.dart';
import 'session_provider.dart';

final memoFlowBridgeSettingsRepositoryProvider =
    Provider<MemoFlowBridgeSettingsRepository>((ref) {
      final accountKey = ref.watch(
        appSessionProvider.select((state) => state.valueOrNull?.currentKey),
      );
      return MemoFlowBridgeSettingsRepository(
        ref.watch(secureStorageProvider),
        accountKey: accountKey,
      );
    });

final memoFlowBridgeSettingsProvider =
    StateNotifierProvider<
      MemoFlowBridgeSettingsController,
      MemoFlowBridgeSettings
    >((ref) {
      return MemoFlowBridgeSettingsController(
        ref.watch(memoFlowBridgeSettingsRepositoryProvider),
      );
    });

class MemoFlowBridgeSettingsController
    extends StateNotifier<MemoFlowBridgeSettings> {
  MemoFlowBridgeSettingsController(this._repo)
    : super(MemoFlowBridgeSettings.defaults) {
    unawaited(_load());
  }

  final MemoFlowBridgeSettingsRepository _repo;

  Future<void> _load() async {
    state = await _repo.read();
  }

  void _setAndPersist(MemoFlowBridgeSettings next) {
    state = next;
    unawaited(_repo.write(next));
  }

  void setEnabled(bool value) {
    _setAndPersist(state.copyWith(enabled: value));
  }

  void setHost(String value) {
    _setAndPersist(state.copyWith(host: value.trim()));
  }

  void setPort(int value) {
    if (value <= 0 || value > 65535) return;
    _setAndPersist(state.copyWith(port: value));
  }

  void setToken(String value) {
    _setAndPersist(state.copyWith(token: value.trim()));
  }

  void setServerName(String value) {
    _setAndPersist(state.copyWith(serverName: value.trim()));
  }

  void setDeviceName(String value) {
    _setAndPersist(state.copyWith(deviceName: value.trim()));
  }

  void setApiVersion(String value) {
    final next = value.trim();
    if (next.isEmpty) return;
    _setAndPersist(state.copyWith(apiVersion: next));
  }

  void savePairing({
    required String host,
    required int port,
    required String token,
    required String serverName,
    required String deviceName,
    required String apiVersion,
  }) {
    _setAndPersist(
      state.copyWith(
        enabled: true,
        host: host.trim(),
        port: port,
        token: token.trim(),
        serverName: serverName.trim(),
        deviceName: deviceName.trim(),
        apiVersion: apiVersion.trim().isEmpty ? state.apiVersion : apiVersion,
        lastPairedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void clearPairing() {
    _setAndPersist(
      state.copyWith(
        enabled: false,
        host: '',
        token: '',
        serverName: '',
        lastPairedAtMs: 0,
      ),
    );
  }
}
