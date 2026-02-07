import '../models/local_memo.dart';

String buildLocalLibraryMarkdown(LocalMemo memo) {
  final tags = memo.tags.isEmpty ? '' : memo.tags.map((t) => '#$t').join(' ');
  final header = <String>[
    '---',
    'uid: ${memo.uid}',
    'created: ${memo.createTime.toIso8601String()}',
    'updated: ${memo.updateTime.toIso8601String()}',
    'visibility: ${memo.visibility}',
    'pinned: ${memo.pinned}',
    if (memo.state.isNotEmpty) 'state: ${memo.state}',
    if (tags.isNotEmpty) 'tags: $tags',
    '---',
    '',
  ].join('\n');
  return '$header${memo.content.trimRight()}\n';
}
