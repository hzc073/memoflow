import 'dart:convert';
import 'dart:typed_data';

enum AiAnalysisType { emotionMap }

enum AiTaskStatus { draft, queued, retrieving, generating, completed, failed }

enum AiIndexJobStatus { queued, running, completed, failed, cancelled }

enum AiIndexJobReason {
  memoCreated,
  memoUpdated,
  memoDeleted,
  policyChanged,
  manualRebuild,
  migration,
}

enum AiEmbeddingStatus { pending, ready, failed, stale }

enum AiAnalysisTemplateKind { builtIn, custom, legacy }

String aiAnalysisTypeToStorage(AiAnalysisType value) => switch (value) {
  AiAnalysisType.emotionMap => 'emotion_map',
};

String aiTaskStatusToStorage(AiTaskStatus value) => switch (value) {
  AiTaskStatus.draft => 'draft',
  AiTaskStatus.queued => 'queued',
  AiTaskStatus.retrieving => 'retrieving',
  AiTaskStatus.generating => 'generating',
  AiTaskStatus.completed => 'completed',
  AiTaskStatus.failed => 'failed',
};

AiTaskStatus aiTaskStatusFromStorage(String value) {
  return switch (value.trim().toLowerCase()) {
    'draft' => AiTaskStatus.draft,
    'queued' => AiTaskStatus.queued,
    'retrieving' => AiTaskStatus.retrieving,
    'generating' => AiTaskStatus.generating,
    'completed' => AiTaskStatus.completed,
    _ => AiTaskStatus.failed,
  };
}

String aiIndexJobStatusToStorage(AiIndexJobStatus value) => switch (value) {
  AiIndexJobStatus.queued => 'queued',
  AiIndexJobStatus.running => 'running',
  AiIndexJobStatus.completed => 'completed',
  AiIndexJobStatus.failed => 'failed',
  AiIndexJobStatus.cancelled => 'cancelled',
};

AiIndexJobStatus aiIndexJobStatusFromStorage(String value) {
  return switch (value.trim().toLowerCase()) {
    'queued' => AiIndexJobStatus.queued,
    'running' => AiIndexJobStatus.running,
    'completed' => AiIndexJobStatus.completed,
    'cancelled' => AiIndexJobStatus.cancelled,
    _ => AiIndexJobStatus.failed,
  };
}

String aiIndexJobReasonToStorage(AiIndexJobReason value) => switch (value) {
  AiIndexJobReason.memoCreated => 'memo_created',
  AiIndexJobReason.memoUpdated => 'memo_updated',
  AiIndexJobReason.memoDeleted => 'memo_deleted',
  AiIndexJobReason.policyChanged => 'policy_changed',
  AiIndexJobReason.manualRebuild => 'manual_rebuild',
  AiIndexJobReason.migration => 'migration',
};

AiIndexJobReason aiIndexJobReasonFromStorage(String value) {
  return switch (value.trim().toLowerCase()) {
    'memo_created' => AiIndexJobReason.memoCreated,
    'memo_deleted' => AiIndexJobReason.memoDeleted,
    'policy_changed' => AiIndexJobReason.policyChanged,
    'manual_rebuild' => AiIndexJobReason.manualRebuild,
    'migration' => AiIndexJobReason.migration,
    _ => AiIndexJobReason.memoUpdated,
  };
}

String aiEmbeddingStatusToStorage(AiEmbeddingStatus value) => switch (value) {
  AiEmbeddingStatus.pending => 'pending',
  AiEmbeddingStatus.ready => 'ready',
  AiEmbeddingStatus.failed => 'failed',
  AiEmbeddingStatus.stale => 'stale',
};

AiEmbeddingStatus aiEmbeddingStatusFromStorage(String value) {
  return switch (value.trim().toLowerCase()) {
    'pending' => AiEmbeddingStatus.pending,
    'ready' => AiEmbeddingStatus.ready,
    'stale' => AiEmbeddingStatus.stale,
    _ => AiEmbeddingStatus.failed,
  };
}

String aiAnalysisTemplateKindToStorage(AiAnalysisTemplateKind value) =>
    switch (value) {
      AiAnalysisTemplateKind.builtIn => 'built_in',
      AiAnalysisTemplateKind.custom => 'custom',
      AiAnalysisTemplateKind.legacy => 'legacy',
    };

AiAnalysisTemplateKind aiAnalysisTemplateKindFromStorage(String value) {
  return switch (value.trim().toLowerCase()) {
    'built_in' => AiAnalysisTemplateKind.builtIn,
    'custom' => AiAnalysisTemplateKind.custom,
    _ => AiAnalysisTemplateKind.legacy,
  };
}

class AiAnalysisTemplateSnapshot {
  const AiAnalysisTemplateSnapshot({
    required this.kind,
    this.templateId = '',
    this.titleSnapshot = '',
    this.iconKeySnapshot = '',
  });

  static const legacy = AiAnalysisTemplateSnapshot(
    kind: AiAnalysisTemplateKind.legacy,
  );

  final AiAnalysisTemplateKind kind;
  final String templateId;
  final String titleSnapshot;
  final String iconKeySnapshot;
}

Float32List? decodeFloat32VectorBlob(Object? rawBlob) {
  if (rawBlob is! Uint8List || rawBlob.isEmpty) {
    return null;
  }
  if (rawBlob.lengthInBytes % Float32List.bytesPerElement != 0) {
    return null;
  }
  final blob = rawBlob.offsetInBytes % Float32List.bytesPerElement == 0
      ? rawBlob
      : Uint8List.fromList(rawBlob);
  return blob.buffer.asFloat32List(
    blob.offsetInBytes,
    blob.lengthInBytes ~/ Float32List.bytesPerElement,
  );
}

class AiChunkDraft {
  const AiChunkDraft({
    required this.chunkIndex,
    required this.content,
    required this.contentHash,
    required this.memoContentHash,
    required this.charStart,
    required this.charEnd,
    required this.tokenEstimate,
    required this.memoCreateTime,
    required this.memoUpdateTime,
    required this.memoVisibility,
  });

  final int chunkIndex;
  final String content;
  final String contentHash;
  final String memoContentHash;
  final int charStart;
  final int charEnd;
  final int tokenEstimate;
  final int memoCreateTime;
  final int memoUpdateTime;
  final String memoVisibility;
}

class AiChunkRecord {
  const AiChunkRecord({
    required this.id,
    required this.memoUid,
    required this.chunkIndex,
    required this.content,
    required this.contentHash,
    required this.memoContentHash,
    required this.charStart,
    required this.charEnd,
    required this.tokenEstimate,
    required this.memoCreateTime,
    required this.memoUpdateTime,
    required this.memoVisibility,
    required this.isActive,
  });

  final int id;
  final String memoUid;
  final int chunkIndex;
  final String content;
  final String contentHash;
  final String memoContentHash;
  final int charStart;
  final int charEnd;
  final int tokenEstimate;
  final int memoCreateTime;
  final int memoUpdateTime;
  final String memoVisibility;
  final bool isActive;

  factory AiChunkRecord.fromRow(Map<String, dynamic> row) {
    return AiChunkRecord(
      id: (row['id'] as int?) ?? 0,
      memoUid: (row['memo_uid'] as String?) ?? '',
      chunkIndex: (row['chunk_index'] as int?) ?? 0,
      content: (row['content'] as String?) ?? '',
      contentHash: (row['content_hash'] as String?) ?? '',
      memoContentHash: (row['memo_content_hash'] as String?) ?? '',
      charStart: (row['char_start'] as int?) ?? 0,
      charEnd: (row['char_end'] as int?) ?? 0,
      tokenEstimate: (row['token_estimate'] as int?) ?? 0,
      memoCreateTime: (row['memo_create_time'] as int?) ?? 0,
      memoUpdateTime: (row['memo_update_time'] as int?) ?? 0,
      memoVisibility: (row['memo_visibility'] as String?) ?? 'PRIVATE',
      isActive: ((row['is_active'] as int?) ?? 0) == 1,
    );
  }
}

class AiEmbeddingRecord {
  const AiEmbeddingRecord({
    required this.id,
    required this.chunkId,
    required this.baseUrl,
    required this.model,
    required this.dimensions,
    required this.status,
    required this.vector,
    required this.errorText,
  });

  final int id;
  final int chunkId;
  final String baseUrl;
  final String model;
  final int dimensions;
  final AiEmbeddingStatus status;
  final Float32List? vector;
  final String? errorText;

  factory AiEmbeddingRecord.fromRow(Map<String, dynamic> row) {
    return AiEmbeddingRecord(
      id: (row['id'] as int?) ?? 0,
      chunkId: (row['chunk_id'] as int?) ?? 0,
      baseUrl: (row['base_url'] as String?) ?? '',
      model: (row['model'] as String?) ?? '',
      dimensions: (row['dimensions'] as int?) ?? 0,
      status: aiEmbeddingStatusFromStorage(
        (row['status'] as String?) ?? 'failed',
      ),
      vector: decodeFloat32VectorBlob(row['vector_blob']),
      errorText: row['error_text'] as String?,
    );
  }
}

class AiEvidenceCandidate {
  const AiEvidenceCandidate({
    required this.evidenceKey,
    required this.sectionKey,
    this.threadKey,
    this.threadHint,
    this.sourceThemeKey,
    required this.memoUid,
    required this.chunkId,
    required this.quoteText,
    required this.charStart,
    required this.charEnd,
    required this.relevanceScore,
    required this.memoCreateTime,
    required this.memoVisibility,
  });

  final String evidenceKey;
  final String sectionKey;
  final String? threadKey;
  final String? threadHint;
  final String? sourceThemeKey;
  final String memoUid;
  final int chunkId;
  final String quoteText;
  final int charStart;
  final int charEnd;
  final double relevanceScore;
  final int memoCreateTime;
  final String memoVisibility;

  Map<String, dynamic> toJson() => {
    'evidence_key': evidenceKey,
    'section_key': sectionKey,
    if ((threadKey ?? '').trim().isNotEmpty) 'thread_key': threadKey,
    if ((threadHint ?? '').trim().isNotEmpty) 'thread_hint': threadHint,
    if ((sourceThemeKey ?? '').trim().isNotEmpty)
      'source_theme_key': sourceThemeKey,
    'memo_uid': memoUid,
    'chunk_id': chunkId,
    'quote_text': quoteText,
    'char_start': charStart,
    'char_end': charEnd,
    'relevance_score': relevanceScore,
  };
}

class AiRetrievalPreviewItem {
  const AiRetrievalPreviewItem({
    required this.memoUid,
    required this.chunkId,
    required this.createdAt,
    required this.visibility,
    required this.content,
    required this.embeddingStatus,
  });

  final String memoUid;
  final int chunkId;
  final DateTime createdAt;
  final String visibility;
  final String content;
  final AiEmbeddingStatus embeddingStatus;
}

class AiRetrievalPreviewPayload {
  const AiRetrievalPreviewPayload({
    required this.totalMatchingMemos,
    required this.candidateChunks,
    required this.embeddingReady,
    required this.embeddingPending,
    required this.embeddingFailed,
    required this.isSampled,
    required this.items,
  });

  final int totalMatchingMemos;
  final int candidateChunks;
  final int embeddingReady;
  final int embeddingPending;
  final int embeddingFailed;
  final bool isSampled;
  final List<AiRetrievalPreviewItem> items;

  bool get hasContent => candidateChunks > 0;

  static const empty = AiRetrievalPreviewPayload(
    totalMatchingMemos: 0,
    candidateChunks: 0,
    embeddingReady: 0,
    embeddingPending: 0,
    embeddingFailed: 0,
    isSampled: false,
    items: <AiRetrievalPreviewItem>[],
  );
}

class AiAnalysisSectionData {
  const AiAnalysisSectionData({
    required this.sectionKey,
    required this.title,
    required this.body,
    required this.evidenceKeys,
  });

  final String sectionKey;
  final String title;
  final String body;
  final List<String> evidenceKeys;

  Map<String, dynamic> toJson() => {
    'section_key': sectionKey,
    'title': title,
    'body': body,
    'evidence_keys': evidenceKeys,
  };
}

class AiAnalysisEvidenceData {
  const AiAnalysisEvidenceData({
    required this.evidenceKey,
    required this.sectionKey,
    required this.memoUid,
    required this.chunkId,
    required this.quoteText,
    required this.charStart,
    required this.charEnd,
    required this.relevanceScore,
  });

  final String evidenceKey;
  final String sectionKey;
  final String memoUid;
  final int chunkId;
  final String quoteText;
  final int charStart;
  final int charEnd;
  final double relevanceScore;

  Map<String, dynamic> toJson() => {
    'evidence_key': evidenceKey,
    'section_key': sectionKey,
    'memo_uid': memoUid,
    'chunk_id': chunkId,
    'quote_text': quoteText,
    'char_start': charStart,
    'char_end': charEnd,
    'relevance_score': relevanceScore,
  };
}

class AiStructuredAnalysisResult {
  const AiStructuredAnalysisResult({
    required this.schemaVersion,
    required this.analysisType,
    required this.summary,
    required this.sections,
    required this.evidences,
    required this.followUpSuggestions,
    required this.rawResponseText,
  });

  final int schemaVersion;
  final AiAnalysisType analysisType;
  final String summary;
  final List<AiAnalysisSectionData> sections;
  final List<AiAnalysisEvidenceData> evidences;
  final List<String> followUpSuggestions;
  final String rawResponseText;

  String get normalizedResultJson => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'analysis_type': aiAnalysisTypeToStorage(analysisType),
    'summary': summary,
    'sections': sections.map((item) => item.toJson()).toList(growable: false),
    'evidences': evidences.map((item) => item.toJson()).toList(growable: false),
    'follow_up_suggestions': followUpSuggestions,
  };
}

class AiSavedAnalysisReport {
  const AiSavedAnalysisReport({
    required this.taskId,
    required this.taskUid,
    required this.status,
    required this.summary,
    required this.sections,
    required this.evidences,
    required this.followUpSuggestions,
    required this.isStale,
  });

  final int taskId;
  final String taskUid;
  final AiTaskStatus status;
  final String summary;
  final List<AiAnalysisSectionData> sections;
  final List<AiAnalysisEvidenceData> evidences;
  final List<String> followUpSuggestions;
  final bool isStale;
}

class AiSavedAnalysisHistoryEntry {
  const AiSavedAnalysisHistoryEntry({
    required this.taskId,
    required this.taskUid,
    required this.status,
    required this.summary,
    required this.promptTemplate,
    required this.rangeStart,
    required this.rangeEndExclusive,
    required this.includePublic,
    required this.includePrivate,
    required this.includeProtected,
    required this.createdTime,
    required this.isStale,
    this.templateKind = AiAnalysisTemplateKind.legacy,
    this.templateId = '',
    this.templateTitleSnapshot = '',
    this.templateIconKeySnapshot = '',
  });

  final int taskId;
  final String taskUid;
  final AiTaskStatus status;
  final String summary;
  final String promptTemplate;
  final int rangeStart;
  final int rangeEndExclusive;
  final bool includePublic;
  final bool includePrivate;
  final bool includeProtected;
  final int createdTime;
  final bool isStale;
  final AiAnalysisTemplateKind templateKind;
  final String templateId;
  final String templateTitleSnapshot;
  final String templateIconKeySnapshot;
}
