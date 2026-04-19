import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'share_clip_models.dart';
import 'share_handler.dart';

enum ClipboardShareDetectionStatus { found, empty, unsupported, unavailable }

@immutable
class ClipboardShareDetection {
  const ClipboardShareDetection({
    required this.status,
    this.payload,
    this.textLength,
    this.host,
    this.errorCode,
  });

  final ClipboardShareDetectionStatus status;
  final SharePayload? payload;
  final int? textLength;
  final String? host;
  final String? errorCode;
}

class ClipboardShareDetector {
  Future<SharePayload?> consumeCandidate() async {
    return (await detectCandidate()).payload;
  }

  Future<ClipboardShareDetection> detectCandidate() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final rawText = _normalizeClipboardText(data?.text);
      if (rawText == null) {
        return const ClipboardShareDetection(
          status: ClipboardShareDetectionStatus.empty,
        );
      }
      final payload = SharePayload(type: SharePayloadType.text, text: rawText);
      final request = buildShareCaptureRequest(payload);
      if (request == null) {
        return ClipboardShareDetection(
          status: ClipboardShareDetectionStatus.unsupported,
          textLength: rawText.length,
        );
      }
      return ClipboardShareDetection(
        status: ClipboardShareDetectionStatus.found,
        payload: payload,
        textLength: rawText.length,
        host: request.url.host,
      );
    } on PlatformException catch (error) {
      return ClipboardShareDetection(
        status: ClipboardShareDetectionStatus.unavailable,
        errorCode: error.code,
      );
    }
  }

  void markSeen(SharePayload _) {}

  String? _normalizeClipboardText(String? rawText) {
    final text = rawText
        ?.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
