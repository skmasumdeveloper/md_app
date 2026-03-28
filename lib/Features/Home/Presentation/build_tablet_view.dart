import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/commons.dart';
import 'package:flutter/material.dart';
import '../../../Commons/app_theme_colors.dart';

import '../../MyProfile/Presentation/my_profile_screen.dart';
import 'home_screen.dart';

// This widget builds the tablet view for the home screen, including the app bar and chat list.
class BuildTabletView extends StatefulWidget {
  final bool isDeleteNavigation;
  final bool isFromChat;
  const BuildTabletView(
      {super.key, required this.isDeleteNavigation, this.isFromChat = false});

  @override
  State<BuildTabletView> createState() => _BuildTabletViewState();
}

class _BuildTabletViewState extends State<BuildTabletView> {
  bool? isAdmin;
  int? selectedIndex;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Container(
                  height: AppSizes.appBarHeight,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.kDefaultPadding),
                  decoration: BoxDecoration(color: colors.surfaceBg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => context.push(const MyProfileScreen()),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                              AppSizes.cardCornerRadius * 10),
                          child: CachedNetworkImage(
                              width: 34,
                              height: 34,
                              fit: BoxFit.cover,
                              imageUrl:
                                  'https://images.unsplash.com/photo-1575936123452-b67c3203c357?q=80&w=1000&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8aW1hZ2V8ZW58MHx8MHx8fDA%3D',
                              placeholder: (context, url) => CircleAvatar(
                                    radius: 16,
                                    backgroundColor: colors.surfaceBg,
                                  ),
                              errorWidget: (context, url, error) =>
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: colors.surfaceBg,
                                    child: Text(
                                      "Name",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                  )),
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(
                    child: BuildChatList(
                  isAdmin: isAdmin ?? false,
                  isDeleteNavigation: widget.isDeleteNavigation,
                  isFromChat: widget.isFromChat,
                ))
              ],
            ),
          ),
          Container(
            width: 1,
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(color: colors.dividerColor),
          ),
          Expanded(
            flex: 3,
            child: Container(
              color: colors.surfaceBg,
            ),
          ),
        ],
      ),
    );
  }
}
