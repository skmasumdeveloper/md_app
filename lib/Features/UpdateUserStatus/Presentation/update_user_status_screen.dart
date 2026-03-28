import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:cu_app/Features/Login/Controller/login_controller.dart';
import 'package:cu_app/Features/MyProfile/Presentation/my_profile_screen.dart';
import 'package:cu_app/Utils/navigator.dart';
import 'package:cu_app/Widgets/custom_app_bar.dart';
import 'package:cu_app/Widgets/rounded_corner_container.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../Widgets/full_button.dart';

// This screen allows users to update their status, such as "Active", "Inactive".
class UpdateUserStatusScreen extends StatefulWidget {
  const UpdateUserStatusScreen({super.key});

  @override
  State<UpdateUserStatusScreen> createState() => _UpdateUserStatusScreenState();
}

class _UpdateUserStatusScreenState extends State<UpdateUserStatusScreen> {
  final loginController = Get.put(LoginController());

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: const CustomAppBar(
        title: 'Enter New Status',
      ),
      body: RoundedCornerContainer(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Status',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium!
                          .copyWith(color: colors.headerBg),
                    ),
                    const SizedBox(
                      height: AppSizes.kDefaultPadding,
                    ),
                    Obx(() {
                      if (loginController.statusController.value.isEmpty) {
                        loginController.statusController.value = "Active";
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.borderColor),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: loginController.statusController.value,
                            dropdownColor: colors.cardBg,
                            items: ["Active", "Inactive", "Deleted"]
                                .map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                loginController.statusController.value =
                                    newValue;
                              }
                            },
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.kDefaultPadding * 2),
                child: Column(
                  children: [
                    Obx(() => loginController.isUserUpdateLoading.value
                        ? const Center(
                            child: CircularProgressIndicator.adaptive(),
                          )
                        : FullButton(
                            label: 'Ok'.toUpperCase(),
                            onPressed: () async {
                              await loginController.updateUserDetails(
                                  status:
                                      loginController.statusController.value);
                              backFromPrevious(context: context);
                            })),
                    Container(
                      alignment: Alignment.center,
                      child: TextButton(
                          style: TextButton.styleFrom(
                              maximumSize:
                                  const Size.fromHeight(AppSizes.buttonHeight)),
                          onPressed: () {
                            context.pop(const MyProfileScreen());
                          },
                          child: Text(
                            'Cancel',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          )),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
