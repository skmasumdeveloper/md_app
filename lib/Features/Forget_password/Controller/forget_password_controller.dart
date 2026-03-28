import 'package:cu_app/Api/api_provider.dart';
import 'package:cu_app/Commons/route.dart';
import 'package:cu_app/Features/Forget_password/presentation/forget_passrow.dart';
import 'package:cu_app/Features/Forget_password/presentation/reset_password.dart';
import 'package:cu_app/Features/Login/Controller/login_controller.dart';
import 'package:cu_app/Features/Login/Presentation/login_screen.dart';
import 'package:cu_app/Utils/custom_snack_bar.dart';
import 'package:cu_app/Utils/navigator.dart';
import 'package:cu_app/Widgets/toast_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// This controller handles the logic for the forget password feature, including sending OTP, verifying it, and resetting the password.
class ForgetPasswordControler extends GetxController {
  var forgetemailController = TextEditingController().obs;
  var otpController = TextEditingController().obs;
  var password = TextEditingController().obs;
  var cnfPassword = TextEditingController().obs;
  ApiProvider apiProvider = ApiProvider();
  RxBool isForgetPasswordLoading = false.obs;
  RxBool verifyingOtp = false.obs;
  RxBool isPasswordReseting = false.obs;
  RxString slug = "".obs;
  RxBool isPasswordVsible = true.obs;

  var oldPasswordController = TextEditingController().obs;
  var newPasswordControllerChange = TextEditingController().obs;
  RxBool isChangingPassword = false.obs;
  RxBool showPassword = true.obs;
  RxBool showCnfPass = true.obs;

  final loginController = Get.put(LoginController());

  // This method shows or hides the password field.
  void showPass(bool v) {
    showPassword.value = v;
  }

// This method shows or hides the confirm password field.
  void showCnf(bool v) {
    showCnfPass.value = v;
  }

// This method sends an OTP to the user's email for password recovery.
  void sentOtp(BuildContext context) async {
    isForgetPasswordLoading(true);
    forgetemailController.value = loginController.emailController.value;
    var res = await apiProvider
        .forgetPassword(forgetemailController.value.text.toLowerCase());
    if (res['success'] == true) {
      customSnackBar(context, res['data']['message'].toString());
      isForgetPasswordLoading(false);
      context.push(ForgetPasswordScreen());
    } else {
      customSnackBar(context, res['message'].toString());
      isForgetPasswordLoading(false);
    }
  }

// This method verifies the OTP entered by the user.
  void verifyOtp(BuildContext context) async {
    verifyingOtp(true);
    var res = await apiProvider.verifyOtp(
        email: forgetemailController.value.text.toLowerCase(),
        otp: otpController.value.text);
    if (res['success'] == true) {
      slug.value = res['data']['slug'];
      customSnackBar(context, res['message'].toString());
      context.push(ResetPasswordPasswordScreen());
      otpController.value.text = "";
      verifyingOtp(false);
      password.value.text = "";
      cnfPassword.value.text = "";
    } else {
      customSnackBar(context, res['error'].toString());
      verifyingOtp(false);
      password.value.text = "";
      cnfPassword.value.text = "";
    }
  }

// This method resets the user's password using the provided email, new password, and confirmation password.
  void resetPassword(BuildContext context) async {
    isPasswordReseting(true);
    var res = await apiProvider.resetpassword(
        slug: slug.value,
        email: forgetemailController.value.text.toLowerCase(),
        password: password.value.text,
        cnfPassword: cnfPassword.value.text);
    if (res['success'] == true) {
      customSnackBar(context, res['message'].toString());
      context.pushAndRemoveUntil(const LoginScreen());
      otpController.value.text = "";
    } else {
      customSnackBar(context, res['error'].toString());
    }

    isPasswordReseting(false);
  }

// This method changes the user's password using the old and new passwords.
  changePassword(BuildContext context) async {
    try {
      Map<String, dynamic> reqModel = {
        "oldPassword": oldPasswordController.value.text,
        "password": newPasswordControllerChange.value.text
      };
      isChangingPassword(true);
      var res = await apiProvider.changePassword(reqModel: reqModel);
      if (res['success'] == true) {
        TostWidget()
            .successToast(title: "Success", message: res['message'].toString());
        backFromPrevious(context: context);
        isChangingPassword(false);
      } else {
        TostWidget()
            .errorToast(title: "Error!", message: res['error'].toString());
        isChangingPassword(false);
      }
    } catch (e) {
      isChangingPassword(false);
    }
  }
}
