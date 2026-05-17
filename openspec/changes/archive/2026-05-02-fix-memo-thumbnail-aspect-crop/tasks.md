## 1. Core Thumbnail Sizing

- [x] 1.1 在 `memos_flutter_app/lib/core/image_thumbnail_cache.dart` 增加 aspect-safe thumbnail cache target helper，输入 tile dimensions、`devicePixelRatio` 和 optional source dimensions。
- [x] 1.2 保留现有 `resolveThumbnailCacheExtent` 行为，兼容仍只需要 single extent 的调用方。
- [x] 1.3 在 `memos_flutter_app/test/core/image_thumbnail_cache_test.dart` 增加 focused unit tests，覆盖 wide、tall、square、height-limited、unknown-dimension 和 max-decode-bound cases。

## 2. Memo Card Grid Integration

- [x] 2.1 更新 `MemoMediaGrid`，在 `MemoImageEntry.width` / `height` 可用时通过 core aspect-safe helper 计算 image thumbnail cache targets。
- [x] 2.2 更新 `MemoImageGrid` 使用同一个 helper，确保 image-only grids 和 mixed-media grids 共享同一 sizing policy。
- [x] 2.3 保持 `ImagePreviewTile` generic；仅在必要时调整，避免 caller-provided cache hints 强制触发 distorted exact two-axis thumbnail decoding。
- [x] 2.4 确认 thumbnail presentation 仍使用 `BoxFit.cover`，且 preview/gallery presentation 保持不变。

## 3. Composer Pending Preview Integration

- [x] 3.1 更新 `NoteInputSheet` pending image attachment tile，使用 core helper 的 unknown-dimension safe fallback，避免把 62px tile 同时传成 exact `cacheWidth` / `cacheHeight`。
- [x] 3.2 更新 `MemosListInlineComposeCard` 的 `_InlineAttachmentTile`，让 inline pending image previews 与 `NoteInputSheet` 共享同一 sizing policy。
- [x] 3.3 确认 pending image thumbnails 继续使用 `BoxFit.cover`，且 remove button、processing overlay、tap-to-preview behavior 不变。

## 4. Regression Coverage

- [x] 4.1 为 wide memo image 在 square home thumbnail tile 中渲染增加 widget coverage，确认不会使用 exact tile-ratio cache sizing。
- [x] 4.2 为 tall memo image 在 square home thumbnail tile 中渲染增加 widget coverage，确认不会使用 exact tile-ratio cache sizing。
- [x] 4.3 为 height-limited memo media grid 增加 coverage，确保 non-square tile shape 不会强制产生 distorted decode/cache dimensions。
- [x] 4.4 新增或更新测试，验证 unknown source dimensions 使用 safe fallback，而不是 exact two-axis cache sizing。
- [x] 4.5 为 `NoteInputSheet` pending image preview 增加 coverage，确认 local pending image 不再使用 exact square two-axis cache sizing。
- [x] 4.6 为 inline compose pending image preview 增加 coverage，确认添加图片后的 62px preview 不会因为 cache hints 被压扁。

## 5. Validation

- [x] 5.1 在 `memos_flutter_app` 运行 `flutter test test/core/image_thumbnail_cache_test.dart`。
- [x] 5.2 运行受影响的 focused memo/image preview/composer widget tests。
- [ ] 5.3 在 `memos_flutter_app` 运行 `flutter analyze`。
- [ ] 5.4 交付 release 前，在 `memos_flutter_app` 运行 `flutter test`。
