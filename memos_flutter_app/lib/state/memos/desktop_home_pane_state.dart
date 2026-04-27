import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DesktopHomeSecondaryPaneMode { none, preview }

enum DesktopHomeEditorSurfaceMode { hidden, centered, fullscreen }

@immutable
sealed class DesktopHomeComposeDraftTarget {
  const DesktopHomeComposeDraftTarget();
}

class DesktopHomeComposeNewMemo extends DesktopHomeComposeDraftTarget {
  const DesktopHomeComposeNewMemo();
}

class DesktopHomeComposeEditMemo extends DesktopHomeComposeDraftTarget {
  const DesktopHomeComposeEditMemo(this.memoUid);

  final String memoUid;
}

@immutable
class DesktopHomePaneState {
  const DesktopHomePaneState({
    required this.selectedMemoUid,
    required this.secondaryPaneMode,
    required this.composeDraftTarget,
    required this.editorSurfaceMode,
  });

  static const initial = DesktopHomePaneState(
    selectedMemoUid: null,
    secondaryPaneMode: DesktopHomeSecondaryPaneMode.none,
    composeDraftTarget: null,
    editorSurfaceMode: DesktopHomeEditorSurfaceMode.hidden,
  );

  final String? selectedMemoUid;
  final DesktopHomeSecondaryPaneMode secondaryPaneMode;
  final DesktopHomeComposeDraftTarget? composeDraftTarget;
  final DesktopHomeEditorSurfaceMode editorSurfaceMode;

  bool get hasSelection => (selectedMemoUid ?? '').trim().isNotEmpty;
  bool get previewVisible =>
      secondaryPaneMode == DesktopHomeSecondaryPaneMode.preview;
  bool get editorVisible =>
      editorSurfaceMode != DesktopHomeEditorSurfaceMode.hidden;
  bool get isEditorFullscreen =>
      editorSurfaceMode == DesktopHomeEditorSurfaceMode.fullscreen;
}

class DesktopHomePaneStateController
    extends AutoDisposeNotifier<DesktopHomePaneState> {
  @override
  DesktopHomePaneState build() => DesktopHomePaneState.initial;

  void selectMemo(String memoUid) {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty) return;
    state = DesktopHomePaneState(
      selectedMemoUid: trimmedUid,
      secondaryPaneMode: state.secondaryPaneMode,
      composeDraftTarget: state.composeDraftTarget,
      editorSurfaceMode: state.editorSurfaceMode,
    );
  }

  void showPreview(String memoUid) {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty) return;
    state = DesktopHomePaneState(
      selectedMemoUid: trimmedUid,
      secondaryPaneMode: DesktopHomeSecondaryPaneMode.preview,
      composeDraftTarget: state.composeDraftTarget,
      editorSurfaceMode: state.editorSurfaceMode,
    );
  }

  void openPreviewPane({String? selectedMemoUid}) {
    final trimmedUid = selectedMemoUid?.trim();
    state = DesktopHomePaneState(
      selectedMemoUid: trimmedUid == null || trimmedUid.isEmpty
          ? state.selectedMemoUid
          : trimmedUid,
      secondaryPaneMode: DesktopHomeSecondaryPaneMode.preview,
      composeDraftTarget: state.composeDraftTarget,
      editorSurfaceMode: state.editorSurfaceMode,
    );
  }

  void closeSecondaryPane() {
    state = DesktopHomePaneState(
      selectedMemoUid: state.selectedMemoUid,
      secondaryPaneMode: DesktopHomeSecondaryPaneMode.none,
      composeDraftTarget: state.composeDraftTarget,
      editorSurfaceMode: state.editorSurfaceMode,
    );
  }

  void showComposeNew({String? selectedMemoUid}) {
    state = DesktopHomePaneState(
      selectedMemoUid: selectedMemoUid?.trim().isEmpty ?? true
          ? null
          : selectedMemoUid!.trim(),
      secondaryPaneMode: state.secondaryPaneMode,
      composeDraftTarget: const DesktopHomeComposeNewMemo(),
      editorSurfaceMode: DesktopHomeEditorSurfaceMode.centered,
    );
  }

  void showComposeEdit(String memoUid) {
    final trimmedUid = memoUid.trim();
    if (trimmedUid.isEmpty) return;
    state = DesktopHomePaneState(
      selectedMemoUid: trimmedUid,
      secondaryPaneMode: state.secondaryPaneMode,
      composeDraftTarget: DesktopHomeComposeEditMemo(trimmedUid),
      editorSurfaceMode: DesktopHomeEditorSurfaceMode.centered,
    );
  }

  void expandComposeToFullscreen() {
    if (state.composeDraftTarget == null) return;
    state = DesktopHomePaneState(
      selectedMemoUid: state.selectedMemoUid,
      secondaryPaneMode: state.secondaryPaneMode,
      composeDraftTarget: state.composeDraftTarget,
      editorSurfaceMode: DesktopHomeEditorSurfaceMode.fullscreen,
    );
  }

  void restoreComposeToCentered() {
    if (state.composeDraftTarget == null) return;
    state = DesktopHomePaneState(
      selectedMemoUid: state.selectedMemoUid,
      secondaryPaneMode: state.secondaryPaneMode,
      composeDraftTarget: state.composeDraftTarget,
      editorSurfaceMode: DesktopHomeEditorSurfaceMode.centered,
    );
  }

  void closeCompose() {
    state = DesktopHomePaneState(
      selectedMemoUid: state.selectedMemoUid,
      secondaryPaneMode: state.secondaryPaneMode,
      composeDraftTarget: null,
      editorSurfaceMode: DesktopHomeEditorSurfaceMode.hidden,
    );
  }

  void restore(DesktopHomePaneState value) {
    state = value;
  }

  void clear() {
    state = DesktopHomePaneState.initial;
  }
}

final desktopHomePaneStateProvider =
    AutoDisposeNotifierProvider<
      DesktopHomePaneStateController,
      DesktopHomePaneState
    >(DesktopHomePaneStateController.new);
