import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/desktop/desktop_titlebar_navigation_policy.dart';
import '../../core/desktop/window_chrome_safe_area.dart';
import '../../core/video_thumbnail_cache.dart';

class AttachmentVideoScreen extends StatefulWidget {
  const AttachmentVideoScreen({
    super.key,
    required this.title,
    this.localFile,
    this.videoUrl,
    this.thumbnailUrl,
    this.headers,
    this.cacheId,
    this.cacheSize,
    this.immersiveDesktopChrome,
    this.showViewerCloseButton = false,
    this.onClose,
    this.isDesktopOverride,
  });

  final String title;
  final File? localFile;
  final String? videoUrl;
  final String? thumbnailUrl;
  final Map<String, String>? headers;
  final String? cacheId;
  final int? cacheSize;
  final bool? immersiveDesktopChrome;
  final bool showViewerCloseButton;
  final Future<void> Function()? onClose;
  final bool? isDesktopOverride;

  @override
  State<AttachmentVideoScreen> createState() => _AttachmentVideoScreenState();
}

class _AttachmentVideoScreenState extends State<AttachmentVideoScreen> {
  VideoPlayerController? _controller;
  Future<void>? _initFuture;
  bool _showControls = true;
  String? _error;
  File? _thumbFile;
  bool _thumbLoading = false;
  Timer? _controlsTimer;
  bool _lastIsPlaying = false;
  late final FocusNode _focusNode;

  bool get _isDesktopViewer =>
      widget.isDesktopOverride ??
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  bool get _usesImmersiveDesktopChrome =>
      _isDesktopViewer && (widget.immersiveDesktopChrome ?? true);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'attachment_video_screen');
    _loadThumbnail();
    _initController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _controller?.removeListener(_handleControllerUpdate);
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initController() {
    final local = widget.localFile;
    final url = widget.videoUrl?.trim() ?? '';
    if (local == null && url.isEmpty) {
      _error = 'No video source available.';
      return;
    }

    final controller = local != null
        ? VideoPlayerController.file(local)
        : VideoPlayerController.networkUrl(
            Uri.parse(url),
            httpHeaders: widget.headers ?? const <String, String>{},
          );

    _controller = controller;
    _lastIsPlaying = controller.value.isPlaying;
    controller.addListener(_handleControllerUpdate);
    _initFuture = controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
        })
        .catchError((error) {
          if (!mounted) return;
          setState(() => _error = error.toString());
        });
  }

  void _handleControllerUpdate() {
    final controller = _controller;
    if (controller == null) return;
    final isPlaying = controller.value.isPlaying;
    if (isPlaying == _lastIsPlaying) return;
    _lastIsPlaying = isPlaying;
    if (isPlaying) {
      _scheduleHideControls();
    } else {
      _controlsTimer?.cancel();
      if (!_showControls && mounted) {
        setState(() => _showControls = true);
      }
    }
  }

  void _scheduleHideControls() {
    _controlsTimer?.cancel();
    if (!_showControls) return;
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      final controller = _controller;
      if (controller == null || !controller.value.isPlaying) return;
      setState(() => _showControls = false);
    });
  }

  Future<void> _loadThumbnail() async {
    if (_thumbLoading) return;
    final hasLocalSource = widget.localFile != null;
    final hasRemoteSource = widget.videoUrl?.trim().isNotEmpty ?? false;
    final hasPosterSource = widget.thumbnailUrl?.trim().isNotEmpty ?? false;
    if (!hasLocalSource && !hasRemoteSource && !hasPosterSource) {
      return;
    }
    _thumbLoading = true;
    final id = (widget.cacheId?.trim().isNotEmpty ?? false)
        ? widget.cacheId!.trim()
        : widget.title;
    final size = widget.cacheSize ?? 0;
    try {
      final file = await VideoThumbnailCache.getThumbnailFile(
        id: id,
        size: size,
        localFile: widget.localFile,
        videoUrl: widget.videoUrl,
        headers: widget.headers,
      ).timeout(const Duration(seconds: 4));
      if (!mounted) return;
      if (file != null && file.existsSync() && file.lengthSync() > 0) {
        setState(() => _thumbFile = file);
      }
    } catch (_) {
      if (!mounted) return;
    } finally {
      _thumbLoading = false;
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
      _controlsTimer?.cancel();
      if (!_showControls) {
        setState(() => _showControls = true);
      }
    } else {
      controller.play();
      _scheduleHideControls();
    }
    setState(() {});
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    final controller = _controller;
    if (controller == null) return;
    if (_showControls && controller.value.isPlaying) {
      _scheduleHideControls();
    } else {
      _controlsTimer?.cancel();
    }
  }

  void _closeViewer() {
    final close = widget.onClose;
    if (close != null) {
      unawaited(close());
      return;
    }
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    navigator.maybePop();
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _closeViewer();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildControls(
    VideoPlayerController controller, {
    required bool visible,
  }) {
    final isPlaying = controller.value.isPlaying;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, 0.02),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    iconSize: 64,
                    color: Colors.white,
                    onPressed: _togglePlay,
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      colors: VideoProgressColors(
                        playedColor: Colors.white,
                        bufferedColor: Colors.white.withValues(alpha: 0.4),
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoster() {
    final file = _thumbFile;
    if (file != null && file.existsSync() && file.lengthSync() > 0) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return Container(color: Colors.black);
        },
      );
    }
    final thumbnailUrl = widget.thumbnailUrl?.trim() ?? '';
    if (thumbnailUrl.isNotEmpty) {
      return Image.network(
        thumbnailUrl,
        fit: BoxFit.cover,
        headers: widget.headers ?? const <String, String>{},
        errorBuilder: (context, error, stackTrace) {
          return Container(color: Colors.black);
        },
      );
    }
    return Container(color: Colors.black);
  }

  Widget _buildViewerCloseButton(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: MediaQuery.paddingOf(context).bottom + 16,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          key: const Key('desktop_media_preview_close_button'),
          customBorder: const CircleBorder(),
          onTap: _closeViewer,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(Icons.close_rounded, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImmersiveTitleLabel(BuildContext context) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: DesktopWindowChromeSafeArea(
        contentExtendsIntoTitleBar: true,
        includeTop: true,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final error = _error;

    final body = SafeArea(
      child: Center(
        child: error != null
            ? Text(error, style: const TextStyle(color: Colors.white70))
            : controller == null
            ? Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(aspectRatio: 16 / 9, child: _buildPoster()),
                  const CircularProgressIndicator(),
                ],
              )
            : FutureBuilder<void>(
                future: _initFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(aspectRatio: 16 / 9, child: _buildPoster()),
                        const CircularProgressIndicator(),
                      ],
                    );
                  }
                  return ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      final aspect = value.aspectRatio > 0
                          ? value.aspectRatio
                          : (16 / 9);
                      final showPoster =
                          value.position == Duration.zero && !value.isPlaying;
                      final showBuffer = value.isBuffering;
                      return GestureDetector(
                        onTap: _toggleControls,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio: aspect,
                              child: VideoPlayer(controller),
                            ),
                            if (showPoster)
                              Positioned.fill(child: _buildPoster())
                            else if (showBuffer)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(),
                                ),
                              ),
                            _buildControls(controller, visible: _showControls),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );

    final scaffold = _usesImmersiveDesktopChrome
        ? Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                body,
                _buildImmersiveTitleLabel(context),
                if (widget.showViewerCloseButton)
                  _buildViewerCloseButton(context),
              ],
            ),
          )
        : Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading:
                  resolveDesktopRouteAutomaticallyImplyLeading(
                    context: context,
                    automaticallyImplyLeading: true,
                  ),
              title: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            body: body,
          );

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_, event) => _handleKeyEvent(event),
      child: scaffold,
    );
  }
}
