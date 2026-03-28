import 'package:cu_app/Features/Forget_password/Controller/forget_password_controller.dart';
import 'package:cu_app/Widgets/custom_text_field.dart';
import 'package:cu_app/Widgets/full_button.dart';
import 'package:cu_app/Widgets/rounded_corner_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Commons/app_icons.dart';
import '../../../Commons/app_sizes.dart';
import '../../../Commons/app_strings.dart';
import '../../../Commons/app_colors.dart';
import '../../../Commons/app_theme_colors.dart';

// This screen allows users to change their password after verifying their identity.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.userEmail});

  final String? userEmail;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final forgotPasswordController = Get.put(ForgetPasswordControler());
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
        ),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(
                Icons.close,
                size: 25,
                color: AppColors.white,
              ))
        ],
        title: Row(
          children: [
            Image.asset(
              AppIcons.appLogo,
              width: 24,
              height: 24,
              fit: BoxFit.cover,
            ),
            const SizedBox(
              width: AppSizes.kDefaultPadding / 2,
            ),
            Text(
              AppStrings.appName,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(color: AppColors.white),
            ),
          ],
        ),
      ),
      body: RoundedCornerContainer(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.kDefaultPadding * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        height: AppSizes.kDefaultPadding,
                      ),
                      Text("Change your password",
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium!
                              .copyWith(
                                color: colors.headerBg,
                                fontWeight: FontWeight.w400,
                              )),
                      const SizedBox(
                        height: AppSizes.kDefaultPadding * 2,
                      ),
                      Obx(() => CustomTextField(
                            suffixIcon: InkWell(
                                onTap: () {
                                  forgotPasswordController.showPass(
                                      !forgotPasswordController
                                          .showPassword.value);
                                },
                                child:
                                    forgotPasswordController.showPassword.value
                                        ? const Icon(Icons.visibility_off)
                                        : const Icon(Icons.visibility)),
                            obscureText:
                                forgotPasswordController.showPassword.value,
                            controller: forgotPasswordController
                                .oldPasswordController.value,
                            labelText: 'Enter old password',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'required';
                              }
                              return null;
                            },
                          )),
                      const SizedBox(
                        height: AppSizes.kDefaultPadding * 2,
                      ),
                      Obx(() => CustomTextField(
                            suffixIcon: InkWell(
                                onTap: () {
                                  forgotPasswordController.showCnf(
                                      !forgotPasswordController
                                          .showCnfPass.value);
                                },
                                child:
                                    forgotPasswordController.showCnfPass.value
                                        ? Icon(
                                            Icons.visibility_off,
                                            color: colors.borderColor,
                                          )
                                        : Icon(
                                            Icons.visibility,
                                            color: colors.borderColor,
                                          )),
                            obscureText:
                                forgotPasswordController.showCnfPass.value,
                            controller: forgotPasswordController
                                .newPasswordControllerChange.value,
                            labelText: 'Enter new password',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'required';
                              }
                              return null;
                            },
                          )),
                    ],
                  ),
                ),
              ),
              Obx(
                () => forgotPasswordController.isChangingPassword.value
                    ? const Center(
                        child: CircularProgressIndicator.adaptive(),
                      )
                    : FullButton(
                        label: 'Save',
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            forgotPasswordController.changePassword(context);
                          }
                        }),
              ),
              const SizedBox(
                height: AppSizes.kDefaultPadding,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
