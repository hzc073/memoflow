## Why

用户反馈在开启图片压缩后，选择 5 张图片到显示“添加成功”需要二三十秒，提交 memo 还会再次等待二三十秒，同步完成又需要更久；并且在图片仍在处理时可以提交，导致 memo 创建成功但附件丢失。当前问题更像附件 staging、图片探测、压缩和上传链路的同步阻塞与重复处理，而不是 SQLite 写入本身。

本 change 需要把图片附件处理改成可感知、可等待、可验证的后台流水线，同时保留此前修复过的长图/截图防拉伸行为：压缩可以变快，但不能通过错误 resize、错误 EXIF 轴处理或破坏宽高比来换取速度。

## What Changes

- Add an attachment-processing capability that separates fast UI admission from slower staging/compression/upload work.
- Add explicit attachment processing states so the composer can show selected images immediately and prevent submit while selected attachments are not ready.
- Make staging lightweight by removing synchronous image decoding from required staging logs and avoiding duplicate staging work for already managed files.
- Run expensive compression work through a bounded background queue/worker path instead of blocking the UI isolate with synchronous native FFI calls.
- Reuse image probe metadata across preprocessing and compression planning to avoid repeated full image decode work.
- Add safe resize planning for photos, screenshots, long images, and EXIF-rotated images so output dimensions preserve the intended aspect ratio.
- Add verification tests and guardrails for latency-sensitive flow, in-flight attachment readiness, long-image no-stretch behavior, EXIF axis handling, and duplicate probe/stage avoidance.
- No breaking changes to user-facing data, server APIs, or memo content format are intended.

## Capabilities

**New Capabilities:**

- `image-attachment-processing`

**Modified Capabilities:**

- None.

## Impact

- Affected runtime areas:
  - `memos_flutter_app/lib/features/memos/memo_editor_screen.dart`
  - `memos_flutter_app/lib/features/memos/memos_list_inline_compose_coordinator.dart`
  - `memos_flutter_app/lib/features/memos/note_input_sheet.dart`
  - `memos_flutter_app/lib/state/memos/memo_composer_state.dart`
  - `memos_flutter_app/lib/state/memos/memo_mutation_service.dart`
  - `memos_flutter_app/lib/application/attachments/queued_attachment_stager.dart`
  - `memos_flutter_app/lib/application/attachments/attachment_preprocessor.dart`
  - `memos_flutter_app/lib/application/attachments/compression/**`
  - sync upload handlers that call `AttachmentPreprocessor`
- Affected tests:
  - attachment staging and composer state tests
  - compression plan/pipeline tests
  - memo editor / inline compose tests for submit gating
  - architecture guardrail or dependency-direction tests if new seams are added
- Architecture phase: `evolve_modularity`.
- Touched modularity checklist items:
  - Item 7: touched write paths must keep clear owners such as services, repositories, mutation seams, and attachment-processing services.
  - Item 8: guardrail tests must cover the highest-risk dependency directions touched by this work.
  - Item 10: coupled areas touched by the change must be left equal or better structured than before.
- Scoped modularity improvement:
  - Move reusable attachment processing state and orchestration semantics into `state`/`application` seams instead of adding more feature-local ad hoc logic.
  - Keep `application/attachments` independent from `features/*`; UI screens only render and dispatch through composer/controller seams.
