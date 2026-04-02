import 'package:cu_app/Commons/app_colors.dart';
import 'package:cu_app/Commons/app_images.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:cu_app/Features/Forget_password/Controller/forget_password_controller.dart';
import 'package:cu_app/Features/Login/Controller/login_controller.dart';
import 'package:cu_app/Widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKeyEmail = GlobalKey<FormState>();
  final GlobalKey<FormState> _formKeyPass = GlobalKey<FormState>();
  final forgetpasswordController = Get.put(ForgetPasswordControler());
  final loginController = Get.put(LoginController());

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 7,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(AppImages.welcomeBg),
                  fit: BoxFit.cover,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      AppImages.appLogo,
                      height: 160,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connecting Your Team',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    24,
                    20,
                    24 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.loginBg,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadowColor,
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Form(
                          key: _formKeyEmail,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: CustomTextField(
                            controller: loginController.emailController.value,
                            hintText: 'Username',
                            prefixIcon:
                                Icon(Icons.person, color: colors.textTertiary),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (!GetUtils.isEmail(value!)) {
                                return 'Invalid Email Address';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 15),
                        Form(
                          key: _formKeyPass,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Obx(() => CustomTextField(
                                controller:
                                    loginController.passwordController.value,
                                hintText: 'Password',
                                prefixIcon: Icon(Icons.lock,
                                    color: colors.textTertiary),
                                obscureText:
                                    loginController.isPasswordVisible.value,
                                keyboardType: TextInputType.visiblePassword,
                                suffixIcon: InkWell(
                                    onTap: () {
                                      loginController.toggleIsPasswordVisible();
                                    },
                                    child: Icon(
                                      loginController.isPasswordVisible.value ==
                                              false
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: colors.borderColor,
                                    )),
                                validator: (value) {
                                  if (value!.isEmpty) {
                                    return 'Invalid Password';
                                  }
                                  return null;
                                },
                              )),
                        ),
                        const SizedBox(height: 25),
                        Obx(
                          () => loginController.isLoginLaoding.value
                              ? const Center(
                                  child: CircularProgressIndicator.adaptive(),
                                )
                              : Container(
                                  width: double.infinity,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.secondary
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.secondary
                                            .withOpacity(0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                    onPressed: () async {
                                      if (_formKeyEmail.currentState!
                                              .validate() &&
                                          _formKeyPass.currentState!
                                              .validate()) {
                                        await loginController.userLogin(
                                            context: context);
                                      }
                                    },
                                    child: const Text(
                                      'LOGIN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                        // SizedBox(
                        //   width: double.infinity,
                        //   height: 46,
                        //   child: OutlinedButton(
                        //     style: OutlinedButton.styleFrom(
                        //       side: const BorderSide(color: AppColors.primary),
                        //       shape: RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.circular(5),
                        //       ),
                        //     ),
                        //     onPressed: () {
                        //       Get.to(() => GuestMeetingPinScreen());
                        //     },
                        //     child: const Text(
                        //       'JOIN GUEST MEETING',
                        //       style: TextStyle(
                        //         color: AppColors.primary,
                        //         fontSize: 16,
                        //         fontWeight: FontWeight.w600,
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        // const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: () {
                                if (_formKeyEmail.currentState!.validate()) {
                                  forgetpasswordController.sentOtp(context);
                                }
                              },
                              child: Obx(
                                () => forgetpasswordController
                                            .isForgetPasswordLoading.value ==
                                        true
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator.adaptive(
                                                strokeWidth: 2),
                                      )
                                    : Text(
                                        "Forgot Password?",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium!
                                            .copyWith(
                                              color: colors.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
