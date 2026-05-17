## 1. Implementation

- [x] 1.1 Replace the memo-card `AppPressScale` wrapper in `memos_flutter_app/lib/features/memos/widgets/memos_list_memo_card.dart` with fixed-offset press feedback capped at no more than one logical pixel.
- [x] 1.2 Preserve the existing `InkWell` and surrounding memo-card gesture callbacks for tap, tap down, tap up, tap cancel, long press, double tap, and secondary tap.
- [x] 1.3 Keep shared `AppPressScale` defaults unchanged for non-memo controls, or make any helper change strictly backward compatible and opt-in.
- [x] 1.4 Confirm the touched files remain scoped to UI interaction code and do not add API, data model, sync, private-extension, billing, entitlement, or commercial behavior.

## 2. Verification

- [x] 2.1 Add or update focused widget coverage for memo-card press feedback if the current test harness can assert the transform or wrapper behavior reliably.
- [x] 2.2 Run `flutter analyze` from `memos_flutter_app`.
- [x] 2.3 Run focused Flutter tests for the changed memo list/card area, or run `flutter test` if focused coverage is not available.
- [ ] 2.4 Manually verify on Windows desktop that pressing short and tall memo cards produces the same near-invisible fixed movement without noticeable spacing growth.
- [x] 2.5 Verify non-memo controls still use their existing press feedback.
