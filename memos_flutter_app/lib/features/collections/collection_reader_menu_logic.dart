enum CollectionReaderMenuState {
  hidden,
  overlayVisible,
  searchSheetVisible,
  tocSheetVisible,
  settingsSheetVisible,
  autoPageSheetVisible,
}

enum CollectionReaderMenuEvent {
  toggleOverlay,
  overlayInteraction,
  overlayTimeout,
  openSearchSheet,
  openTocSheet,
  openSettingsSheet,
  openAutoPageSheet,
  closeSheet,
  pageTurned,
  chapterJumped,
  searchResultJumped,
  autoPageStarted,
  appBackgrounded,
  readerExited,
}

class CollectionReaderMenuTransition {
  const CollectionReaderMenuTransition({
    required this.nextState,
    this.restartOverlayTimer = false,
    this.cancelOverlayTimer = false,
  });

  final CollectionReaderMenuState nextState;
  final bool restartOverlayTimer;
  final bool cancelOverlayTimer;
}

CollectionReaderMenuTransition reduceCollectionReaderMenuState(
  CollectionReaderMenuState current,
  CollectionReaderMenuEvent event,
) {
  switch (event) {
    case CollectionReaderMenuEvent.toggleOverlay:
      return current == CollectionReaderMenuState.overlayVisible
          ? const CollectionReaderMenuTransition(
              nextState: CollectionReaderMenuState.hidden,
              cancelOverlayTimer: true,
            )
          : const CollectionReaderMenuTransition(
              nextState: CollectionReaderMenuState.overlayVisible,
              cancelOverlayTimer: true,
            );
    case CollectionReaderMenuEvent.overlayInteraction:
      return current == CollectionReaderMenuState.overlayVisible
          ? const CollectionReaderMenuTransition(
              nextState: CollectionReaderMenuState.overlayVisible,
              cancelOverlayTimer: true,
            )
          : CollectionReaderMenuTransition(nextState: current);
    case CollectionReaderMenuEvent.overlayTimeout:
      return current == CollectionReaderMenuState.overlayVisible
          ? const CollectionReaderMenuTransition(
              nextState: CollectionReaderMenuState.hidden,
              cancelOverlayTimer: true,
            )
          : CollectionReaderMenuTransition(nextState: current);
    case CollectionReaderMenuEvent.openSearchSheet:
      return const CollectionReaderMenuTransition(
        nextState: CollectionReaderMenuState.searchSheetVisible,
        cancelOverlayTimer: true,
      );
    case CollectionReaderMenuEvent.openTocSheet:
      return const CollectionReaderMenuTransition(
        nextState: CollectionReaderMenuState.tocSheetVisible,
        cancelOverlayTimer: true,
      );
    case CollectionReaderMenuEvent.openSettingsSheet:
      return const CollectionReaderMenuTransition(
        nextState: CollectionReaderMenuState.settingsSheetVisible,
        cancelOverlayTimer: true,
      );
    case CollectionReaderMenuEvent.openAutoPageSheet:
      return const CollectionReaderMenuTransition(
        nextState: CollectionReaderMenuState.autoPageSheetVisible,
        cancelOverlayTimer: true,
      );
    case CollectionReaderMenuEvent.closeSheet:
      return const CollectionReaderMenuTransition(
        nextState: CollectionReaderMenuState.hidden,
        cancelOverlayTimer: true,
      );
    case CollectionReaderMenuEvent.pageTurned:
    case CollectionReaderMenuEvent.chapterJumped:
    case CollectionReaderMenuEvent.searchResultJumped:
    case CollectionReaderMenuEvent.autoPageStarted:
    case CollectionReaderMenuEvent.appBackgrounded:
    case CollectionReaderMenuEvent.readerExited:
      return const CollectionReaderMenuTransition(
        nextState: CollectionReaderMenuState.hidden,
        cancelOverlayTimer: true,
      );
  }
}
