import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../../Widgets/custom_app_bar.dart';

// This widget displays an image in full screen using PhotoView.
class ShowImage extends StatelessWidget {
  final String imageUrl;

  const ShowImage({
    required this.imageUrl,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: '',
      ),
      body: PhotoView(imageProvider: NetworkImage(imageUrl)),
    );
  }
}
