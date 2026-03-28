// ignore_for_file: unused_local_variable

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// This utility function opens a PDF file from a given URL and saves it to the device's download directory.
Future<void> openPDF({
  required String fileUrl,
  required String fileName,
}) async {
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
      OpenFilex.open(savePath);
      return;
    }
    await dio.download(
      fileUrl,
      savePath,
    );
  } finally {}
}

// This function opens a file from a given URL and handles the download and opening process.
Future openFile({required String url, String? fileName}) async {
  File? file = await downlaodFile(url, fileName!);
}

// This function downloads a file from a given URL and returns the file object.
Future<File?> downlaodFile(String url, String name) async {
  try {
    final appStorage = await getApplicationDocumentsDirectory();
    File file = File("${appStorage.path}/$name");
    final response = await Dio().get(url,
        options: Options(
            responseType: ResponseType.bytes,
            followRedirects: false,
            receiveTimeout: const Duration(seconds: 0)));
    final raf = file.openSync(mode: FileMode.write);
    raf.writeFromSync(response.data);
    await raf.close();
    return file;
  } catch (e) {
    return null;
  }
}

// This function downloads a file from a given URL and opens it, with progress tracking and error handling.
Future downLoadingFile({required String url, String? fileName}) async {
  await downloadFile(url, fileName!);
}

// This function downloads a file from a given URL and saves it to the device's download directory.
Future<void> downloadFile(String url, String name) async {
  final status = await _requestPermission();

  if (status.isGranted) {
    try {
      final downloadsDir = await _getDownloadDirectory();
      if (downloadsDir == null) {
        showToast("Could not find downloads directory.", isError: true);
        return;
      }
      final savePath = '${downloadsDir.path}/$name';
      final file = File(savePath);

      await Dio().download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {}
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
        ),
      );

      showToast("Download Complete! File saved at: $savePath");
    } catch (e) {
      showToast("An error occurred during download.", isError: true);
    }
  } else {
    showToast("Storage permission denied.", isError: true);
  }
}

// This function requests the necessary permissions for file access based on the platform.
Future<PermissionStatus> _requestPermission() async {
  if (Platform.isAndroid) {
    if (await Permission.manageExternalStorage.isGranted) {
      return PermissionStatus.granted;
    }

    if (Platform.version.contains('API 33') ||
        Platform.version.contains('API 34') ||
        Platform.version.contains('API 35')) {
      return await Permission.manageExternalStorage.request();
    } else {
      return await Permission.storage.request();
    }
  }

  return PermissionStatus.granted;
}

// This function retrieves the download directory based on the platform.
Future<Directory?> _getDownloadDirectory() async {
  if (Platform.isAndroid) {
    final dir = await getExternalStorageDirectory();
    return Directory('${dir!.path.split('Android')[0]}Download');
  } else if (Platform.isIOS) {
    return await getApplicationDocumentsDirectory();
  }

  return null;
}

void showToast(String message, {bool isError = false}) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    backgroundColor: isError ? Colors.redAccent : Colors.green,
    textColor: Colors.white,
    fontSize: 16.0,
  );
}
