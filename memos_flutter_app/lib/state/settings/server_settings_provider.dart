import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/memos_api.dart';
import '../../data/models/server_setting.dart';
import '../memos/attachment_upload_size_limit_provider.dart';
import '../memos/memos_providers.dart';
import '../system/local_library_provider.dart';
import '../system/session_provider.dart';

enum ServerSettingSaveStatus {
  saved,
  invalidInput,
  unsupported,
  permissionDenied,
  unavailable,
  failed,
}

class ServerSettingSaveResult {
  const ServerSettingSaveResult({required this.status, this.unavailableReason});

  const ServerSettingSaveResult.saved()
    : status = ServerSettingSaveStatus.saved,
      unavailableReason = null;

  const ServerSettingSaveResult.invalidInput()
    : status = ServerSettingSaveStatus.invalidInput,
      unavailableReason = null;

  final ServerSettingSaveStatus status;
  final ServerSettingUnavailableReason? unavailableReason;

  bool get isSaved => status == ServerSettingSaveStatus.saved;
}

class ServerSettingsState {
  const ServerSettingsState({
    required this.snapshot,
    this.isSavingMemoContentLimit = false,
    this.isSavingAttachmentUploadLimit = false,
    this.memoContentSaveResult,
    this.attachmentUploadSaveResult,
  });

  const ServerSettingsState.loading()
    : snapshot = const AsyncValue<ServerSettingsSnapshot>.loading(),
      isSavingMemoContentLimit = false,
      isSavingAttachmentUploadLimit = false,
      memoContentSaveResult = null,
      attachmentUploadSaveResult = null;

  final AsyncValue<ServerSettingsSnapshot> snapshot;
  final bool isSavingMemoContentLimit;
  final bool isSavingAttachmentUploadLimit;
  final ServerSettingSaveResult? memoContentSaveResult;
  final ServerSettingSaveResult? attachmentUploadSaveResult;

  ServerSettingsState copyWith({
    AsyncValue<ServerSettingsSnapshot>? snapshot,
    bool? isSavingMemoContentLimit,
    bool? isSavingAttachmentUploadLimit,
    ServerSettingSaveResult? memoContentSaveResult,
    ServerSettingSaveResult? attachmentUploadSaveResult,
    bool clearMemoContentSaveResult = false,
    bool clearAttachmentUploadSaveResult = false,
  }) {
    return ServerSettingsState(
      snapshot: snapshot ?? this.snapshot,
      isSavingMemoContentLimit:
          isSavingMemoContentLimit ?? this.isSavingMemoContentLimit,
      isSavingAttachmentUploadLimit:
          isSavingAttachmentUploadLimit ?? this.isSavingAttachmentUploadLimit,
      memoContentSaveResult: clearMemoContentSaveResult
          ? null
          : memoContentSaveResult ?? this.memoContentSaveResult,
      attachmentUploadSaveResult: clearAttachmentUploadSaveResult
          ? null
          : attachmentUploadSaveResult ?? this.attachmentUploadSaveResult,
    );
  }
}

final serverSettingsProvider =
    StateNotifierProvider.autoDispose<
      ServerSettingsController,
      ServerSettingsState
    >((ref) {
      final currentLocalLibrary = ref.watch(currentLocalLibraryProvider);
      final currentAccount = ref.watch(
        appSessionProvider.select((state) => state.valueOrNull?.currentAccount),
      );
      final api = currentLocalLibrary != null || currentAccount == null
          ? null
          : ref.watch(memosApiProvider);
      final controller = ServerSettingsController(ref, api: api);
      unawaited(controller.load());
      return controller;
    });

class ServerSettingsController extends StateNotifier<ServerSettingsState> {
  ServerSettingsController(this._ref, {required MemosApi? api})
    : _api = api,
      super(const ServerSettingsState.loading());

  final Ref _ref;
  final MemosApi? _api;

  Future<void> load() async {
    state = state.copyWith(
      snapshot: const AsyncValue<ServerSettingsSnapshot>.loading(),
      clearMemoContentSaveResult: true,
      clearAttachmentUploadSaveResult: true,
    );

    final snapshot = await _loadSnapshot();
    if (!mounted) return;
    state = state.copyWith(snapshot: snapshot);
  }

  Future<void> refresh() => load();

  Future<ServerSettingSaveResult> updateMemoContentLimitBytes(int bytes) async {
    if (bytes <= 0) {
      const result = ServerSettingSaveResult.invalidInput();
      state = state.copyWith(memoContentSaveResult: result);
      return result;
    }

    state = state.copyWith(
      isSavingMemoContentLimit: true,
      clearMemoContentSaveResult: true,
    );
    final api = _api;
    if (api == null) {
      const result = ServerSettingSaveResult(
        status: ServerSettingSaveStatus.unavailable,
      );
      if (mounted) {
        state = state.copyWith(
          isSavingMemoContentLimit: false,
          memoContentSaveResult: result,
        );
      }
      return result;
    }
    try {
      final value = await api.updateServerMemoContentLimitBytes(bytes);
      final result = _saveResultFor(value);
      if (!mounted) return result;
      _replaceMemoContentLimit(value, result);
      return result;
    } catch (_) {
      const result = ServerSettingSaveResult(
        status: ServerSettingSaveStatus.failed,
      );
      if (mounted) {
        state = state.copyWith(
          isSavingMemoContentLimit: false,
          memoContentSaveResult: result,
        );
      }
      return result;
    }
  }

  Future<ServerSettingSaveResult> updateAttachmentUploadLimitMiB(
    int mebibytes,
  ) async {
    if (mebibytes <= 0) {
      const result = ServerSettingSaveResult.invalidInput();
      state = state.copyWith(attachmentUploadSaveResult: result);
      return result;
    }

    state = state.copyWith(
      isSavingAttachmentUploadLimit: true,
      clearAttachmentUploadSaveResult: true,
    );
    final api = _api;
    if (api == null) {
      const result = ServerSettingSaveResult(
        status: ServerSettingSaveStatus.unavailable,
      );
      if (mounted) {
        state = state.copyWith(
          isSavingAttachmentUploadLimit: false,
          attachmentUploadSaveResult: result,
        );
      }
      return result;
    }
    try {
      final value = await api.updateServerAttachmentUploadLimitMiB(mebibytes);
      final result = _saveResultFor(value);
      if (!mounted) return result;
      _replaceAttachmentUploadLimit(value, result);
      if (result.isSaved) {
        _ref.invalidate(attachmentUploadSizeLimitResolverProvider);
      }
      return result;
    } catch (_) {
      const result = ServerSettingSaveResult(
        status: ServerSettingSaveStatus.failed,
      );
      if (mounted) {
        state = state.copyWith(
          isSavingAttachmentUploadLimit: false,
          attachmentUploadSaveResult: result,
        );
      }
      return result;
    }
  }

  Future<AsyncValue<ServerSettingsSnapshot>> _loadSnapshot() async {
    final api = _api;
    if (api == null) {
      return const AsyncValue.data(ServerSettingsSnapshot.localLibrary());
    }

    try {
      return AsyncValue.data(await api.getServerSettings());
    } catch (error, stackTrace) {
      return AsyncValue.error(error, stackTrace);
    }
  }

  void _replaceMemoContentLimit(
    ServerSettingValue<int> value,
    ServerSettingSaveResult result,
  ) {
    final current = state.snapshot.valueOrNull;
    final nextValue = _valueAfterSaveAttempt(
      current?.memoContentLimitBytes,
      value,
    );
    final next = (current ?? const ServerSettingsSnapshot.localLibrary())
        .copyWith(memoContentLimitBytes: nextValue);
    state = state.copyWith(
      snapshot: AsyncValue.data(next),
      isSavingMemoContentLimit: false,
      memoContentSaveResult: result,
    );
  }

  void _replaceAttachmentUploadLimit(
    ServerSettingValue<int> value,
    ServerSettingSaveResult result,
  ) {
    final current = state.snapshot.valueOrNull;
    final nextValue = _valueAfterSaveAttempt(
      current?.attachmentUploadLimitMiB,
      value,
    );
    final next = (current ?? const ServerSettingsSnapshot.localLibrary())
        .copyWith(attachmentUploadLimitMiB: nextValue);
    state = state.copyWith(
      snapshot: AsyncValue.data(next),
      isSavingAttachmentUploadLimit: false,
      attachmentUploadSaveResult: result,
    );
  }

  ServerSettingValue<int> _valueAfterSaveAttempt(
    ServerSettingValue<int>? current,
    ServerSettingValue<int> attempted,
  ) {
    if (attempted.isKnown) return attempted;
    if (attempted.unavailableReason ==
            ServerSettingUnavailableReason.permissionDenied &&
        current != null &&
        current.isKnown) {
      return current.asReadOnly();
    }
    return attempted;
  }

  ServerSettingSaveResult _saveResultFor(ServerSettingValue<int> value) {
    if (value.isKnown) return const ServerSettingSaveResult.saved();
    if (!value.supported) {
      return ServerSettingSaveResult(
        status: ServerSettingSaveStatus.unsupported,
        unavailableReason: value.unavailableReason,
      );
    }
    if (value.unavailableReason ==
        ServerSettingUnavailableReason.permissionDenied) {
      return ServerSettingSaveResult(
        status: ServerSettingSaveStatus.permissionDenied,
        unavailableReason: value.unavailableReason,
      );
    }
    return ServerSettingSaveResult(
      status: ServerSettingSaveStatus.unavailable,
      unavailableReason: value.unavailableReason,
    );
  }
}
