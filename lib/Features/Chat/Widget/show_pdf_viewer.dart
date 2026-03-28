import 'package:flutter/material.dart';
import 'package:flutter_cached_pdfview/flutter_cached_pdfview.dart';

import '../../../Widgets/custom_app_bar.dart';

// This widget displays a PDF document in a full-screen view using the flutter_cached_pdfview package.
class ShowPdf extends StatelessWidget {
  final String pdfPath;

  const ShowPdf({
    required this.pdfPath,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: const CustomAppBar(
          title: '',
        ),
        body: const PDF().cachedFromUrl(
          pdfPath,
          maxAgeCacheObject: const Duration(days: 30),
          //duration of cache
          placeholder: (progress) => Center(child: Text('$progress %')),
          errorWidget: (error) => const Center(child: Text('Loading...')),
        ));
  }
}
