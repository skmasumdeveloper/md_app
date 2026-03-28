import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

// This widget provides a full-screen image viewer that displays an image with a title, allowing users to zoom and pan the image.
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? lableText;

  const FullScreenImageViewer(
      {super.key, required this.imageUrl, this.lableText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          lableText ?? "",
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
        ),
      ),
      body: Center(
        child: PhotoView(
          imageProvider: CachedNetworkImageProvider(imageUrl),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
        ),
      ),
    );
  }
}
