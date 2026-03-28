import 'dart:io';
import 'package:cu_app/Features/Home/Presentation/home_screen.dart';
import 'package:cu_app/Features/Login/Repo/respository.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cu_app/Features/Meetings/Repository/meetings_repo.dart';
import 'package:cu_app/Features/Meetings/Presentation/meeting_details_screen.dart';
import '../../../Utils/app_preference.dart';
import '../../../Widgets/toast_widget.dart';
import '../../Group_Call/controller/group_call.dart';
import '../../Home/Controller/socket_controller.dart';
import '../Model/user_profle_model.dart';

// This controller handles user login, profile management, and logout functionality.
class LoginController extends GetxController {
  final _authRepo = AuthRepo();
  var emailController = TextEditingController().obs;
  var passwordController = TextEditingController().obs;
  final localStorage = LocalStorage();
  RxBool isPasswordVisible = true.obs;
  RxString statusController = ''.obs;
  toggleIsPasswordVisible() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  RxBool isLoginLaoding = false.obs;
  // This method handles user login by validating the input and calling the repository to perform the login operation.
  userLogin({required BuildContext context}) async {
    try {
// Save fcm token
      final newfcmToken = await FirebaseMessaging.instance.getToken();
      AppPreference().saveFirebaseToken(token: newfcmToken ?? "");

      // save apple device token
      final pushKitToken =
          await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      AppPreference().saveApplePushToken(token: pushKitToken ?? "");

      String? fcmToken = await AppPreference().getFirebaseToken();
      String? applePushToken = await AppPreference().getApplePushToken();

      isLoginLaoding(true);
      Map<String, dynamic> reqModel = {
        "id": emailController.value.text.toString().toLowerCase(),
        "password": passwordController.value.text.toString(),
        "firebaseToken": fcmToken,
        "applePushToken": applePushToken,
      };
      var res = await _authRepo.userLogin(reqModel: reqModel);

      if (res.data!.success == true) {
        getUserProfile();

        TostWidget()
            .successToast(title: "Login Success", message: res.data!.message);
        localStorage.setToken(token: res.data?.data?.token.toString());
        localStorage.setUserId(userId: res.data?.data?.user?.sId.toString());
        localStorage.setUserName(
            userName: res.data?.data?.user?.name.toString());

        // Initialize controllers in proper order
        // SocketController will auto-connect via onInit()
        Get.put(SocketController());
        Get.put(GroupcallController());

        isLoginLaoding(false);
        updateUserDetails(status: "");

        // If a pending deep link exists, navigate to the meeting details after login
        final pending = localStorage.getPendingDeepLink();
        if (pending != null &&
            (pending['groupId'] ?? '').toString().isNotEmpty) {
          final isAnyCallActive = await LocalStorage().getIsAnyCallActive();
          if (isAnyCallActive) {
            // if call is active, go to home and show message
            TostWidget().errorToast(
                title: 'Busy',
                message: 'A call is running. Cannot open meeting now.');
            await LocalStorage().clearPendingDeepLink();
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const HomeScreen(
                          isDeleteNavigation: false,
                        )));
          } else {
            final groupId = pending['groupId'].toString();
            await LocalStorage().clearPendingDeepLink();
            final repo = MeetingsRepo();
            final res = await repo.getMeetingGroupDetails(groupId: groupId);
            if (res.data != null) {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => MeetingDetailsScreen(
                            meeting: res.data!,
                          )));
            } else {
              // fallback to home
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const HomeScreen(
                            isDeleteNavigation: false,
                          )));
            }
          }
        } else {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const HomeScreen(
                        isDeleteNavigation: false,
                      )));
        }
      } else {
        TostWidget().errorToast(title: "Error", message: res.data?.error);
        isLoginLaoding(false);
      }
    } catch (e) {
      isLoginLaoding(false);
    }
  }

  RxBool isUserLaoding = false.obs;
  Rx<User> userModel = User().obs;
  // This method retrieves the user's profile information from the repository and updates the local user model.
  getUserProfile({bool isrefresh = true}) async {
    isrefresh ? isUserLaoding(true) : null;
    try {
      var res = await _authRepo.getUserProfile();
      if (res.data?.success == true) {
        userModel.value = res.data!.data!.user!;
        statusController.value = res.data!.data!.user!.accountStatus ?? "";

        isUserLaoding(false);
      } else {
        userModel.value = User();
        isUserLaoding(false);
      }
    } catch (e) {
      isUserLaoding(false);
    }
  }

  // Profile image picker method to select an image from the gallery or camera.
  Future<void> pickImage(
      {required ImageSource imageSource, required BuildContext context}) async {
    try {
      final selected =
          await ImagePicker().pickImage(imageQuality: 50, source: imageSource);
      if (selected != null) {
        File groupImages = File(selected.path);

        updateUserDetails(status: "", image: groupImages);
      } else {}
    } on Exception {}
  }

  RxBool isUserUpdateLoading = false.obs;
  // This method updates the user's profile details, including status and profile image.
  updateUserDetails({required String status, File? image}) async {
    try {
      isUserUpdateLoading(true);
      String? firebaseToken = await AppPreference().getFirebaseToken();
      String? applePushToken = await AppPreference().getApplePushToken();
      var res = await _authRepo.updateProfileDetails(
          status: status,
          groupImage: image,
          firebaseToken: firebaseToken,
          applePushToken: applePushToken);
      if (res.data!["success"] == true) {
        await getUserProfile();
        // getUserProfile();

        isUserUpdateLoading(false);
      } else {
        isUserUpdateLoading(false);
      }
    } catch (e) {
      isUserUpdateLoading(false);
    }
  }

  RxBool isLoading = false.obs;
  // This method logs out the user by clearing the local storage and calling the logout service.
  Future<bool> logout() async {
    String userId = LocalStorage().getUserId();
    Map<String, dynamic> reqModel = {"user_id": userId};
    try {
      isLoading(true);
      final res = await _authRepo.userLogout(reqModel: reqModel);
      if (res.errorMessage != null) {
        return false;
      } else if (res.data!['success'] == false) {
        return false;
      } else {
        await AppPreference().clearPreference();
        return true;
      }
    } finally {
      isLoading(false);
    }
  }
}
