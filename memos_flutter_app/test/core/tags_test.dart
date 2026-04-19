import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/core/tags.dart';

void main() {
  test('normalizeTagPath preserves tag case', () {
    expect(normalizeTagPath('  #Work / Sub  '), 'Work/Sub');
    expect(normalizeTagPath('#work/Sub'), 'work/Sub');
  });

  test('extractTags preserves tag case and distinguishes variants', () {
    expect(extractTags('#Work #work'), const <String>['Work', 'work']);
  });

  test('extractTags ignores link fragments while keeping real tags', () {
    expect(
      extractTags(
        'Read [section](https://example.com/article#intro) #Work\n\n[jump](#details)',
      ),
      const <String>['Work'],
    );
  });
}
