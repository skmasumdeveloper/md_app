import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:cu_app/Features/EditMember/repo/edit_member_repo.dart';
import 'package:cu_app/Features/EditMember/model/edit_member_model.dart'
    as EditModel;
import 'package:cu_app/Features/AllMembers/model/all_members_model.dart';
import 'package:cu_app/Features/AllMembers/controller/all_members_controller.dart';
import 'package:cu_app/Widgets/toast_widget.dart';

import '../../../Commons/app_strings.dart';
import '../../Login/Controller/login_controller.dart';

// This controller handles the logic for editing member details in the application.
class EditMemberController extends GetxController {
  final EditMemberRepo _editMemberRepo = EditMemberRepo();
  final userController = Get.put(LoginController());

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool isUpdating = false.obs;
  final RxString selectedUserType = 'user'.obs;
  final RxString selectedAccountStatus = 'Active'.obs;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  EditModel.Data? currentUser;
  String? userId;

  final List<String> userTypes = ['user'];
  final List<String> accountStatuses = ['Active', 'Inactive'];

  @override
  void onInit() {
    super.onInit();

    if (Get.arguments != null && Get.arguments is MemberData) {
      final member = Get.arguments as MemberData;
      userId = member.sId;
      loadUserData();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getUserTypes();
    });
  }

// This method retrieves the user types based on the user's role.
  void getUserTypes() {
    if (userController.userModel.value.userType != null &&
        userController.userModel.value.userType!.isNotEmpty) {
      if (userController.userModel.value.userType!
          .contains(AdminCheck.superAdmin)) {
        userTypes.assignAll(['user', 'admin']);
      } else if (userController.userModel.value.userType!
          .contains(AdminCheck.admin)) {
        userTypes.assignAll(['user']);
      } else {
        userTypes.assignAll(['user']);
      }
    } else {
      userTypes.assignAll(['user']);
    }
    selectedUserType.value = userTypes.first;
  }

// This method retrieves the account statuses.
  Future<void> loadUserData() async {
    if (userId == null) return;

    try {
      isLoading.value = true;
      final response = await _editMemberRepo.getSingleUser(userId!);

      if (response.data?.success == true && response.data?.data != null) {
        currentUser = response.data!.data!;
        populateFormFields();
      } else {
        Get.back();
      }
    } catch (e) {
      Get.back();
    } finally {
      isLoading.value = false;
    }
  }

// This method populates the form fields with the current user's data.
  void populateFormFields() {
    if (currentUser != null) {
      nameController.text = currentUser!.name ?? '';
      emailController.text = currentUser!.email ?? '';
      phoneController.text = currentUser!.phone ?? '';
      passwordController.text = '';
      selectedUserType.value = currentUser!.userType ?? 'user';
      selectedAccountStatus.value = currentUser!.accountStatus ?? 'Active';
    }
  }

// This method updates the user details based on the form input.
  Future<void> updateUser() async {
    if (!formKey.currentState!.validate()) return;

    try {
      isUpdating.value = true;

      final response = await _editMemberRepo.updateUserDetails(
        id: userId!,
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        password: passwordController.text.trim(),
        userType: selectedUserType.value,
        accountStatus: selectedAccountStatus.value,
      );

      if (response.data?.success == true) {
        TostWidget().successToast(
          title: "Success",
          message: "User updated successfully",
        );

        final allMembersController = Get.find<AllMembersController>();
        allMembersController.refreshMembers();
      } else {
        TostWidget().errorToast(
          title: "Error",
          message: response.errorMessage ?? "Failed to update user",
        );
      }
    } catch (e) {
      TostWidget().errorToast(
        title: "Error",
        message: "An error occurred while updating user",
      );
    } finally {
      isUpdating.value = false;
    }
  }

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!GetUtils.isEmail(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (value.trim().length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    return null;
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.onClose();
  }
}
