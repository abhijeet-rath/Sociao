import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

/// Plays a network video, filling its parent. Tap toggles play / pause.
/// Owns and disposes its controller; only mount it for the visible page.
class VideoSurface extends StatefulWidget {
  const VideoSurface({
    super.key,
    required this.url,
    this.posterUrl,
    this.fit = BoxFit.cover,
  });

  final String url;
  final String? posterUrl;
  final BoxFit fit;

  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface> {
  late VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    _failed = false;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller
        .initialize()
        .then((_) async {
          if (!mounted) return;
          // Browsers block autoplay with sound, so start muted on web.
          if (kIsWeb) await _controller.setVolume(0);
          await _controller.setLooping(true);
          await _controller.play();
          if (mounted) setState(() {});
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poster = widget.posterUrl == null
        ? const ColoredBox(color: Colors.black)
        : CachedNetworkImage(
            imageUrl: widget.posterUrl!,
            fit: widget.fit,
            errorWidget: (_, _, _) => const ColoredBox(color: Colors.black),
          );

    if (_failed) {
      return Stack(
        fit: StackFit.expand,
        children: [
          poster,
          Center(
            child: TextButton.icon(
              onPressed: () {
                _controller.dispose();
                setState(_init);
              },
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Video unavailable. Tap to retry',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    final ready = _controller.value.isInitialized;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!ready) return;
        setState(() {
          _controller.value.isPlaying
              ? _controller.pause()
              : _controller.play();
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          poster,
          if (ready)
            FittedBox(
              fit: widget.fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (ready && !_controller.value.isPlaying)
            const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                size: 80,
                color: Colors.white70,
              ),
            ),
        ],
      ),
    );
  }
}
