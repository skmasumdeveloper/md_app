import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../Commons/app_colors.dart';
import '../../../Commons/app_sizes.dart';
import '../../../Commons/app_theme_colors.dart';
import '../../../Widgets/custom_app_bar.dart';
import '../../../Widgets/custom_card.dart';
import '../../../Widgets/custom_text_field.dart';
import '../../../Widgets/rounded_corner_container.dart';
import '../../../Widgets/toast_widget.dart';
import '../../../Utils/invite_utils.dart';
import '../controller/guest_meeting_controller.dart';
import 'guest_meeting_create_screen.dart';
import 'guest_meeting_details_screen.dart';

class GuestMeetingListScreen extends StatefulWidget {
  GuestMeetingListScreen({Key? key}) : super(key: key);

  @override
  State<GuestMeetingListScreen> createState() => _GuestMeetingListScreenState();
}

class _GuestMeetingListScreenState extends State<GuestMeetingListScreen> {
  final controller = Get.put(GuestMeetingController());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.getGuestMeetings(isLoadingShow: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surfaceBg,
      appBar: CustomAppBar(
        title: 'Guest Meetings',
        actions: [
          IconButton(
            onPressed: () async {
              await controller.getGuestMeetings(isLoadingShow: true);
            },
            icon: Icon(Icons.refresh, color: colors.textOnPrimary),
          ),
        ],
      ),
      body: SafeArea(
        child: RoundedCornerContainer(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                child: CustomTextField(
                  controller: controller.searchController,
                  hintText: 'Search guest meetings',
                  prefixIcon: Icon(Icons.search, color: colors.iconSecondary),
                  onChanged: (v) {
                    controller.searchText.value = v;
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (controller.searchText.value == v) {
                        controller.getGuestMeetings();
                      }
                    });
                  },
                ),
              ),
              Expanded(child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.guestMeetings.isEmpty) {
                  return Center(
                      child: Text('No guest meetings found',
                          style: TextStyle(color: colors.textSecondary)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.kDefaultPadding),
                  itemCount: controller.guestMeetings.length,
                  itemBuilder: (context, index) {
                    final m = controller.guestMeetings[index];
                    final guestCount = m.guests.length;
                    final firstGuestName = m.guests.isNotEmpty
                        ? (m.guests.first.name ?? '').trim()
                        : '';
                    final guestSummary = guestCount <= 0
                        ? 'No guests'
                        : guestCount == 1
                            ? firstGuestName
                            : '$firstGuestName +${guestCount - 1}';
                    String dateStr = '';
                    String timeStr = '';
                    String status = m.status ?? '';
                    try {
                      final dt = DateTime.parse(m.startTime!).toLocal();
                      dateStr = DateFormat('dd/MM/yyyy').format(dt);
                      timeStr = DateFormat('hh:mm a').format(dt);
                      final s = dt;
                      final e = m.endTime != null
                          ? DateTime.parse(m.endTime!).toLocal()
                          : null;
                      final now = DateTime.now();
                      if (e != null && now.isAfter(s) && now.isBefore(e)) {
                        status = 'In progress';
                      } else if (now.isBefore(s)) {
                        status = 'Scheduled';
                      } else if (e != null && now.isAfter(e)) {
                        status = 'Ended';
                      }
                    } catch (_) {}

                    return CustomCard(
                      onPressed: () {
                        controller.setSelectedMeeting(m);
                        Get.to(() => GuestMeetingDetailsScreen(meeting: m));
                      },
                      padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // rounded square avatar
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: colors.surfaceBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                (m.topic ?? 'G').trim().isNotEmpty
                                    ? (m.topic ?? 'G').trim()[0].toUpperCase()
                                    : 'G',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                        color: AppColors.orange,
                                        fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // main content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.topic ?? 'No topic',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colors.textPrimary)),
                                const SizedBox(height: 6),
                                Text('$guestSummary • $dateStr',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: colors.textTertiary)),
                                const SizedBox(height: 4),
                                Text(timeStr,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: colors.textTertiary)),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // right-side actions and status
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // status pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: status == 'In progress'
                                      ? AppColors.green.withOpacity(0.15)
                                      : status == 'Scheduled'
                                          ? AppColors.primary.withOpacity(0.12)
                                          : colors.surfaceBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: status == 'In progress'
                                        ? AppColors.green
                                        : status == 'Scheduled'
                                            ? AppColors.primary
                                            : colors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // action icons
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (status != 'Ended') ...[
                                    IconButton(
                                      icon: Icon(Icons.copy,
                                          size: 20, color: colors.iconSecondary),
                                      tooltip: 'Copy invite',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(8),
                                      onPressed: () async {
                                        await InviteUtils.copyInviteToClipboard(
                                          context: context,
                                          link: m.meetingLink ?? '',
                                          pin: m.pin,
                                          meetingStartTime: m.startTime,
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.share,
                                          size: 20, color: colors.iconSecondary),
                                      tooltip: 'Share invite',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(8),
                                      onPressed: () async {
                                        await InviteUtils.shareInvite(
                                          link: m.meetingLink ?? '',
                                          pin: m.pin,
                                          meetingStartTime: m.startTime,
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              )
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              }))
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          controller.clearForm();
          final res = await Get.to(() => const GuestMeetingCreateScreen());
          if (res == true) {
            // Show success toast and refresh
            TostWidget().successToast(
                title: 'Success', message: 'Guest meeting created');
            await controller.getGuestMeetings(isLoadingShow: true);
          }
        },
      ),
    );
  }
}
