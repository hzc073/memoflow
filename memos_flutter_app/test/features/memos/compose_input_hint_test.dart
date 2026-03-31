import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/features/memos/compose_input_hint.dart';

void main() {
  test('returns false when no drafts exist', () {
    expect(
      shouldShowComposeDraftHint(
        enableDraftHint: true,
        pendingDraftCount: 0,
        hasCurrentComposeContent: false,
      ),
      isFalse,
    );
  });

  test('returns true for blank composer when drafts exist', () {
    expect(
      shouldShowComposeDraftHint(
        enableDraftHint: true,
        pendingDraftCount: 2,
        hasCurrentComposeContent: false,
      ),
      isTrue,
    );
  });

  test('returns false when composer already has content', () {
    expect(
      shouldShowComposeDraftHint(
        enableDraftHint: true,
        pendingDraftCount: 2,
        hasCurrentComposeContent: true,
      ),
      isFalse,
    );
  });

  test('returns false when draft hint is disabled', () {
    expect(
      shouldShowComposeDraftHint(
        enableDraftHint: false,
        pendingDraftCount: 2,
        hasCurrentComposeContent: false,
      ),
      isFalse,
    );
  });
}
