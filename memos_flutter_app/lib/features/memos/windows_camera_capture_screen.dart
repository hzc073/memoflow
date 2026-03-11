import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../i18n/strings.g.dart';

class WindowsCameraCaptureScreen extends StatefulWidget {
  const WindowsCameraCaptureScreen({super.key});

  static Future<XFile?> capture(BuildContext context) {
    return captureWithNavigator(Navigator.of(context));
  }

  static Future<XFile?> captureWithNavigator(NavigatorState navigator) {
    return navigator.push<XFile>(
      MaterialPageRoute<XFile>(
        builder: (_) => const WindowsCameraCaptureScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<WindowsCameraCaptureScreen> createState() =>
      _WindowsCameraCaptureScreenState();
}

class _WindowsCameraCaptureScreenState
    extends State<WindowsCameraCaptureScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  bool _permissionLikelyDenied = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (!Platform.isWindows) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage = 'Camera capture is only enabled on Windows.';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _errorMessage = context.t.strings.legacy.msg_no_camera_detected;
          _permissionLikelyDenied = false;
        });
        return;
      }
      final preferred = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      final selected = preferred.isNotEmpty ? preferred.first : cameras.first;
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
        _errorMessage = null;
        _permissionLikelyDenied = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _permissionLikelyDenied = _isPermissionError(error);
        _errorMessage = _friendlyCameraError(error);
      });
    }
  }

  bool _isPermissionError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('permission') ||
        message.contains('access denied') ||
        message.contains('cameraaccessdenied');
  }

  String _friendlyCameraError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('permission') ||
        message.contains('access denied') ||
        message.contains('cameraaccessdenied')) {
      return 'Camera permission denied. Enable camera access in Windows settings.';
    }
    if (message.contains('no camera') ||
        message.contains('no device') ||
        message.contains('camera not found') ||
        message.contains('not found')) {
      return context.t.strings.legacy.msg_no_camera_detected;
    }
    if (message.contains('camera in use')) {
      return 'Camera is currently in use by another app.';
    }
    return context.t.strings.legacy.msg_camera_failed(error: error);
  }

  Future<void> _openWindowsCameraSettings() async {
    final uri = Uri.parse('ms-settings:privacy-webcam');
    final launched = await launchUrl(uri);
    if (!mounted || launched) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t.strings.legacy.msg_unable_open_windows_camera_settings,
        ),
      ),
    );
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(file);
    } catch (error) {
      if (!mounted) return;
      final message = _friendlyCameraError(error);
      final permissionError = _isPermissionError(error);
      setState(() {
        _errorMessage = message;
        _permissionLikelyDenied = permissionError;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: Text(context.t.strings.legacy.msg_capture_photo)),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_outlined, size: 42),
                    const SizedBox(height: 12),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    if (_permissionLikelyDenied) ...[
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _openWindowsCameraSettings,
                        child: Text(
                          context.t.strings.legacy.msg_open_camera_settings,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller!.value.previewSize!.height,
                      height: controller.value.previewSize!.width,
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Center(
                    child: FilledButton.icon(
                      onPressed: _capturing ? null : _capture,
                      icon: _capturing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt),
                      label: Text(_capturing ? 'Capturing...' : 'Capture'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
