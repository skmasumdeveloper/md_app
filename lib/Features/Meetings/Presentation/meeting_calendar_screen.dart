import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../Commons/app_colors.dart';
import '../../../Commons/app_theme_colors.dart';
import '../../../Widgets/custom_app_bar.dart';
import '../Controller/meeting_calendar_controller.dart';
import '../Model/meetings_list_model.dart';
import 'meeting_details_screen.dart';
import 'meeting_list_item.dart';
import 'package:intl/intl.dart';
import '../../../Widgets/toast_widget.dart';
import '../../../Utils/calendar_storage.dart';
import '../../../Utils/storage_service.dart';
import '../../../services/navigation_service.dart';

class MeetingCalendarScreen extends StatefulWidget {
  const MeetingCalendarScreen({super.key});

  @override
  State<MeetingCalendarScreen> createState() => _MeetingCalendarScreenState();
}

class _MeetingCalendarScreenState extends State<MeetingCalendarScreen> {
  final MeetingCalendarController controller =
      Get.put(MeetingCalendarController());

  // local UI filter: 0 = All, 1 = Upcoming, 2 = Past
  int _selectedFilter = 0;

  // Initialize calendar on state init
  @override
  void initState() {
    super.initState();
  }

  String _formatSelectedDateLabel(DateTime date) {
    final month = DateFormat('MMM').format(date);
    final day = date.day;
    String suffix = 'th';
    if (!(day >= 11 && day <= 13)) {
      final last = day % 10;
      if (last == 1) suffix = 'st';
      if (last == 2) suffix = 'nd';
      if (last == 3) suffix = 'rd';
    }
    return '$month $day$suffix';
  }

  Widget _buildFilterButton(BuildContext ctx, String label, int index) {
    final colors = ctx.appColors;
    final bool selected = _selectedFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary : colors.surfaceBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? AppColors.secondary : colors.borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected ? colors.textOnPrimary : colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surfaceBg,
      appBar: CustomAppBar(
        title: 'Calendar',
        actions: [
          // icon button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () async {
                final calendars =
                    await CalendarStorage.ensureCalendarsAvailable();
                if (!mounted) return;

                final availableCalendars =
                    calendars.where((c) => c.id != null).toList();
                if (availableCalendars.isEmpty) {
                  TostWidget().errorToast(
                      title: 'Calendar sync failed',
                      message: 'No device calendars available');
                  return;
                }

                final storage = LocalStorage();

                final localCalendars = availableCalendars
                    .where((c) =>
                        c.name == CalendarStorage.localCalendarName ||
                        c.accountName == CalendarStorage.localCalendarName)
                    .toList();

                final Map<String, List<Calendar>> accountCalendars = {};
                for (final cal in availableCalendars) {
                  final account = cal.accountName ?? '';
                  if (account.isEmpty ||
                      account == CalendarStorage.localCalendarName) {
                    continue;
                  }
                  accountCalendars.putIfAbsent(account, () => []).add(cal);
                }

                String selectedKey = '';
                final storedType = storage.getSelectedCalendarType();
                final storedAccount = storage.getSelectedCalendarAccount();
                final storedId = storage.getSelectedCalendarId();

                if (storedType == CalendarStorage.selectionTypeAccount &&
                    storedAccount.isNotEmpty &&
                    accountCalendars.containsKey(storedAccount)) {
                  selectedKey = 'account:$storedAccount';
                } else if (storedType == CalendarStorage.selectionTypeLocal &&
                    localCalendars.isNotEmpty) {
                  selectedKey = 'local:${CalendarStorage.localCalendarName}';
                } else if (storedId.isNotEmpty) {
                  final found = availableCalendars.firstWhere(
                      (c) => c.id == storedId,
                      orElse: () => availableCalendars.first);
                  final account = found.accountName ?? '';
                  if (account.isNotEmpty &&
                      account != CalendarStorage.localCalendarName) {
                    selectedKey = 'account:$account';
                  } else if (localCalendars.isNotEmpty) {
                    selectedKey = 'local:${CalendarStorage.localCalendarName}';
                  }
                }

                if (selectedKey.isEmpty) {
                  if (accountCalendars.isNotEmpty) {
                    selectedKey = 'account:${accountCalendars.keys.first}';
                  } else if (localCalendars.isNotEmpty) {
                    selectedKey = 'local:${CalendarStorage.localCalendarName}';
                  }
                }

                showDialog(
                  context: context,
                  builder: (ctx) => Dialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: StatefulBuilder(
                        builder: (context, setState) {
                          final dialogColors = context.appColors;
                          return SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Calendar Sync',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: dialogColors.textPrimary),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Manage how app events appear on your device',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: dialogColors.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Select calendar account',
                                    style: TextStyle(
                                        color: dialogColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value:
                                      selectedKey.isEmpty ? null : selectedKey,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: dialogColors.borderColor)),
                                  ),
                                  items: [
                                    ...accountCalendars.keys.map((account) {
                                      return DropdownMenuItem<String>(
                                        value: 'account:$account',
                                        child: Text(
                                          account,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13),
                                        ),
                                      );
                                    }),
                                    if (localCalendars.isNotEmpty)
                                      DropdownMenuItem<String>(
                                        value:
                                            'local:${CalendarStorage.localCalendarName}',
                                        child: const Text(
                                          'Local_Calendar',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13),
                                        ),
                                      ),
                                  ],
                                  onChanged: (val) {
                                    if (val == null) return;
                                    setState(() {
                                      selectedKey = val;
                                      final parts = val.split(':');
                                      final type = parts.first;
                                      final value =
                                          val.substring(type.length + 1);

                                      if (type ==
                                          CalendarStorage
                                              .selectionTypeAccount) {
                                        final cals = accountCalendars[value] ??
                                            <Calendar>[];
                                        final first =
                                            cals.isNotEmpty ? cals.first : null;
                                        storage.setSelectedCalendar(
                                            calendarId: first?.id ?? '',
                                            calendarName: first?.name,
                                            calendarAccount: value,
                                            calendarType: CalendarStorage
                                                .selectionTypeAccount);
                                      } else if (type ==
                                          CalendarStorage.selectionTypeLocal) {
                                        final first = localCalendars.isNotEmpty
                                            ? localCalendars.first
                                            : null;
                                        storage.setSelectedCalendar(
                                            calendarId: first?.id ?? '',
                                            calendarName: first?.name ??
                                                CalendarStorage
                                                    .localCalendarName,
                                            calendarAccount: CalendarStorage
                                                .localCalendarName,
                                            calendarType: CalendarStorage
                                                .selectionTypeLocal);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final parentContext = context;
                                      Navigator.of(ctx)
                                          .pop(); // Close initial dialog
                                      final picked = await showDateRangePicker(
                                        context: parentContext,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                        initialDateRange: DateTimeRange(
                                          start: DateTime.now(),
                                          end: DateTime.now()
                                              .add(const Duration(days: 90)),
                                        ),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme:
                                                  const ColorScheme.light(
                                                primary: AppColors.primary,
                                                onPrimary: Colors.white,
                                                onSurface: Colors.black,
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                        helpText:
                                            'Select Sync Period (Max 1 Year)',
                                      );

                                      if (!mounted) return;
                                      if (picked != null) {
                                        final duration = picked.end
                                            .difference(picked.start)
                                            .inDays;
                                        if (duration > 365) {
                                          TostWidget().errorToast(
                                              title: 'Invalid Range',
                                              message:
                                                  'Please select a range within 1 year');
                                          return;
                                        }

                                        final dialogContext = NavigationService
                                            .navigatorKey.currentContext;
                                        if (dialogContext == null) return;
                                        showDialog(
                                          context: dialogContext,
                                          barrierDismissible: false,
                                          builder: (_) => const Center(
                                              child:
                                                  CircularProgressIndicator()),
                                        );
                                        await controller
                                            .fetchAndSyncToDeviceCalendar(
                                                picked.start, picked.end);
                                        if (!mounted) return;
                                        Navigator.of(dialogContext,
                                                rootNavigator: true)
                                            .pop();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    icon: Icon(Icons.sync,
                                        color: dialogColors.textOnPrimary, size: 20),
                                    label: Text(
                                      'Sync App Events to Device',
                                      style: TextStyle(
                                          color: dialogColors.textOnPrimary,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final parentContext = context;
                                      Navigator.of(ctx).pop();
                                      final confirmed = await showDialog<bool>(
                                        context: parentContext,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Unsync Calendar?'),
                                          content: const Text(
                                              'This will remove all app events from your device calendar. Are you sure?'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.of(c).pop(false),
                                                child: const Text('Cancel')),
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.of(c).pop(true),
                                                child: const Text('Unsync',
                                                    style: TextStyle(
                                                        color: AppColors.red))),
                                          ],
                                        ),
                                      );
                                      if (!mounted) return;
                                      if (confirmed == true) {
                                        final dialogContext = NavigationService
                                            .navigatorKey.currentContext;
                                        if (dialogContext == null) return;
                                        showDialog(
                                          context: dialogContext,
                                          barrierDismissible: false,
                                          builder: (_) => const Center(
                                              child:
                                                  CircularProgressIndicator()),
                                        );
                                        await controller
                                            .clearAppEventsFromDeviceCalendar();
                                        if (!mounted) return;
                                        Navigator.of(dialogContext,
                                                rootNavigator: true)
                                            .pop();
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.red,
                                      side: const BorderSide(color: AppColors.red),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.delete_outline,
                                        color: AppColors.red, size: 20),
                                    label: const Text(
                                        'Clear App Events from Device',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: () => Navigator.of(ctx).pop(),
                                  child: Text('Cancel',
                                      style:
                                          TextStyle(color: dialogColors.textSecondary)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(top: 6, bottom: 6),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_repeat_outlined, color: AppColors.white),
                    const SizedBox(height: 2),
                    const Text(
                      'Sync Calendar',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: GetBuilder<MeetingCalendarController>(
        builder: (c) {
          return Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colors.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.borderColor),
                  ),
                  child: TableCalendar(
                    firstDay: c.firstDay,
                    lastDay: c.lastDay,
                    focusedDay: c.focusedDay,

                    // REQUIRED to avoid crash
                    calendarFormat: c.calendarFormat,
                    onFormatChanged: c.onFormatChanged,

                    // Day selection
                    selectedDayPredicate: (day) =>
                        isSameDay(c.selectedDay, day),
                    onDaySelected: c.onDaySelected,

                    // Page swipe
                    onPageChanged: c.onPageChanged,

                    // load events for markers
                    eventLoader: c.getEventsForDay,

                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      headerPadding:
                          EdgeInsets.symmetric(vertical: 2, horizontal: 0),
                    ),

                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      // default marker decoration (single dot)
                      markerDecoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      markerSize: 6,
                      markersMaxCount: 4,
                    ),

                    // Custom marker builder to ensure dots use primary color and sit at bottom center
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        final int count = events.length > 4 ? 4 : events.length;
                        if (count == 0) return const SizedBox.shrink();
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Wrap(
                              spacing: 4,
                              children: List.generate(count, (index) {
                                return Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Selected date header + filter tabs
                Builder(builder: (ctx) {
                  final selectedDate = c.selectedDay ?? c.focusedDay;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_formatSelectedDateLabel(selectedDate)} Agenda',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: colors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildFilterButton(ctx, 'All', 0),
                            const SizedBox(width: 12),
                            _buildFilterButton(ctx, 'Upcoming', 1),
                            const SizedBox(width: 12),
                            _buildFilterButton(ctx, 'Past', 2),
                          ],
                        )
                      ],
                    ),
                  );
                }),

                // Filtered events list
                Expanded(
                  child: Builder(builder: (ctx) {
                    final selectedDate = c.selectedDay ?? c.focusedDay;
                    final allEvents = c.getEventsForDay(selectedDate);
                    final now = DateTime.now();
                    List<MeetingModel> filteredEvents;

                    if (_selectedFilter == 1) {
                      filteredEvents = allEvents.where((e) {
                        try {
                          final start =
                              DateTime.parse(e.meetingStartTime!).toLocal();
                          return start.isAfter(now);
                        } catch (_) {
                          return false;
                        }
                      }).toList();
                    } else if (_selectedFilter == 2) {
                      filteredEvents = allEvents.where((e) {
                        try {
                          final end = e.meetingEndTime != null &&
                                  e.meetingEndTime!.isNotEmpty
                              ? DateTime.parse(e.meetingEndTime!).toLocal()
                              : null;
                          final start =
                              DateTime.parse(e.meetingStartTime!).toLocal();
                          if (end != null) return end.isBefore(now);
                          return start.isBefore(now);
                        } catch (_) {
                          return false;
                        }
                      }).toList();
                    } else {
                      filteredEvents = allEvents;
                    }

                    if (filteredEvents.isEmpty) {
                      return Center(
                          child: Text('No meetings for selected date',
                              style: TextStyle(color: colors.textSecondary)));
                    }

                    return ListView.separated(
                      itemCount: filteredEvents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final meeting = filteredEvents[index];
                        return MeetingListItem(
                          meeting: meeting,
                          isProcessing: controller.processingMeetingIds
                              .contains(meeting.sId ?? ''),
                          onTap: () {
                            if (meeting.isDeviceEvent == true) {
                              return;
                            }
                            Get.to(() => MeetingDetailsScreen(meeting: meeting))
                                ?.then((_) =>
                                    controller.getCalenderMeetingsList());
                          },
                          onAccept: () async {
                            await controller.acceptMeeting(meeting);
                          },
                          onDecline: () async {
                            final TextEditingController reasonCtrl =
                                TextEditingController();
                            final reason = await showDialog<String>(
                              context: context,
                              builder: (ctx) {
                                return AlertDialog(
                                  title: const Text('Reason for declining'),
                                  content: TextField(
                                    controller: reasonCtrl,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter reason',
                                    ),
                                    maxLines: 3,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(ctx)
                                            .pop(reasonCtrl.text.trim());
                                      },
                                      child: const Text('Submit'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (reason != null && reason.isNotEmpty) {
                              await controller.declineMeeting(meeting, reason);
                            }
                          },
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
