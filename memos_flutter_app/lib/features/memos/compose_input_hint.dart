bool shouldShowComposeDraftHint({
  required bool enableDraftHint,
  required int pendingDraftCount,
  required bool hasCurrentComposeContent,
}) {
  return enableDraftHint && pendingDraftCount > 0 && !hasCurrentComposeContent;
}
