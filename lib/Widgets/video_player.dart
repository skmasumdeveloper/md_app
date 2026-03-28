import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// This widget displays a video message using the VideoPlayerController, allowing users to play videos from a given URL.
class VideoMessage extends StatefulWidget {
  final String videoUrl;
  const VideoMessage({super.key, required this.videoUrl});

  @override
  // ignore: library_private_types_in_public_api
  _VideoMessageState createState() => _VideoMessageState();
}

class _VideoMessageState extends State<VideoMessage> {
  late VideoPlayerController _videoPlayerController;

  @override
  void initState() {
    super.initState();
    // ignore: deprecated_member_use
    _videoPlayerController = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController.play();
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_ios)),
      ),
      body: Center(
        child: _videoPlayerController.value.isInitialized
            ? AspectRatio(
                aspectRatio: _videoPlayerController.value.aspectRatio,
                child: VideoPlayer(_videoPlayerController))
            : const Scaffold(
                body: Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    super.dispose();
  }
}
