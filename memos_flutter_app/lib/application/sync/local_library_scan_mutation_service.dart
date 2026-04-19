import '../../data/db/app_database.dart';
import '../../data/models/memo_clip_card_metadata.dart';
import '../../data/models/memo_location.dart';

class LocalLibraryScanMutationService {
  LocalLibraryScanMutationService({required this.db});

  final AppDatabase db;

  Future<void> replaceMemoFromDisk({
    required String uid,
    required String content,
    required String visibility,
    required bool pinned,
    required String state,
    required int createTimeSec,
    Object? displayTimeSec,
    bool displayTimeSpecified = false,
    required int updateTimeSec,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    int relationCount = 0,
    required int syncState,
    String? lastError,
    bool clearOutbox = false,
    String relationsMode = 'none',
    String? relationsJson,
  }) {
    return db.replaceMemoFromLocalLibrary(
      uid: uid,
      content: content,
      visibility: visibility,
      pinned: pinned,
      state: state,
      createTimeSec: createTimeSec,
      displayTimeSec: displayTimeSec,
      displayTimeSpecified: displayTimeSpecified,
      updateTimeSec: updateTimeSec,
      tags: tags,
      attachments: attachments,
      location: location,
      relationCount: relationCount,
      syncState: syncState,
      lastError: lastError,
      clearOutbox: clearOutbox,
      relationsMode: relationsMode,
      relationsJson: relationsJson,
    );
  }

  Future<void> deleteMemoFromDisk(String memoUid) {
    return db.deleteMemoFromLocalLibrary(memoUid: memoUid);
  }

  Future<void> deleteOutboxForMemo(String memoUid) {
    return db.deleteOutboxForMemo(memoUid);
  }

  Future<void> deleteMemoByUid(String memoUid) {
    return db.deleteMemoByUid(memoUid);
  }

  Future<void> upsertMemoClipCard(MemoClipCardMetadata metadata) {
    return db.upsertMemoClipCard(metadata);
  }

  Future<void> deleteMemoClipCard(String memoUid) {
    return db.deleteMemoClipCard(memoUid);
  }

  Future<void> upsertMemo({
    required String uid,
    required String content,
    required String visibility,
    required bool pinned,
    required String state,
    required int createTimeSec,
    Object? displayTimeSec,
    bool displayTimeSpecified = false,
    required int updateTimeSec,
    required List<String> tags,
    required List<Map<String, dynamic>> attachments,
    required MemoLocation? location,
    int relationCount = 0,
    required int syncState,
    String? lastError,
  }) {
    if (displayTimeSpecified) {
      return db.upsertMemo(
        uid: uid,
        content: content,
        visibility: visibility,
        pinned: pinned,
        state: state,
        createTimeSec: createTimeSec,
        displayTimeSec: displayTimeSec,
        updateTimeSec: updateTimeSec,
        tags: tags,
        attachments: attachments,
        location: location,
        relationCount: relationCount,
        syncState: syncState,
        lastError: lastError,
      );
    }
    return db.upsertMemo(
      uid: uid,
      content: content,
      visibility: visibility,
      pinned: pinned,
      state: state,
      createTimeSec: createTimeSec,
      updateTimeSec: updateTimeSec,
      tags: tags,
      attachments: attachments,
      location: location,
      relationCount: relationCount,
      syncState: syncState,
      lastError: lastError,
    );
  }

  Future<void> deleteMemoRelationsCache(String memoUid) {
    return db.deleteMemoRelationsCache(memoUid);
  }

  Future<void> upsertMemoRelationsCache(
    String memoUid, {
    required String relationsJson,
  }) {
    return db.upsertMemoRelationsCache(memoUid, relationsJson: relationsJson);
  }
}
