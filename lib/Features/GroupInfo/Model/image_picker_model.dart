import 'package:cu_app/Commons/app_colors.dart';
import 'package:flutter/material.dart';

class ImagePickerList {
  final String? title;
  final Widget? icon;

  ImagePickerList(this.title, this.icon);
}

final List<ImagePickerList> chatPickerList = [
  ImagePickerList(
      "File",
      const Icon(
        Icons.file_copy,
        color: AppColors.primary,
      )),
  ImagePickerList(
      'Gallery',
      const Icon(
        Icons.image,
        color: AppColors.primary,
      )),
  ImagePickerList(
      'Camera',
      const Icon(
        Icons.camera_alt_rounded,
        color: AppColors.primary,
      )),
  ImagePickerList(
      "Video",
      const Icon(
        Icons.video_call,
        color: AppColors.primary,
      ))
];

final List<ImagePickerList> imagePickerList = [
  ImagePickerList(
      'Gallery',
      const Icon(
        Icons.image,
        color: AppColors.primary,
      )),
  ImagePickerList(
      'Camera',
      const Icon(
        Icons.camera_alt_rounded,
        color: AppColors.primary,
      ))
];
