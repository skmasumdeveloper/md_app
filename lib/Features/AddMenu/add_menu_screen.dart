import 'package:cu_app/Commons/app_colors.dart';
import 'package:cu_app/Features/AllMembers/presentation/all_members_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Commons/app_strings.dart';
import '../AddContact/presentation/add_contact_screen.dart';
import '../AddMembers/Presentation/add_members_screen.dart';
import '../Login/Controller/login_controller.dart';

// This screen provides options to add new members or create groups, depending on the user's role.
class AddMenuScreen extends StatefulWidget {
  const AddMenuScreen({super.key});

  @override
  State<AddMenuScreen> createState() => _AddMenuScreenState();
}

class _AddMenuScreenState extends State<AddMenuScreen> {
  final userController = Get.put(LoginController());
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      userController.getUserProfile();
    });
  }

// This method navigates to the AddMembersScreen to create a new group.
  void _navigateToCreateGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddMembersScreen(
          isCameFromHomeScreen: true,
          groupId: "",
        ),
      ),
    );
  }

// This method navigates to the AddContactScreen to add a new contact.
  void _navigateToAddMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddContactScreen(),
      ),
    );
  }

// This method navigates to the AllMembersScreen to view all members.
  void _navigateToAllMebers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AllMembersScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
        ),
        title: const Text('Add Menu',
            style:
                TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            userController.userModel.value.userType != null &&
                    userController.userModel.value.userType!.isNotEmpty
                ? userController.userModel.value.userType!
                            .contains(AdminCheck.admin) ||
                        userController.userModel.value.userType!
                            .contains(AdminCheck.superAdmin)
                    ? _buildMenuCard(
                        'Create New Group',
                        Icons.group_add,
                        'Create a new group for collaboration',
                        _navigateToCreateGroup,
                        Colors.blue.shade100,
                        Colors.blue.shade700,
                      )
                    : const SizedBox.shrink()
                : const SizedBox.shrink(),
            const SizedBox(height: 16),
            userController.userModel.value.userType != null &&
                    userController.userModel.value.userType!.isNotEmpty
                ? userController.userModel.value.userType!
                            .contains(AdminCheck.admin) ||
                        userController.userModel.value.userType!
                            .contains(AdminCheck.superAdmin)
                    ? _buildMenuCard(
                        'Add New Contact',
                        Icons.person_add,
                        'Create a new user',
                        _navigateToAddMembers,
                        Colors.green.shade100,
                        const Color.fromARGB(255, 84, 105, 86),
                      )
                    : const SizedBox.shrink()
                : const SizedBox.shrink(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    String title,
    IconData icon,
    String description,
    VoidCallback onTap,
    Color backgroundColor,
    Color iconColor,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 26, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
