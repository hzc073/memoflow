import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/desktop_quick_input_channel.dart';
import 'desktop_media_preview_request.dart';

const Duration _mediaPreviewWindowIpcAttemptDelay = Duration(milliseconds: 120);
const int _mediaPreviewWindowIpcAttempts = 12;

enum DesktopMediaPreviewWindowOpenStatus { unsupported, opened, failed }

class DesktopMediaPreviewWindowOpenResult {
  const DesktopMediaPreviewWindowOpenResult._(
    this.status, {
    this.windowId,
    this.error,
  });

  const DesktopMediaPreviewWindowOpenResult.unsupported()
    : this._(DesktopMediaPreviewWindowOpenStatus.unsupported);

  const DesktopMediaPreviewWindowOpenResult.opened({required int windowId})
    : this._(DesktopMediaPreviewWindowOpenStatus.opened, windowId: windowId);

  factory DesktopMediaPreviewWindowOpenResult.failed(Object error) {
    return DesktopMediaPreviewWindowOpenResult._(
      DesktopMediaPreviewWindowOpenStatus.failed,
      error: error,
    );
  }

  final DesktopMediaPreviewWindowOpenStatus status;
  final int? windowId;
  final Object? error;

  bool get opened => status == DesktopMediaPreviewWindowOpenStatus.opened;
}

bool isDesktopMediaPreviewSurfacePlatform({TargetPlatform? platform}) {
  if (kIsWeb) return false;
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    _ => false,
  };
}

bool supportsDesktopMediaPreviewWindow({TargetPlatform? platform}) {
  if (kIsWeb) return false;
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.macOS => true,
    TargetPlatform.windows || TargetPlatform.linux => false,
    _ => false,
  };
}

Future<DesktopMediaPreviewWindowOpenResult> openDesktopMediaPreviewWindow({
  required DesktopMediaPreviewRequest request,
  TargetPlatform? platform,
}) async {
  final resolvedPlatform = platform ?? defaultTargetPlatform;
  if (!supportsDesktopMediaPreviewWindow(platform: resolvedPlatform)) {
    return const DesktopMediaPreviewWindowOpenResult.unsupported();
  }
  final availableRequest = request.retainAvailableItems();
  if (availableRequest == null) {
    return DesktopMediaPreviewWindowOpenResult.failed(
      StateError(
        'Desktop media preview request has no available media source.',
      ),
    );
  }

  try {
    final window = await DesktopMultiWindow.createWindow(
      jsonEncode(<String, dynamic>{
        desktopWindowTypeKey: desktopWindowTypeMediaPreview,
        'payload': availableRequest.toJson(),
      }),
    );
    await window.setTitle('MemoFlow Media');
    final frame = switch (resolvedPlatform) {
      TargetPlatform.macOS => const Offset(0, 0) & Size(1040, 760),
      _ => const Offset(0, 0) & Size(1080, 780),
    };
    await window.setFrame(frame);
    await window.center();
    await window.show();
    final responsive = await _waitForMediaPreviewWindowIpc(window.windowId);
    if (!responsive) {
      try {
        await window.close();
      } catch (_) {}
      return DesktopMediaPreviewWindowOpenResult.failed(
        StateError('Desktop media preview window IPC did not become ready.'),
      );
    }
    return DesktopMediaPreviewWindowOpenResult.opened(
      windowId: window.windowId,
    );
  } catch (error) {
    return DesktopMediaPreviewWindowOpenResult.failed(error);
  }
}

Future<bool> _waitForMediaPreviewWindowIpc(int windowId) async {
  for (var attempt = 0; attempt < _mediaPreviewWindowIpcAttempts; attempt++) {
    try {
      final result = await DesktopMultiWindow.invokeMethod(
        windowId,
        desktopMediaPreviewPingMethod,
        null,
      );
      if (result == true) return true;
    } catch (_) {}
    await Future<void>.delayed(_mediaPreviewWindowIpcAttemptDelay);
  }
  return false;
}
