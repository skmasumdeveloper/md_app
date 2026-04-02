import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/app_images.dart';
import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Features/Login/Controller/login_controller.dart';
import 'package:cu_app/Features/MyProfile/Presentation/my_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../Commons/app_theme_colors.dart';
import '../../../Widgets/rounded_corner_container.dart';
import '../../AddMenu/add_menu_screen.dart';
import '../../Group_Call_old/controller/group_call.dart';
import '../Presentation/home_screen.dart';

// This widget builds the mobile view for the home screen, including the app bar and chat list.
class BuildMobileView extends StatefulWidget {
  final bool isDeleteNavigation;
  final bool isFromChat;
  const BuildMobileView(
      {super.key, required this.isDeleteNavigation, this.isFromChat = false});

  @override
  State<BuildMobileView> createState() => _BuildMobileViewState();
}

class _BuildMobileViewState extends State<BuildMobileView> {
  final loginController = Get.put(LoginController());
  final userController = Get.put(LoginController());
  final callController = Get.put(GroupcallController());
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      userController.getUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
          child: Padding(
            padding: const EdgeInsets.only(top: 30),
            child: SizedBox(
              width: 100,
              height: 100,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(AppImages.appLogoWhite),
                    fit: BoxFit.contain,
                    opacity: 0.2,
                    filterQuality: FilterQuality.high,
                    alignment: Alignment.center,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${loginController.userModel.value.name ?? ""} (${loginController.userModel.value.userType ?? ""})',
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: AppColors.white, fontWeight: FontWeight.w600),
                ),
                Text(
                  loginController.statusController.value.isEmpty
                      ? "Available"
                      : loginController.statusController.value,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(color: AppColors.white.withOpacity(0.8)),
                ),
              ],
            )),
        actions: [
          Obx(() => userController.userModel.value.userType != null &&
                  userController.userModel.value.userType!.isNotEmpty
              ? userController.userModel.value.userType!
                          .contains(AdminCheck.admin) ||
                      userController.userModel.value.userType!
                          .contains(AdminCheck.superAdmin)
                  ? IconButton(
                      icon: const Icon(
                        Icons.add,
                        color: AppColors.white,
                        size: 30,
                      ),
                      onPressed: () {
                        context.push(const AddMenuScreen());
                      },
                    )
                  : const SizedBox.shrink()
              : const SizedBox.shrink()),
          const SizedBox(width: 10),
        ],
        leading: Padding(
          padding: const EdgeInsets.all(6.0),
          child: GestureDetector(
            onTap: () => context.push(const MyProfileScreen()),
            child: Obx(() => ClipOval(
                  child: CachedNetworkImage(
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    imageUrl: loginController.userModel.value.image ?? "",
                    placeholder: (context, url) => CircleAvatar(
                      radius: 20,
                      backgroundColor: colors.surfaceBg,
                    ),
                    errorWidget: (context, url, error) => CircleAvatar(
                      radius: 20,
                      backgroundColor: colors.surfaceBg,
                      child: Text(
                        loginController.userModel.value.name
                                ?.substring(0, 1)
                                .toUpperCase() ??
                            "",
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary),
                      ),
                    ),
                  ),
                )),
          ),
        ),
      ),
      body: Obx(() => RoundedCornerContainer(
            child: BuildChatList(
              isDeleteNavigation: widget.isDeleteNavigation,
              isAdmin: userController.userModel.value.userType != null &&
                      userController.userModel.value.userType!.isNotEmpty
                  ? userController.userModel.value.userType!
                              .contains(AdminCheck.admin) ||
                          userController.userModel.value.userType!
                              .contains(AdminCheck.superAdmin)
                      ? true
                      : false
                  : false,
              isFromChat: widget.isFromChat,
            ),
          )),
    );
  }
}
