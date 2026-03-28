import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cu_app/Commons/app_colors.dart';
import 'package:cu_app/Features/EditMember/controller/edit_member_controller.dart';

// This screen allows users to edit member details such as name, email, password, user type, and account status.
class EditMemberScreen extends StatefulWidget {
  const EditMemberScreen({super.key});

  @override
  State<EditMemberScreen> createState() => _EditMemberScreenState();
}

class _EditMemberScreenState extends State<EditMemberScreen> {
  final editMemberController = Get.put(EditMemberController());

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
        title: const Text(
          'Edit Member',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Obx(() {
        if (editMemberController.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: editMemberController.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(context, 'Name', colors),
                const SizedBox(height: 8),
                _buildTextField(
                  context: context,
                  colors: colors,
                  controller: editMemberController.nameController,
                  hintText: 'Enter full name',
                  prefixIcon: Icons.person_outline,
                  validator: editMemberController.validateName,
                ),
                const SizedBox(height: 20),
                _buildSectionTitle(context, 'Email', colors),
                const SizedBox(height: 8),
                _buildTextField(
                  context: context,
                  colors: colors,
                  controller: editMemberController.emailController,
                  hintText: 'Enter email address',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: editMemberController.validateEmail,
                ),
                const SizedBox(height: 20),
                _buildSectionTitle(context, 'Password', colors),
                const SizedBox(height: 8),
                _buildTextField(
                  context: context,
                  colors: colors,
                  controller: editMemberController.passwordController,
                  hintText: 'Enter password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                if (editMemberController.selectedUserType.value != 'user') ...[
                  _buildSectionTitle(context, 'User Type', colors),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    context: context,
                    colors: colors,
                    value: editMemberController.selectedUserType.value,
                    items: editMemberController.userTypes,
                    onChanged: (value) {
                      editMemberController.selectedUserType.value = value!;
                    },
                    icon: Icons.admin_panel_settings_outlined,
                  ),
                  const SizedBox(height: 20),
                ],
                _buildSectionTitle(context, 'Account Status', colors),
                const SizedBox(height: 8),
                _buildDropdown(
                  context: context,
                  colors: colors,
                  value: editMemberController.selectedAccountStatus.value,
                  items: editMemberController.accountStatuses,
                  onChanged: (value) {
                    editMemberController.selectedAccountStatus.value = value!;
                  },
                  icon: Icons.account_circle_outlined,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: editMemberController.isUpdating.value
                        ? null
                        : editMemberController.updateUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: editMemberController.isUpdating.value
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        : const Text(
                            'Update Member',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSectionTitle(
      BuildContext context, String title, AppThemeColors colors) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required AppThemeColors colors,
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: colors.textFieldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDropdown({
    required BuildContext context,
    required AppThemeColors colors,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor),
        color: colors.textFieldBg,
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item.capitalize!,
              style: const TextStyle(fontSize: 16),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        dropdownColor: colors.cardBg,
        style: TextStyle(color: colors.textPrimary),
      ),
    );
  }
}
