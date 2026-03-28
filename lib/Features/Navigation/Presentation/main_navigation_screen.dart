import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:cu_app/Features/AllMembers/presentation/all_members_screen.dart';
import 'package:cu_app/Features/CallHistory/Presentation/call_history_screen.dart';
import 'package:cu_app/Features/Home/Presentation/build_mobile_view.dart';
import 'package:cu_app/Features/Meetings/Presentation/meetings_list_screen.dart';
import 'package:cu_app/Features/Navigation/Controller/navigation_controller.dart';
import 'package:cu_app/Features/Settings/Presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../Login/Controller/login_controller.dart';

// This screen serves as the main navigation hub for the application, allowing users to switch between different sections such as Chats, Calls, Contacts, Meetings, and Settings.
class MainNavigationScreen extends StatefulWidget {
  final bool isDeleteNavigation;
  final bool isFromChat;
  const MainNavigationScreen(
      {super.key, required this.isDeleteNavigation, this.isFromChat = false});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final navigationController = Get.put(NavigationController());
  final userController = Get.put(LoginController());

  bool get isUserAdminOrSuperAdmin {
    return userController.userModel.value.userType != null &&
        userController.userModel.value.userType!.isNotEmpty &&
        (userController.userModel.value.userType!.contains(AdminCheck.admin) ||
            userController.userModel.value.userType!
                .contains(AdminCheck.superAdmin));
  }

  List<Widget> get _screens {
    List<Widget> screens = [
      BuildMobileView(
        isDeleteNavigation: false,
        isFromChat: widget.isFromChat,
      ), // Chats screen
    ];

    screens.add(
      const CallHistoryScreen(), // Calls screen
    );

    if (isUserAdminOrSuperAdmin) {
      screens.add(const AllMembersScreen()); // Contacts screen
    }

    screens.add(const MeetingsListScreen()); // meetings screen

    screens.add(
      SettingsScreen(), // Settings screen
    );

    return screens;
  }

  List<BottomNavigationBarItem> get _bottomNavItems {
    List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.chat_bubble_outline),
        activeIcon: Icon(Icons.chat_bubble),
        label: 'Chats',
      ),
    ];

    items.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.call_outlined),
        activeIcon: Icon(Icons.call),
        label: 'Calls',
      ),
    );

    if (isUserAdminOrSuperAdmin) {
      items.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people),
          label: 'Contacts',
        ),
      );
    }

    items.add(
      BottomNavigationBarItem(
        icon: Obx(() {
          return Badge(
            smallSize: 10,
            isLabelVisible: navigationController.meetingsUnread.value,
            child: const Icon(Icons.calendar_month_outlined),
          );
        }),
        activeIcon: const Icon(Icons.calendar_month),
        label: 'Meetings',
        tooltip: 'Meetings', // Tooltip for the Meetings tab
      ),
    );

    items.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings_outlined),
        activeIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    );

    return items;
  }

  int currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Obx(() => _screens[navigationController.selectedIndex.value]),
        bottomNavigationBar: Obx(() => Container(
              decoration: BoxDecoration(
                color: colors.cardBg,
                boxShadow: [
                  BoxShadow(
                    color: colors.shadowColor,
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: navigationController.selectedIndex.value,
                onTap: navigationController.changeTabIndex,
                type: BottomNavigationBarType.fixed,
                backgroundColor: colors.cardBg,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: colors.textTertiary,
                selectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                items: _bottomNavItems,
              ),
            )),
      ),
    );
  }
}
