import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';

import '../Commons/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final bool? autoImplyLeading;

  const CustomAppBar({
    super.key,
    this.title = '',
    this.actions,
    this.autoImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: AppBar(
            elevation: 0.0,
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: autoImplyLeading!,
            actions: actions,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.appBarGradient,
              ),
            ),
            leading: autoImplyLeading == true
                ? IconButton(
                    icon: const Icon(
                      EvaIcons.arrowBack,
                      color: AppColors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  )
                : const SizedBox(),
            title: Text(
              title!,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium!
                  .copyWith(color: AppColors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
