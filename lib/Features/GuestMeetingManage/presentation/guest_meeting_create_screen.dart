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
import '../controller/guest_meeting_controller.dart';

class GuestMeetingCreateScreen extends StatefulWidget {
  const GuestMeetingCreateScreen({Key? key}) : super(key: key);

  @override
  State<GuestMeetingCreateScreen> createState() =>
      _GuestMeetingCreateScreenState();
}

class _GuestMeetingCreateScreenState extends State<GuestMeetingCreateScreen> {
  final controller = Get.find<GuestMeetingController>();
  final _formKey = GlobalKey<FormState>();

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: controller.selectedStartDate.value ?? now,
      // disallow past dates — user should pick today or future dates only
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) controller.selectedStartDate.value = d;
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();

    // If user already selected a date and it's today, disallow past times.
    final selectedDate = controller.selectedStartDate.value;
    final isDateToday = selectedDate != null &&
        selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    // Choose a sensible initial time: previously selected time or now (if date is today)
    final initial = controller.selectedStartTime.value ??
        (isDateToday
            ? TimeOfDay(hour: now.hour, minute: now.minute)
            : TimeOfDay.now());

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked == null) return;

    // If selected date is today, prevent choosing a past time
    if (isDateToday) {
      final pickedDt =
          DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      if (!pickedDt.isAfter(now)) {
        TostWidget().errorToast(
          title: 'Validation',
          message: 'Please select a future time for today',
        );
        return;
      }
    }

    controller.selectedStartTime.value = picked;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surfaceBg,
      appBar: const CustomAppBar(title: 'Create Guest Meeting'),
      body: RoundedCornerContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomCard(
                  padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                  child: Column(
                    children: [
                      CustomTextField(
                        controller: controller.subjectController,
                        hintText: 'Subject',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: controller.descriptionController,
                        hintText: 'Description (Optional)',
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CustomCard(
                  padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Guests',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: colors.textPrimary,
                              )),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: controller.guestNameController,
                              hintText: 'Guest Name',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CustomTextField(
                              controller: controller.guestEmailController,
                              hintText: 'Guest Email',
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 44,
                            width: 44,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.orange,
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: controller.addGuestToMeeting,
                              child: const Text('Add',
                                  style: TextStyle(fontSize: 15)),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      Obx(() {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.borderColor),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: controller.selectedGuests.isEmpty
                              ? Text(
                                  'No guests added',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: colors.textTertiary),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: List.generate(
                                    controller.selectedGuests.length,
                                    (index) {
                                      final guest =
                                          controller.selectedGuests[index];
                                      final label =
                                          '${guest.name ?? ''} (${guest.email ?? ''})';
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: AppColors.orange),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(label,
                                                style: TextStyle(
                                                    color: colors.textPrimary)),
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () => controller
                                                  .removeGuestAt(index),
                                              child: Icon(
                                                Icons.close,
                                                size: 16,
                                                color: colors.iconSecondary,
                                              ),
                                            )
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomCard(
                        padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                        child: Obx(() {
                          final date = controller.selectedStartDate.value;
                          final dateText = date == null
                              ? 'Select date'
                              : DateFormat('dd/MM/yyyy').format(date);
                          final time = controller.selectedStartTime.value;
                          final timeText = time == null
                              ? 'Select time'
                              : time.format(context);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Meeting Start Time',
                                  style:
                                      Theme.of(context).textTheme.labelMedium),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _pickDate,
                                icon:
                                    const Icon(Icons.calendar_today, size: 16),
                                label: Text(dateText),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _pickTime,
                                icon: const Icon(Icons.access_time, size: 16),
                                label: Text(timeText),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomCard(
                        padding: const EdgeInsets.all(AppSizes.kDefaultPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Meeting Duration',
                                style: Theme.of(context).textTheme.labelMedium),
                            const SizedBox(height: 8),
                            Obx(
                              () => DropdownButtonFormField<int>(
                                value: controller.selectedDurationMinutes.value,
                                items: controller.durationOptions
                                    .map(
                                      (e) => DropdownMenuItem(
                                          value: e, child: Text('$e min')),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    controller.selectedDurationMinutes.value =
                                        v;
                                  }
                                },
                                decoration: const InputDecoration(
                                    border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Obx(() {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSizes.dimen16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: controller.isLoading.value
                          ? null
                          : () async {
                              if (_formKey.currentState?.validate() ?? false) {
                                final ok =
                                    await controller.createGuestMeeting();
                                if (ok) {
                                  Get.back(result: true);
                                }
                              }
                            },
                      child: controller.isLoading.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Obx(
                              () => Text(
                                'Create Meeting (${controller.selectedGuests.length} Guest${controller.selectedGuests.length == 1 ? '' : 's'})',
                                style: TextStyle(color: colors.textOnPrimary),
                              ),
                            ),
                    ),
                  );
                })
              ],
            ),
          ),
        ),
      ),
    );
  }
}
