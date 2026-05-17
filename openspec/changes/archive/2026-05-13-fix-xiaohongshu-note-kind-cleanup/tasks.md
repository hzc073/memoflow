## 1. Xiaohongshu Parser Rules

- [x] 1.1 Add `xiaohongshu_note_content_cleaner.dart` with target-note cleanup, kind evidence, and image URL normalization.
- [x] 1.2 Update `XiaohongshuSharePageParser` to classify page kind from target-note evidence instead of broad unrelated page state.
- [x] 1.3 Preserve video-note classification when direct target video candidates are present.

## 2. Regression Coverage

- [x] 2.1 Add parser tests proving image notes with unrelated recommended videos remain `article`.
- [x] 2.2 Add formatter coverage proving article body text is preserved after Xiaohongshu image-note parsing.
- [x] 2.3 Add image URL normalization coverage for `http://sns-webpic...` to `https://...`.

## 3. Verification

- [x] 3.1 Run focused share parser/formatter tests.
- [x] 3.2 Run `flutter analyze` if focused tests pass.
