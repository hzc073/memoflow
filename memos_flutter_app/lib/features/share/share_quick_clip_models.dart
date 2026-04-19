import 'package:flutter/foundation.dart';

@immutable
class ShareQuickClipSubmission {
  const ShareQuickClipSubmission({
    required this.tags,
    required this.textOnly,
    required this.titleAndLinkOnly,
  });

  final List<String> tags;
  final bool textOnly;
  final bool titleAndLinkOnly;
}
