import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../Widgets/toast_widget.dart';

// This function downloads a file from a given URL and opens it, with progress tracking and error handling.
Future<void> downloadAndOpenFile(
    String url,
    String fileName,
    void Function(int received, int total) onProgress,
    bool isDownloadOnly) async {
  final Dio dio = Dio();

  try {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    }

    if (fileName.contains(RegExp(r'[^a-zA-Z0-9._-\s]'))) {
      fileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '-');
    }

    final savePath = '${directory!.path}/$fileName';
    final file = File(savePath);

    if (await file.exists()) {
      TostWidget().successToast(message: 'File already exists: $fileName');

      isDownloadOnly ? null : OpenFilex.open(savePath);
      return;
    }

    await dio.download(
      url,
      savePath,
      onReceiveProgress: onProgress,
    );
    TostWidget().successToast(message: 'File downloaded to: $fileName');
    isDownloadOnly ? null : OpenFilex.open(savePath);
  } finally {}
}
