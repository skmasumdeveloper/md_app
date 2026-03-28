import 'dart:io';

import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../Commons/app_colors.dart';
import '../Commons/app_sizes.dart';
import '../Features/GroupInfo/Model/image_picker_model.dart';
import '../Utils/custom_bottom_modal_sheet.dart';

// This widget provides a custom image picker that allows users to select an image from the gallery or capture one using the camera.
class CustomImagePicker extends StatefulWidget {
  //final UserDetailsStateLoaded state;
  final String imageUrl;

  const CustomImagePicker({super.key, required this.imageUrl});

  @override
  State<CustomImagePicker> createState() => _CustomImagePickerState();
}

class _CustomImagePickerState extends State<CustomImagePicker> {
  File? image;

  Future pickImageFromGallery() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final imageTemp = File(image.path);
      setState(() => this.image = imageTemp);
    } on PlatformException catch (e) {
      debugPrint("Failed to pick image: $e");
    }
  }

  Future pickImageFromCamera() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.camera);
      if (image == null) return;
      final imageTemp = File(image.path);
      setState(() => this.image = imageTemp);
    } on PlatformException catch (e) {
      debugPrint("Failed to pick image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
          bottom: AppSizes.dimen30,
          top: AppSizes.dimen16,
          left: AppSizes.dimen16,
          right: AppSizes.dimen16),
      child: Center(
        child: Stack(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.3,
              child: CircleAvatar(
                  maxRadius: 60,
                  backgroundColor: AppColors.lightGrey,
                  backgroundImage: (image != null)
                      ? Image.file(File(image!.path)).image
                      : NetworkImage(widget.imageUrl)),
            ),
            Positioned(
                left: 77,
                bottom: 06,
                child: InkWell(
                  onTap: () {
                    showCustomBottomSheet(
                        context,
                        '',
                        ListView.builder(
                            shrinkWrap: true,
                            itemCount: chatPickerList.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                onTap: () {
                                  switch (index) {
                                    case 0:
                                      pickImageFromGallery();
                                      break;
                                    case 1:
                                      pickImageFromCamera();
                                      break;
                                  }
                                  Navigator.pop(context);
                                },
                                leading: chatPickerList[index].icon,
                                title: Text(chatPickerList[index].title!,
                                    style:
                                        Theme.of(context).textTheme.bodyLarge),
                              );
                            }));
                  },
                  child: const CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.shimmer,
                      child: Icon(
                        EvaIcons.camera,
                        color: AppColors.primary,
                      )),
                ))
          ],
        ),
      ),
    );
  }
}
