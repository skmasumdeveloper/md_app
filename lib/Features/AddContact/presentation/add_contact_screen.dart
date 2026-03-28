import 'package:cu_app/Commons/app_colors.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:cu_app/Features/AddContact/controller/add_contact_controller.dart';
import 'package:cu_app/Widgets/custom_text_field.dart';
import 'package:cu_app/Widgets/full_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// This screen allows users to add a new contact by filling out a form with their details.
class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final addContactController = Get.put(AddContactController());
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      addContactController.getUserTypes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.appBarGradient,
          ),
        ),
        title: const Text('New Contact',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: AppColors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Container(
          decoration: BoxDecoration(
            color: colors.cardBg,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.person_add,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Create New Contact',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the details below to create a new contact',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.textTertiary,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Obx(() => CustomTextField(
                        controller: addContactController.nameController.value,
                        labelText: 'Full Name',
                        hintText: 'Enter full name',
                        suffixIcon: const Icon(Icons.person_outline),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter full name';
                          }
                          if (value.length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      )),
                  const SizedBox(height: 20),
                  Obx(() => CustomTextField(
                        controller: addContactController.emailController.value,
                        labelText: 'Email Address',
                        hintText: 'Enter email address',
                        keyboardType: TextInputType.emailAddress,
                        suffixIcon: const Icon(Icons.email_outlined),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email address';
                          }
                          if (!GetUtils.isEmail(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      )),
                  const SizedBox(height: 20),
                  Obx(() => CustomTextField(
                        controller:
                            addContactController.passwordController.value,
                        labelText: 'Password',
                        hintText: 'Enter password',
                        obscureText:
                            addContactController.isPasswordVisible.value,
                        suffixIcon: IconButton(
                          icon: Icon(
                            addContactController.isPasswordVisible.value
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed:
                              addContactController.togglePasswordVisibility,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      )),
                  Obx(() =>
                      addContactController.isShowUserTypeDropDown.value == true
                          ? const SizedBox(height: 20)
                          : const SizedBox(height: 0)),
                  Obx(() =>
                      addContactController.isShowUserTypeDropDown.value == true
                          ? Text(
                              'User Type',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: colors.textSecondary,
                                  ),
                            )
                          : const SizedBox(
                              height: 0,
                            )),
                  const SizedBox(height: 8),
                  Obx(() => addContactController.userTypes.isNotEmpty &&
                          addContactController.isShowUserTypeDropDown.value ==
                              true
                      ? Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.borderColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: addContactController.selectedUserType.value,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              prefixIcon:
                                  Icon(Icons.admin_panel_settings_outlined),
                            ),
                            items: addContactController.userTypes
                                .map((String userType) {
                              return DropdownMenuItem<String>(
                                value: userType,
                                child: Text(
                                  userType.toLowerCase() == 'user'
                                      ? 'User'
                                      : 'Admin',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                addContactController.setUserType(newValue);
                              }
                            },
                          ),
                        )
                      : SizedBox(
                          height: 50,
                        )),
                  const SizedBox(height: 40),
                  Obx(() => addContactController.isLoading.value
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : FullButton(
                          label: 'Create Contact',
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              addContactController.createUser(context);
                            }
                            return null;
                          },
                        )),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
