import 'package:cu_app/Commons/commons.dart';
import 'package:cu_app/Widgets/custom_app_bar.dart';
import 'package:cu_app/Widgets/custom_card.dart';
import 'package:cu_app/Widgets/custom_text_field.dart';
import 'package:cu_app/Widgets/rounded_corner_container.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Commons/app_theme_colors.dart';
import '../Controller/edit_meeting_controller.dart';

// This screen allows users to edit an existing meeting by entering updated details such as title, description, date, time, and duration. It validates the input and navigates to the next screen to add participants.
class EditMeetingScreen extends StatefulWidget {
  final String groupId;
  const EditMeetingScreen({super.key, required this.groupId});

  @override
  State<EditMeetingScreen> createState() => _EditMeetingScreenState();
}

class _EditMeetingScreenState extends State<EditMeetingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final editMeetingController = Get.put(EditMeetingController());

  @override
  void initState() {
    super.initState();
    // Initialize the controller with the group ID to fetch existing meeting details
    WidgetsBinding.instance.addPostFrameCallback((t) {
      editMeetingController.clearForm();
      editMeetingController.getMeetingDetails(widget.groupId);
    });
  }

  @override
  void dispose() {
    editMeetingController.dispose();
    editMeetingController.clearForm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Form(
      key: _formKey,
      child: Scaffold(
        backgroundColor: colors.surfaceBg,
        appBar: const CustomAppBar(
          title: 'Edit Meeting',
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
                        Obx(() {
                          if (editMeetingController.isLoading.value) {
                            return const Center(
                                child: CircularProgressIndicator(
                              strokeWidth: 1,
                            ));
                          }
                          return CustomTextField(
                            controller:
                                editMeetingController.meetingTitleController,
                            hintText: 'Enter meeting title',
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Meeting title is required';
                              }
                              return null;
                            },
                          );
                        }),
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
                              editMeetingController.descriptionController,
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
                                    onTap: () => editMeetingController
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
                                                editMeetingController
                                                    .formattedStartDate,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: editMeetingController
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
                                                value: editMeetingController
                                                        .hourOptions
                                                        .contains(
                                                            editMeetingController
                                                                .selectedHour
                                                                .value)
                                                    ? editMeetingController
                                                        .selectedHour.value
                                                    : null, // ensure valid
                                                isExpanded: true,
                                                hint: const Text('Hour'),
                                                icon: Icon(
                                                  Icons.keyboard_arrow_down,
                                                  color: colors.iconSecondary,
                                                  size: 16,
                                                ),
                                                items: editMeetingController
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
                                                    editMeetingController
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
                                                value: editMeetingController
                                                        .minuteOptions
                                                        .contains(
                                                            editMeetingController
                                                                .selectedMinute
                                                                .value)
                                                    ? editMeetingController
                                                        .selectedMinute.value
                                                    : null, // ensure valid
                                                isExpanded: true,
                                                hint: const Text('Min'),
                                                icon: Icon(
                                                  Icons.keyboard_arrow_down,
                                                  color: colors.iconSecondary,
                                                  size: 16,
                                                ),
                                                items: editMeetingController
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
                                                    editMeetingController
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
                                            value: editMeetingController
                                                    .amPmOptions
                                                    .contains(
                                                        editMeetingController
                                                            .selectedAmPm.value)
                                                ? editMeetingController
                                                    .selectedAmPm.value
                                                : null, // ensure valid
                                            isExpanded: true,
                                            icon: Icon(
                                              Icons.keyboard_arrow_down,
                                              color: colors.iconSecondary,
                                              size: 16,
                                            ),
                                            items: editMeetingController
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
                                                editMeetingController
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
                                  'Selected time: ${editMeetingController.formattedSelectedTime}',
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
                                  value: editMeetingController.durationOptions
                                          .contains(editMeetingController
                                              .selectedDurationMinutes.value)
                                      ? editMeetingController
                                          .selectedDurationMinutes.value
                                      : null, // ensure valid
                                  isExpanded: true,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down,
                                    color: colors.iconSecondary,
                                  ),
                                  items: editMeetingController.durationOptions
                                      .map((duration) {
                                    final minutes = duration;

                                    return DropdownMenuItem<int>(
                                      value: duration,
                                      child: Text(
                                        '$minutes min',
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
                                      editMeetingController
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
        floatingActionButton: Obx(() {
          if (editMeetingController.isLoading.value) {
            return const SizedBox.shrink();
          }
          if (editMeetingController.isUpdateLoading.value) {
            return const CircularProgressIndicator();
          }
          return FloatingActionButton.extended(
            onPressed: () {
              if (_formKey.currentState!.validate() &&
                  editMeetingController.validateFormAndTime()) {
                editMeetingController.updateGroup(context: context);
              }
            },
            backgroundColor: AppColors.primary,
            icon: const Icon(EvaIcons.checkmark, color: AppColors.white),
            label: const Text(
              'Update',
              style: TextStyle(
                  color: AppColors.white, fontWeight: FontWeight.w600),
            ),
          );
        }),
      ),
    );
  }
}
