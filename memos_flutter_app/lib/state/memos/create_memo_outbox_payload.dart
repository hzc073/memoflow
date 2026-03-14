import '../../data/models/memo_location.dart';

Map<String, dynamic> buildCreateMemoOutboxPayload({
  required String uid,
  required String content,
  required String visibility,
  required bool pinned,
  required int createTimeSec,
  required bool hasAttachments,
  MemoLocation? location,
  List<Map<String, dynamic>> relations = const <Map<String, dynamic>>[],
}) {
  return <String, dynamic>{
    'uid': uid,
    'content': content,
    'visibility': visibility,
    'pinned': pinned,
    'has_attachments': hasAttachments,
    'create_time': createTimeSec,
    'display_time': createTimeSec,
    if (location != null) 'location': location.toJson(),
    if (relations.isNotEmpty) 'relations': relations,
  };
}
