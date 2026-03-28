import '../../application/sync/migration/memoflow_migration_models.dart';

enum MemoFlowMigrationSenderPhase {
  selecting,
  buildingPackage,
  packageReady,
  waitingForReceiver,
  uploading,
  completed,
  failed,
}

enum MemoFlowMigrationReceiverPhase {
  idle,
  startingSession,
  waitingProposal,
  reviewingProposal,
  receiving,
  completed,
  failed,
  cancelled,
}

class MemoFlowMigrationSenderState {
  static const Object _unset = Object();

  const MemoFlowMigrationSenderState({
    required this.isLocalLibraryMode,
    required this.includeMemos,
    required this.includeSettings,
    required this.selectedConfigTypes,
    required this.phase,
    this.packageResult,
    this.statusMessage,
    this.errorMessage,
    this.uploadProgress = 0,
    this.activeProposalId,
    this.latestStatus,
    this.result,
  });

  final bool isLocalLibraryMode;
  final bool includeMemos;
  final bool includeSettings;
  final Set<MemoFlowMigrationConfigType> selectedConfigTypes;
  final MemoFlowMigrationSenderPhase phase;
  final MemoFlowMigrationPackageBuildResult? packageResult;
  final String? statusMessage;
  final String? errorMessage;
  final double uploadProgress;
  final String? activeProposalId;
  final MemoFlowMigrationStatusSnapshot? latestStatus;
  final MemoFlowMigrationResult? result;

  bool get canBuildPackage => includeMemos || effectiveConfigTypes.isNotEmpty;

  Set<MemoFlowMigrationConfigType> get effectiveConfigTypes {
    return includeSettings
        ? selectedConfigTypes
        : const <MemoFlowMigrationConfigType>{};
  }

  MemoFlowMigrationSenderState copyWith({
    bool? isLocalLibraryMode,
    bool? includeMemos,
    bool? includeSettings,
    Set<MemoFlowMigrationConfigType>? selectedConfigTypes,
    MemoFlowMigrationSenderPhase? phase,
    Object? packageResult = _unset,
    Object? statusMessage = _unset,
    Object? errorMessage = _unset,
    double? uploadProgress,
    Object? activeProposalId = _unset,
    Object? latestStatus = _unset,
    Object? result = _unset,
  }) {
    return MemoFlowMigrationSenderState(
      isLocalLibraryMode: isLocalLibraryMode ?? this.isLocalLibraryMode,
      includeMemos: includeMemos ?? this.includeMemos,
      includeSettings: includeSettings ?? this.includeSettings,
      selectedConfigTypes: selectedConfigTypes ?? this.selectedConfigTypes,
      phase: phase ?? this.phase,
      packageResult: identical(packageResult, _unset)
          ? this.packageResult
          : packageResult as MemoFlowMigrationPackageBuildResult?,
      statusMessage: identical(statusMessage, _unset)
          ? this.statusMessage
          : statusMessage as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      activeProposalId: identical(activeProposalId, _unset)
          ? this.activeProposalId
          : activeProposalId as String?,
      latestStatus: identical(latestStatus, _unset)
          ? this.latestStatus
          : latestStatus as MemoFlowMigrationStatusSnapshot?,
      result: identical(result, _unset)
          ? this.result
          : result as MemoFlowMigrationResult?,
    );
  }

  factory MemoFlowMigrationSenderState.initial({
    required bool isLocalLibraryMode,
  }) {
    return MemoFlowMigrationSenderState(
      isLocalLibraryMode: isLocalLibraryMode,
      includeMemos: isLocalLibraryMode,
      includeSettings: false,
      selectedConfigTypes: memoFlowMigrationSafeConfigDefaults,
      phase: MemoFlowMigrationSenderPhase.selecting,
    );
  }
}

class MemoFlowMigrationReceiverState {
  static const Object _unset = Object();

  const MemoFlowMigrationReceiverState({
    required this.phase,
    required this.canOverwriteCurrentWorkspace,
    required this.acceptedSensitiveConfigTypes,
    this.sessionDescriptor,
    this.qrPayload,
    this.proposal,
    this.selectedReceiveMode = MemoFlowMigrationReceiveMode.newWorkspace,
    this.statusMessage,
    this.errorMessage,
    this.latestStatus,
    this.result,
  });

  final MemoFlowMigrationReceiverPhase phase;
  final MemoFlowMigrationSessionDescriptor? sessionDescriptor;
  final String? qrPayload;
  final MemoFlowMigrationProposal? proposal;
  final bool canOverwriteCurrentWorkspace;
  final MemoFlowMigrationReceiveMode selectedReceiveMode;
  final Set<MemoFlowMigrationConfigType> acceptedSensitiveConfigTypes;
  final String? statusMessage;
  final String? errorMessage;
  final MemoFlowMigrationStatusSnapshot? latestStatus;
  final MemoFlowMigrationResult? result;

  MemoFlowMigrationReceiverState copyWith({
    MemoFlowMigrationReceiverPhase? phase,
    Object? sessionDescriptor = _unset,
    Object? qrPayload = _unset,
    Object? proposal = _unset,
    bool? canOverwriteCurrentWorkspace,
    MemoFlowMigrationReceiveMode? selectedReceiveMode,
    Set<MemoFlowMigrationConfigType>? acceptedSensitiveConfigTypes,
    Object? statusMessage = _unset,
    Object? errorMessage = _unset,
    Object? latestStatus = _unset,
    Object? result = _unset,
  }) {
    return MemoFlowMigrationReceiverState(
      phase: phase ?? this.phase,
      sessionDescriptor: identical(sessionDescriptor, _unset)
          ? this.sessionDescriptor
          : sessionDescriptor as MemoFlowMigrationSessionDescriptor?,
      qrPayload: identical(qrPayload, _unset)
          ? this.qrPayload
          : qrPayload as String?,
      proposal: identical(proposal, _unset)
          ? this.proposal
          : proposal as MemoFlowMigrationProposal?,
      canOverwriteCurrentWorkspace:
          canOverwriteCurrentWorkspace ?? this.canOverwriteCurrentWorkspace,
      selectedReceiveMode: selectedReceiveMode ?? this.selectedReceiveMode,
      acceptedSensitiveConfigTypes:
          acceptedSensitiveConfigTypes ?? this.acceptedSensitiveConfigTypes,
      statusMessage: identical(statusMessage, _unset)
          ? this.statusMessage
          : statusMessage as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      latestStatus: identical(latestStatus, _unset)
          ? this.latestStatus
          : latestStatus as MemoFlowMigrationStatusSnapshot?,
      result: identical(result, _unset)
          ? this.result
          : result as MemoFlowMigrationResult?,
    );
  }

  factory MemoFlowMigrationReceiverState.initial() {
    return const MemoFlowMigrationReceiverState(
      phase: MemoFlowMigrationReceiverPhase.idle,
      canOverwriteCurrentWorkspace: false,
      acceptedSensitiveConfigTypes: <MemoFlowMigrationConfigType>{},
    );
  }
}
