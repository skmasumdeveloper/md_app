import 'package:cu_app/Commons/app_colors.dart';
import 'package:cu_app/Commons/app_sizes.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:cu_app/Commons/route.dart';
import 'package:cu_app/Features/Forget_password/presentation/change_password_screen.dart';
import 'package:cu_app/Features/Home/Controller/socket_controller.dart';
import 'package:cu_app/Features/Login/Controller/login_controller.dart';
import 'package:cu_app/Features/Login/Presentation/login_screen.dart';
import 'package:cu_app/Features/UpdateUserStatus/Presentation/update_user_status_screen.dart';
import 'package:cu_app/Utils/navigator.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/Widgets/custom_app_bar.dart';
import 'package:cu_app/Widgets/custom_divider.dart';
import 'package:cu_app/Widgets/rounded_corner_container.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../Commons/app_images.dart';
import '../../../Utils/custom_bottom_modal_sheet.dart';
import '../../../Utils/safe_cached_image.dart';
import '../../../Widgets/custom_confirmation_dialog.dart';
import '../../../Widgets/image_popup.dart';
import '../../GroupInfo/Model/image_picker_model.dart';
import '../../Group_Call/controller/group_call.dart';
import '../../Navigation/Controller/navigation_controller.dart';

// This screen displays the user's profile information, including their name, email, and profile picture. It also provides options to change the password, update the status, and log out.
class MyProfileScreen extends StatefulWidget {
  final List<dynamic>? groupsList;

  const MyProfileScreen({super.key, this.groupsList});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final loginController = Get.put(LoginController());
  final socketController = Get.find<SocketController>();
  final groupcallController = Get.put(GroupcallController());
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((t) {
      loginController.getUserProfile();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    socketController.updateBuildContext(context);
    groupcallController.updateBuildContext(context);
    return Scaffold(
        appBar: const CustomAppBar(
          title: 'My Profile',
          actions: [],
        ),
        body: RoundedCornerContainer(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (loginController.userModel.value.image !=
                                      null) {
                                    Get.to(
                                        () => FullScreenImageViewer(
                                              imageUrl: loginController
                                                  .userModel.value.image
                                                  .toString(),
                                              lableText: loginController
                                                      .userModel.value.name ??
                                                  "",
                                            ),
                                        transition: Transition
                                            .circularReveal, // Optional: Customize the animation
                                        duration:
                                            const Duration(milliseconds: 700));
                                  }
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                      AppSizes.cardCornerRadius * 10),
                                  child: Obx(
                                    () => SafeCachedImage(
                                      imageUrl:
                                          loginController.userModel.value.image,
                                      width: 106,
                                      height: 106,
                                      placeholder: CircleAvatar(
                                          radius: 66,
                                          backgroundColor: colors.surfaceBg),
                                      errorWidget: CircleAvatar(
                                        radius: 66,
                                        backgroundColor: colors.surfaceBg,
                                        child: Text(loginController
                                            .userModel.value.name
                                            .toString()[0]
                                            .toUpperCase()),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      showCustomBottomSheet(
                                          context,
                                          '',
                                          SizedBox(
                                            height: 150,
                                            child: ListView.builder(
                                                shrinkWrap: true,
                                                padding: const EdgeInsets.all(
                                                    AppSizes.kDefaultPadding),
                                                itemCount:
                                                    imagePickerList.length,
                                                scrollDirection:
                                                    Axis.horizontal,
                                                itemBuilder: (context, index) {
                                                  return GestureDetector(
                                                    onTap: () {
                                                      switch (index) {
                                                        case 0:
                                                          loginController.pickImage(
                                                              context: context,
                                                              imageSource:
                                                                  ImageSource
                                                                      .gallery);
                                                          break;
                                                        case 1:
                                                          loginController.pickImage(
                                                              context: context,
                                                              imageSource:
                                                                  ImageSource
                                                                      .camera);
                                                          break;
                                                      }

                                                      Navigator.pop(context);
                                                    },
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .only(
                                                          left: AppSizes
                                                                  .kDefaultPadding *
                                                              2),
                                                      child: Column(
                                                        children: [
                                                          Container(
                                                            width: 60,
                                                            height: 60,
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(
                                                                    AppSizes
                                                                        .kDefaultPadding),
                                                            decoration: BoxDecoration(
                                                                border: Border.all(
                                                                    width: 1,
                                                                    color: colors
                                                                        .borderColor),
                                                                color: colors
                                                                    .cardBg,
                                                                shape: BoxShape
                                                                    .circle),
                                                            child:
                                                                imagePickerList[
                                                                        index]
                                                                    .icon,
                                                          ),
                                                          const SizedBox(
                                                            height: AppSizes
                                                                    .kDefaultPadding /
                                                                2,
                                                          ),
                                                          Text(
                                                            '${imagePickerList[index].title}',
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodyMedium,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                }),
                                          ));
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      padding: const EdgeInsets.all(
                                          AppSizes.kDefaultPadding / 1.3),
                                      decoration: BoxDecoration(
                                          border: Border.all(
                                              width: 1,
                                              color: colors.borderColor),
                                          color: colors.cardBg,
                                          shape: BoxShape.circle),
                                      child: Image.asset(
                                        AppImages.cameraIcon,
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ))
                            ],
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSizes.kDefaultPadding),
                              child: Text(
                                'Add an optional profile picture',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const CustomDivider(
                  height: 30,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.kDefaultPadding),
                  child: Column(
                    children: [
                      ListTile(
                        dense: true,
                        horizontalTitleGap: 0,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          EvaIcons.person,
                          color: colors.iconSecondary,
                          size: 20,
                        ),
                        title: Text(
                          'Name',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        subtitle: Obx(() => Text(
                              loginController.userModel.value.name ?? "",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(fontWeight: FontWeight.w400),
                            )),
                      ),
                      const CustomDivider(),
                      ListTile(
                        dense: true,
                        horizontalTitleGap: 0,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          EvaIcons.email,
                          color: colors.iconSecondary,
                          size: 20,
                        ),
                        title: Text(
                          'Email',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        subtitle: Obx(() => Text(
                              loginController.userModel.value.email ?? "",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(fontWeight: FontWeight.w400),
                            )),
                      ),
                      const CustomDivider(),
                    ],
                  ),
                ),
                ListTile(
                  onTap: () {
                    context.push(const UpdateUserStatusScreen());
                  },
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.kDefaultPadding),
                  horizontalTitleGap: 0,
                  leading: Icon(
                    EvaIcons.info,
                    color: colors.iconSecondary,
                    size: 20,
                  ),
                  title: Text(
                    'Status',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Obx(() => Text(
                        loginController.userModel.value.accountStatus ?? "",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge!
                            .copyWith(fontWeight: FontWeight.w400),
                      )),
                  trailing: Icon(
                    EvaIcons.arrowIosForward,
                    color: colors.iconSecondary,
                    size: 24,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.kDefaultPadding),
                  child: CustomDivider(),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10, right: 10),
                  child: InkWell(
                    onTap: () {
                      doNavigator(
                          route: const ChangePasswordScreen(),
                          context: context);
                    },
                    child: ListTile(
                      dense: true,
                      horizontalTitleGap: 0,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        EvaIcons.lock,
                        color: colors.iconSecondary,
                        size: 20,
                      ),
                      title: Text(
                        'Change Password',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.kDefaultPadding),
                  child: CustomDivider(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.kDefaultPadding),
                  child: InkWell(
                    onTap: () {
                      showDialog(
                          context: context,
                          barrierDismissible: true,
                          builder: (BuildContext dialogContext) {
                            return Obx(() => ConfirmationDialog(
                                title: 'Logout?',
                                body: 'Are you sure you want to logout?',
                                positiveButtonLabel:
                                    loginController.isLoading.value
                                        ? "Loading..."
                                        : 'Logout',
                                negativeButtonLabel: 'Cancel',
                                onPressedPositiveButton: () async {
                                  final isLoggedOut =
                                      await loginController.logout();
                                  if (isLoggedOut == true) {
                                    loginController.emailController.value
                                        .clear();
                                    loginController.passwordController.value
                                        .clear();
                                    loginController.isPasswordVisible(true);

                                    final socketController =
                                        Get.isRegistered<SocketController>()
                                            ? Get.find<SocketController>()
                                            : null;

                                    if (socketController != null) {
                                      try {
                                        socketController.socket
                                            ?.clearListeners();
                                        socketController.socket?.disconnect();
                                        socketController.socket?.dispose();
                                        socketController.socket?.destroy();
                                        socketController.socket?.io.close();
                                        socketController.socket = null;
                                      } catch (e) {}
                                      Get.delete<SocketController>(force: true);
                                    }
                                    LocalStorage().deleteAllLocalData();
                                    Get.delete<NavigationController>();
                                    Get.delete<GroupcallController>();
                                    Get.deleteAll(force: true);
                                    context.pushAndRemoveUntil(
                                        const LoginScreen());
                                  }
                                }));
                          });
                    },
                    child: ListTile(
                      dense: true,
                      horizontalTitleGap: 0,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        EvaIcons.logOutOutline,
                        color: AppColors.red,
                        size: 20,
                      ),
                      title: Text(
                        'Logout',
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              color: AppColors.red,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
