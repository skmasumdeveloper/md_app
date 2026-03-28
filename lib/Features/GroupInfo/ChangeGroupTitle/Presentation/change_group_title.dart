import 'package:cu_app/Commons/route.dart';
import 'package:cu_app/Commons/app_theme_colors.dart';
import 'package:cu_app/Features/GroupInfo/Presentation/group_info_screen.dart';
import 'package:flutter/material.dart';
import '../../../../Commons/app_sizes.dart';
import '../../../../Widgets/custom_app_bar.dart';

// This screen allows users to change the title of a group.
class ChangeGroupTitle extends StatefulWidget {
  final String groupId;

  const ChangeGroupTitle({
    super.key,
    required this.groupId,
  });

  @override
  State<ChangeGroupTitle> createState() => _ChangeGroupTitleState();
}

class _ChangeGroupTitleState extends State<ChangeGroupTitle> {
  final TextEditingController titleController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Form(
      key: _formKey,
      child: Scaffold(
        backgroundColor: colors.surfaceBg,
        appBar: const CustomAppBar(
          title: 'Enter New Title',
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
              color: colors.cardBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Group Title',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .copyWith(color: colors.textPrimary),
                  ),
                  const SizedBox(
                    height: AppSizes.kDefaultPadding,
                  ),
                ],
              ),
            ),
            const Spacer(),
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.kDefaultPadding * 2),
                child: Column(
                  children: [
                    Container(
                      alignment: Alignment.center,
                      child: TextButton(
                          style: TextButton.styleFrom(
                              maximumSize:
                                  const Size.fromHeight(AppSizes.buttonHeight)),
                          onPressed: () {
                            context.pop(GroupInfoScreen(
                              groupId: widget.groupId,
                              isMeeting: false,
                            ));
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
            ),
          ],
        ),
      ),
    );
  }
}
