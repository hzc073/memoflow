import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
  });

  final String title;
  final File? localFile;
  final String? videoUrl;
  final String? thumbnailUrl;
  final Map<String, String>? headers;
  final String? cacheId;
  final int? cacheSize;

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

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
    _initController();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _controller?.removeListener(_handleControllerUpdate);
    _controller?.dispose();
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
    _initFuture = controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    }).catchError((error) {
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
    _thumbLoading = true;
    final id = (widget.cacheId?.trim().isNotEmpty ?? false) ? widget.cacheId!.trim() : widget.title;
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

  Widget _buildControls(VideoPlayerController controller, {required bool visible}) {
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
                    icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final error = _error;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: error != null
              ? Text(
                  error,
                  style: const TextStyle(color: Colors.white70),
                )
              : controller == null
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: _buildPoster(),
                        ),
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
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: _buildPoster(),
                              ),
                              const CircularProgressIndicator(),
                            ],
                          );
                        }
                        return ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: controller,
                          builder: (context, value, child) {
                            final aspect = value.aspectRatio > 0 ? value.aspectRatio : (16 / 9);
                            final showPoster = value.position == Duration.zero && !value.isPlaying;
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
                                    Positioned.fill(
                                      child: _buildPoster(),
                                    )
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
      ),
    );
  }
}
