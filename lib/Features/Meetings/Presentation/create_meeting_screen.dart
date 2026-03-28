import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Features/Meetings/Controller/create_meeting_controller.dart';
import 'package:cu_app/Features/Meetings/Presentation/add_meeting_participants_screen.dart';
import 'package:cu_app/Widgets/custom_app_bar.dart';
import 'package:cu_app/Widgets/custom_card.dart';
import 'package:cu_app/Widgets/custom_text_field.dart';
import 'package:cu_app/Widgets/rounded_corner_container.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Commons/app_theme_colors.dart';

// This screen allows users to create a new meeting by entering details such as title, description, date, time, and duration. It validates the input and navigates to the next screen to add participants.
class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final createMeetingController = Get.put(CreateMeetingController());

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Form(
      key: _formKey,
      child: Scaffold(
        backgroundColor: colors.surfaceBg,
        appBar: const CustomAppBar(
          title: 'Schedule Meeting',
        ),
        body: RoundedCornerContainer(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSizes.kDefaultPadding),

                  // Meeting Title
                  CustomCard(
                    padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meeting Title*',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: AppSizes.kDefaultPadding / 2),
                        CustomTextField(
                          controller:
                              createMeetingController.meetingTitleController,
                          hintText: 'Enter meeting title',
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Meeting title is required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 2),

                  // Description
                  CustomCard(
                    padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description (Optional)',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: AppSizes.kDefaultPadding / 2),
                        CustomTextField(
                          controller:
                              createMeetingController.descriptionController,
                          hintText: 'Enter meeting description',
                          minLines: 1,
                          maxLines: 5,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 2),

                  // Start Date & Time
                  CustomCard(
                    padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date & Time*',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: AppSizes.kDefaultPadding / 2),

                        // Date Picker
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: colors.textTertiary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () => createMeetingController
                                        .selectStartDate(context),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: colors.borderColor),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            color: colors.iconSecondary,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Obx(() => Text(
                                                createMeetingController
                                                    .formattedStartDate,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: createMeetingController
                                                                  .selectedStartDate
                                                                  .value ==
                                                              null
                                                          ? colors.textTertiary
                                                          : colors.textPrimary,
                                                    ),
                                              )),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 5),

                        // Time Input
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.textTertiary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                // Hour Dropdown (1-12)
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border:
                                          Border.all(color: colors.borderColor),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child:
                                        Obx(() => DropdownButtonHideUnderline(
                                              child: DropdownButton<int>(
                                                value: createMeetingController
                                                    .selectedHour.value,
                                                isExpanded: true,
                                                hint: const Text('Hour'),
                                                icon: Icon(
                                                  Icons.keyboard_arrow_down,
                                                  color: colors.iconSecondary,
                                                  size: 16,
                                                ),
                                                items: createMeetingController
                                                    .hourOptions
                                                    .map((hour) {
                                                  return DropdownMenuItem<int>(
                                                    value: hour,
                                                    child: Text(
                                                      hour
                                                          .toString()
                                                          .padLeft(2, '0'),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color: colors
                                                                .textPrimary,
                                                          ),
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (int? value) {
                                                  if (value != null) {
                                                    createMeetingController
                                                        .updateHour(value);
                                                  }
                                                },
                                              ),
                                            )),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                Text(
                                  ':',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),

                                const SizedBox(width: 8),

                                // Minute Dropdown
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border:
                                          Border.all(color: colors.borderColor),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child:
                                        Obx(() => DropdownButtonHideUnderline(
                                              child: DropdownButton<int>(
                                                value: createMeetingController
                                                    .selectedMinute.value,
                                                isExpanded: true,
                                                hint: const Text('Min'),
                                                icon: Icon(
                                                  Icons.keyboard_arrow_down,
                                                  color: colors.iconSecondary,
                                                  size: 16,
                                                ),
                                                items: createMeetingController
                                                    .minuteOptions
                                                    .map((minute) {
                                                  return DropdownMenuItem<int>(
                                                    value: minute,
                                                    child: Text(
                                                      minute
                                                          .toString()
                                                          .padLeft(2, '0'),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color: colors
                                                                .textPrimary,
                                                          ),
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (int? value) {
                                                  if (value != null) {
                                                    createMeetingController
                                                        .updateMinute(value);
                                                  }
                                                },
                                              ),
                                            )),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // AM/PM Dropdown
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border:
                                          Border.all(color: colors.borderColor),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Obx(() =>
                                        DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: createMeetingController
                                                .selectedAmPm.value,
                                            isExpanded: true,
                                            icon: Icon(
                                              Icons.keyboard_arrow_down,
                                              color: colors.iconSecondary,
                                              size: 16,
                                            ),
                                            items: createMeetingController
                                                .amPmOptions
                                                .map((amPm) {
                                              return DropdownMenuItem<String>(
                                                value: amPm,
                                                child: Text(
                                                  amPm,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color:
                                                            colors.textPrimary,
                                                      ),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (String? value) {
                                              if (value != null) {
                                                createMeetingController
                                                    .updateAmPm(value);
                                              }
                                            },
                                          ),
                                        )),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Display selected time
                            Obx(() => Text(
                                  'Selected time: ${createMeetingController.formattedSelectedTime}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colors.textTertiary,
                                      ),
                                )),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 2),

                  // Meeting Duration
                  CustomCard(
                    padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meeting Duration*',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: AppSizes.kDefaultPadding / 2),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.kDefaultPadding,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.borderColor),
                            borderRadius: BorderRadius.circular(
                                AppSizes.cardCornerRadius),
                          ),
                          child: Obx(() => DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: createMeetingController
                                      .selectedDurationMinutes.value,
                                  isExpanded: true,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down,
                                    color: colors.iconSecondary,
                                  ),
                                  items: createMeetingController.durationOptions
                                      .map((duration) {
                                    final minutes = duration;

                                    return DropdownMenuItem<int>(
                                      value: duration,
                                      child: Text(
                                        '${minutes} min',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: colors.textPrimary,
                                            ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (int? value) {
                                    if (value != null) {
                                      createMeetingController
                                          .updateDuration(value);
                                    }
                                  },
                                ),
                              )),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSizes.kDefaultPadding * 4),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            if (_formKey.currentState!.validate() &&
                createMeetingController.validateFormAndTime()) {
              Get.to(() => const AddMeetingParticipantsScreen());
            }
          },
          backgroundColor: AppColors.primary,
          icon:
              const Icon(EvaIcons.arrowForwardOutline, color: AppColors.white),
          label: const Text(
            'Next',
            style:
                TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
