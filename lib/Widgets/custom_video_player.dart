import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../Commons/commons.dart';

// This widget provides a custom video player that can play video files with controls for playback.
class CustomVideoPlayer extends StatefulWidget {
  final File file;

  const CustomVideoPlayer({Key? key, required this.file}) : super(key: key);

  @override
  _CustomVideoPlayerState createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  late VideoPlayerController videoPlayerController;
  ChewieController? chewieController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPlayer();
    });
  }

  void _initPlayer() async {
    videoPlayerController = VideoPlayerController.file(widget.file);
    await videoPlayerController.initialize();
    chewieController = ChewieController(
        videoPlayerController: videoPlayerController,
        allowFullScreen: false,
        autoPlay: false,
        looping: false,
        allowPlaybackSpeedChanging: true,
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: AppColors.darkGrey,
          bufferedColor: AppColors.red,
        ),
        hideControlsTimer: const Duration(seconds: 3));
    setState(() {});
  }

  @override
  void dispose() {
    videoPlayerController.dispose();
    chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: chewieController != null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Chewie(
                controller: chewieController!,
              ),
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}
