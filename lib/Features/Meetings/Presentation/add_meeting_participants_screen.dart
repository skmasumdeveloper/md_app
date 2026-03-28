import 'package:cached_network_image/cached_network_image.dart';
import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Features/Meetings/Controller/create_meeting_controller.dart';
import 'package:cu_app/Widgets/custom_app_bar.dart';
import 'package:cu_app/Widgets/custom_text_field.dart';
import 'package:cu_app/Widgets/rounded_corner_container.dart';
import 'package:cu_app/Widgets/shimmer_effetct.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Commons/app_theme_colors.dart';

// This screen allows users to add participants to a meeting by selecting from a list of members. It includes a search bar, displays selected participants, and provides functionality to create a meeting with the selected participants.
class AddMeetingParticipantsScreen extends StatefulWidget {
  const AddMeetingParticipantsScreen({super.key});

  @override
  State<AddMeetingParticipantsScreen> createState() =>
      _AddMeetingParticipantsScreenState();
}

class _AddMeetingParticipantsScreenState
    extends State<AddMeetingParticipantsScreen> {
  final TextEditingController searchController = TextEditingController();
  final createMeetingController = Get.find<CreateMeetingController>();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surfaceBg,
      appBar: CustomAppBar(
        title: 'Add Participants',
        actions: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.kDefaultPadding + 6),
            child: Obx(() => Text(
                  '${createMeetingController.selectedMemberIds.length} / ${createMeetingController.memberList.length}',
                  style: const TextStyle(color: AppColors.white),
                )),
          )
        ],
      ),
      body: RoundedCornerContainer(
        child: Column(
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.kDefaultPadding),
              margin: const EdgeInsets.all(AppSizes.kDefaultPadding),
              decoration: BoxDecoration(
                color: colors.surfaceBg,
                borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
              ),
              child: Row(
                children: [
                  Icon(
                    EvaIcons.searchOutline,
                    size: 22,
                    color: colors.iconSecondary,
                  ),
                  const SizedBox(width: AppSizes.kDefaultPadding),
                  Expanded(
                    child: CustomTextField(
                      controller: searchController,
                      hintText: 'Search participants...',
                      isBorder: false,
                      onChanged: (val) {
                        createMeetingController.searchText.value =
                            val.toString();
                        EasyDebounce.debounce(
                          'meeting-participants-search',
                          const Duration(milliseconds: 200),
                          () async {
                            await createMeetingController.getMemberList();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Selected participants summary
            Obx(() => createMeetingController.selectedMembers.isNotEmpty
                ? Container(
                    height: 120,
                    margin: const EdgeInsets.symmetric(
                        horizontal: AppSizes.kDefaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${createMeetingController.selectedMembers.length} Selected',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                        ),
                        const SizedBox(height: 5),
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount:
                                createMeetingController.selectedMembers.length,
                            itemBuilder: (context, index) {
                              final member = createMeetingController
                                  .selectedMembers[index];
                              return Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSizes.kDefaultPadding,
                                  top: 10,
                                ),
                                child: Column(
                                  children: [
                                    Stack(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(2.0),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                                AppSizes.cardCornerRadius * 10),
                                            child: CachedNetworkImage(
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              imageUrl: member.image ?? "",
                                              placeholder: (context, url) =>
                                                  const CircleAvatar(
                                                radius: 20,
                                                backgroundColor:
                                                    AppColors.shimmer,
                                              ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      CircleAvatar(
                                                radius: 20,
                                                backgroundColor:
                                                    AppColors.shimmer,
                                                child: Text(
                                                  member.name
                                                          ?.substring(0, 1)
                                                          .toUpperCase() ??
                                                      '?',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: GestureDetector(
                                            onTap: () => createMeetingController
                                                .toggleMemberSelection(member),
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: AppColors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.close,
                                                size: 12,
                                                color: colors.textOnPrimary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        member.name?.length != null &&
                                                member.name!.length > 8
                                            ? "${member.name!.substring(0, 8)}.."
                                            : member.name ?? "",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox()),

            // Members List (with pagination)
            Expanded(
              child: Obx(() {
                // Show initial loader only when loading first page
                if (createMeetingController.isMemberListLoading.value &&
                    createMeetingController.page.value == 1) {
                  return const ShimmerEffectLaoder(numberOfWidget: 20);
                }

                if (createMeetingController.memberList.isEmpty) {
                  return Center(
                    child: Text("No participants found",
                        style: TextStyle(color: colors.textSecondary)),
                  );
                }

                final showBottomLoader =
                    createMeetingController.isMemberListLoading.value &&
                        createMeetingController.hasMore.value;

                // calculate itemCount to include a loader only while loading more
                final itemCount = createMeetingController.memberList.length +
                    (showBottomLoader ? 1 : 0);

                return NotificationListener<ScrollNotification>(
                  onNotification: (scrollInfo) {
                    if (scrollInfo.metrics.pixels >=
                            scrollInfo.metrics.maxScrollExtent - 100 &&
                        !createMeetingController.isMemberListLoading.value &&
                        createMeetingController.hasMore.value) {
                      createMeetingController.loadMoreMembers();
                    }
                    return false;
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: ListView.builder(
                      itemCount: itemCount,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.kDefaultPadding),
                      itemBuilder: (context, index) {
                        // show loader at the end while more data is expected
                        if (index >=
                            createMeetingController.memberList.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }

                        final member =
                            createMeetingController.memberList[index];

                        return Container(
                          margin: const EdgeInsets.only(
                              bottom: AppSizes.kDefaultPadding / 2),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                    AppSizes.cardCornerRadius * 10),
                                child: CachedNetworkImage(
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  imageUrl: member.image ?? "",
                                  placeholder: (context, url) =>
                                      const CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.shimmer,
                                  ),
                                  errorWidget: (context, url, error) =>
                                      CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.shimmer,
                                    child: Text(
                                      member.name
                                              ?.substring(0, 1)
                                              .toUpperCase() ??
                                          '?',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSizes.kDefaultPadding),
                              Expanded(
                                child: Obx(() {
                                  final isSelected = createMeetingController
                                      .selectedMemberIds
                                      .contains(member.sId);

                                  return CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member.name ?? "",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge,
                                        ),
                                        if (member.email?.isNotEmpty == true)
                                          Text(
                                            member.email!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: colors.textTertiary,
                                                ),
                                          ),
                                      ],
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.trailing,
                                    value: isSelected,
                                    onChanged: (value) {
                                      createMeetingController
                                          .toggleMemberSelection(member);
                                    },
                                  );
                                }),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton:
          Obx(() => createMeetingController.isCreatingMeeting.value
              ? const FloatingActionButton(
                  onPressed: null,
                  backgroundColor: AppColors.grey,
                  child: CircularProgressIndicator(color: AppColors.white),
                )
              : FloatingActionButton.extended(
                  onPressed:
                      createMeetingController.selectedMemberIds.isNotEmpty
                          ? () => createMeetingController.createMeeting(context)
                          : null,
                  backgroundColor:
                      createMeetingController.selectedMemberIds.isNotEmpty
                          ? AppColors.primary
                          : AppColors.grey,
                  icon: const Icon(Icons.check, color: AppColors.white),
                  label: const Text(
                    'Create Meeting',
                    style: TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.w600),
                  ),
                )),
    );
  }
}
