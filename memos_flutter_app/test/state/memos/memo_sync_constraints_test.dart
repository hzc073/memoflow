import 'package:flutter_test/flutter_test.dart';

import 'package:memos_flutter_app/data/db/app_database.dart';
import 'package:memos_flutter_app/state/memos/memo_sync_constraints.dart';

void main() {
  test('tryParseRemoteMemoLengthLimit parses max 8192 message', () {
    expect(
      tryParseRemoteMemoLengthLimit('content too long (max 8192 characters)'),
      8192,
    );
  });

  test('looksLikeRemoteMemoTooLongError recognizes generic server message', () {
    expect(
      looksLikeRemoteMemoTooLongError(
        'Memo content exceeds the maximum length allowed by the server.',
      ),
      isTrue,
    );
  });

  test('buildRemoteMemoTooLongUserMessage prioritizes server setting change', () {
    final message = buildRemoteMemoTooLongUserMessage(maxChars: 8192);

    expect(message, contains('8192'));
    expect(message, contains('Increase the server memo length limit'));
    expect(message, contains('shorten this memo'));
  });

  test('guardMemoContentForRemoteSync no longer blocks long content locally', () async {
    final db = AppDatabase(
      dbName: 'memo_sync_constraints_guard_${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(db.close);
    final allowed = await guardMemoContentForRemoteSync(
      db: db,
      enabled: true,
      memoUid: 'memo-1',
      content: 'a' * (remoteMemoMaxCharsDefault + 100),
    );

    expect(allowed, isTrue);
  });
}
