import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SafeCachedImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget placeholder;
  final Widget errorWidget;

  const SafeCachedImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    required this.placeholder,
    required this.errorWidget,
  });

  bool _isValidUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isValidUrl(imageUrl)) {
      return errorWidget;
    }

    return CachedNetworkImage(
      width: width,
      height: height,
      fit: fit,
      imageUrl: imageUrl!,
      placeholder: (context, url) => placeholder,
      errorWidget: (context, url, error) => errorWidget,
    );
  }
}
