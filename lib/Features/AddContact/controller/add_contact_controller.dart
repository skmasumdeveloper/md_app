// import 'dart:developer';
import 'package:cu_app/Features/AddContact/Repo/add_contact_repo.dart';
import 'package:cu_app/Features/AddContact/model/add_contact_model.dart';
import 'package:cu_app/Utils/navigator.dart';
import 'package:cu_app/Widgets/toast_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Commons/app_strings.dart';
import '../../AllMembers/controller/all_members_controller.dart';
import '../../Login/Controller/login_controller.dart';

// This controller handles the logic for adding a new contact in the application.
class AddContactController extends GetxController {
  final AddContactRepo _addContactRepo = AddContactRepo();
  final userController = Get.put(LoginController());

  // Form controllers
  var nameController = TextEditingController().obs;
  var emailController = TextEditingController().obs;
  var passwordController = TextEditingController().obs;

  // Loading states
  final RxBool isLoading = false.obs;
  final RxBool isPasswordVisible = true.obs;

  // Selected user type
  final RxString selectedUserType = 'user'.obs;

  // User type options
  final List<String> userTypes = ['user'];

  final RxBool isShowUserTypeDropDown = true.obs;

  @override
  void onInit() {
    super.onInit();
    // Initialize user types if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getUserTypes();
    });

    // Default to first user type
  }

// This method retrieves the user types based on the user's role.
  void getUserTypes() {
    if (userController.userModel.value.userType != null &&
        userController.userModel.value.userType!.isNotEmpty) {
      if (userController.userModel.value.userType!
          .contains(AdminCheck.superAdmin)) {
        userTypes.assignAll(['user', 'admin']);
        isShowUserTypeDropDown.value = true;
      } else if (userController.userModel.value.userType!
          .contains(AdminCheck.admin)) {
        userTypes.assignAll(['user']);
        isShowUserTypeDropDown.value = false;
      } else {
        userTypes.assignAll(['user']);
        isShowUserTypeDropDown.value = false;
      }
    } else {
      userTypes.assignAll(['user']);
      isShowUserTypeDropDown.value = false;
    }
    selectedUserType.value = userTypes.first;
  }

// This method toggles the visibility of the password field.
  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

// This method sets the selected user type.
  void setUserType(String userType) {
    selectedUserType.value = userType;
  }

  // Check if user exists and handle the flow
  Future<void> handleUserCreation(BuildContext context) async {
    try {
      isLoading.value = true;

      // First check if user exists
      final checkResponse = await _addContactRepo.checkUserExists(
        emailController.value.text.trim(),
      );

      if (checkResponse.data != null) {
        // User exists, show popup
        isLoading.value = false;
        _showUserExistsDialog(context, checkResponse.data!);
      } else {
        // User doesn't exist, create directly
        await _createUserDirectly(context).then((v) {
          if (v) {
            _clearForm();
            backFromPrevious(context: context);
            TostWidget().successToast(
              title: "Success",
              message: "User added successfully",
            );
          }
        });
      }
    } catch (e) {
      isLoading.value = false;
      TostWidget().errorToast(
        title: "Error",
        message: "An error occurred while checking user",
      );
    }
  }

// This method shows a dialog if the user already exists.
  void _showUserExistsDialog(
      BuildContext context, AddContactModel existingUser) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'User Already Exists!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'User with email "${emailController.value.text.trim()}" already exists in CU app. Do you want to add this user in your contact list?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                isLoading.value = false;
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _createUserDirectly(context).then((v) {
                  if (v == true) {
                    _clearForm();
                    backFromPrevious(context: context);
                    TostWidget().successToast(
                      title: "Success",
                      message: "User added successfully",
                    );
                  }
                });
                backFromPrevious(context: context);
              },
              child: const Text('Add in Contact List'),
            ),
          ],
        );
      },
    );
  }

// This method creates a new user directly.
  Future<bool> _createUserDirectly(BuildContext context) async {
    try {
      isLoading.value = true;

      final response = await _addContactRepo.createUser(
        name: nameController.value.text.trim(),
        email: emailController.value.text.trim(),
        password: passwordController.value.text.trim(),
        userType: selectedUserType.value,
      );

      if (response.data?.success == true) {
        final allMembersController = Get.put(AllMembersController());
        allMembersController.refreshMembers();
        return true;
      } else {
        TostWidget().errorToast(
          title: "Error",
          message: response.errorMessage ?? "Failed to add user",
        );
        return false;
      }
    } finally {
      isLoading.value = false;
    }
  }

  // Remove the old createUser method and replace with handleUserCreation
  Future<void> createUser(BuildContext context) async {
    await handleUserCreation(context);
  }

// This method used to clear the form fields after successful user creation.
  void _clearForm() {
    nameController.value.clear();
    emailController.value.clear();
    passwordController.value.clear();
    selectedUserType.value = 'user';
  }

  @override
  void onClose() {
    nameController.value.dispose();
    emailController.value.dispose();
    passwordController.value.dispose();
    super.onClose();
  }
}
