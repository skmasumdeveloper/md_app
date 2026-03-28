import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';

import '../Model/meetings_list_model.dart';
import '../Repository/meetings_repo.dart';
import '../../../Widgets/toast_widget.dart';
import '../../../Utils/storage_service.dart';
import '../../../Utils/calendar_storage.dart';
import '../Model/calendar_event_model.dart';

class MeetingCalendarController extends GetxController {
  // Calendar date limits
  DateTime firstDay = DateTime(DateTime.now().year - 10, 1, 1);
  DateTime lastDay = DateTime(DateTime.now().year + 10, 12, 31);
  // Current focused day
  DateTime focusedDay = DateTime.now();
  // Selected day
  DateTime? selectedDay = DateTime.now();
  // Calendar format (Month / Week)
  CalendarFormat calendarFormat = CalendarFormat.month;
  final _meetingsRepo = MeetingsRepo();
  RxList<MeetingModel> meetingsList = <MeetingModel>[].obs;
  RxBool isMeetingsListLoading = false.obs;
  RxString slug = "meeting".obs;
  RxInt limit = 1000.obs;
  RxString startDateCalendar = "".obs;
  RxString endDateCalendar = "".obs;

  // Number of padding days added before/after the month when requesting calendar events
  final int calendarPaddingDays = 10;

  // Track processing meeting ids for actions
  RxList<String> processingMeetingIds = <String>[].obs;
  RxBool isActionLoading = false.obs;

  // Map of events keyed by date (date only, no time)
  Map<DateTime, List<MeetingModel>> events = {};

  // Return meetings for a given date (normalized day)
  List<MeetingModel> getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return events[key] ?? [];
  }

  // Build events map from meetingsList
  void _buildEventsFromMeetings() {
    events.clear();
    for (final meeting in meetingsList) {
      if (meeting.meetingStartTime == null || meeting.meetingStartTime!.isEmpty)
        continue;
      try {
        final parsed = DateTime.parse(meeting.meetingStartTime!);
        final local = parsed.toLocal();
        final key = DateTime(local.year, local.month, local.day);
        events.putIfAbsent(key, () => []).add(meeting);
      } catch (e) {
        print('Error parsing meeting start time: $e');
      }
    }
  }

  // Build events map from storage (Hive + device events) and convert to MeetingModel for UI
  void _buildEventsFromStorage() {
    events.clear();
    final stored = CalendarStorage.getAllEvents();

    // Separate app-origin events and device-origin events
    final Map<String, CalendarEventModel> appByMeetingId = {};
    final List<CalendarEventModel> deviceEvents = [];

    for (final e in stored) {
      if (e.source == 'app') {
        final key = e.meetingId ?? e.id;
        appByMeetingId[key] = e;
      } else {
        deviceEvents.add(e);
      }
    }

    // Link device events that contain meetingId to existing app events to avoid duplicates
    for (final de in deviceEvents) {
      final mid = de.meetingId;
      if (mid != null && appByMeetingId.containsKey(mid)) {
        final appEvt = appByMeetingId[mid]!;
        if (appEvt.deviceEventId == null || appEvt.deviceEventId!.isEmpty) {
          appEvt.deviceEventId = de.deviceEventId;
          // persist the link
          CalendarStorage.linkDeviceEventToAppEvent(
              mid, de.deviceEventId ?? '');
        }
      }
    }

    // Add app events (preferred view) -- show action buttons
    for (final app in appByMeetingId.values) {
      try {
        final local = app.start.toLocal();
        final key = DateTime(local.year, local.month, local.day);

        // Build meeting from stored app event
        final meeting = MeetingModel(
          sId: app.meetingId ?? app.id,
          groupName: app.title,
          meetingStartTime: app.start.toUtc().toIso8601String(),
          meetingEndTime: app.end?.toUtc().toIso8601String(),
          link: app.link,
          pin: app.pin,
          isDeviceEvent: false,
        );

        // Try to enrich with the latest server-side meeting info (userAction, images, participants)
        try {
          MeetingModel? cached;
          for (var m in meetingsList) {
            if (m.sId != null && m.sId == (app.meetingId ?? app.id)) {
              cached = m;
              break;
            }
          }
          if (cached != null) {
            meeting.userAction = cached.userAction;
            meeting.participantActions = cached.participantActions;
            meeting.groupImage = cached.groupImage ?? meeting.groupImage;
            meeting.groupName = cached.groupName ?? meeting.groupName;
          }
        } catch (_) {}

        events.putIfAbsent(key, () => []).add(meeting);
      } catch (err) {
        print('Error building app event from storage: $err');
      }
    }

    // Add device-only events (those not linked to an app meeting)
    for (final de in deviceEvents) {
      if (de.meetingId != null && appByMeetingId.containsKey(de.meetingId))
        continue;
      try {
        final local = de.start.toLocal();
        final key = DateTime(local.year, local.month, local.day);

        final meeting = MeetingModel(
          sId: de.meetingId ?? de.id,
          groupName: de.title,
          meetingStartTime: de.start.toUtc().toIso8601String(),
          meetingEndTime: de.end?.toUtc().toIso8601String(),
          link: de.link,
          pin: de.pin,
          isDeviceEvent: true,
        );

        events.putIfAbsent(key, () => []).add(meeting);
      } catch (err) {
        print('Error building device event from storage: $err');
      }
    }

    update();
  }

  // Init calendar values
  void initCalendar() {
    final now = DateTime.now();
    firstDay = DateTime(now.year - 10, 1, 1);
    lastDay = DateTime(now.year + 10, 12, 31);
    focusedDay = now;
    selectedDay = now;

    // Determine month visible range and add padding days so that events on the edges are included
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final lastOfMonth = DateTime(now.year, now.month + 1, 0);

    final start = firstOfMonth.subtract(Duration(days: calendarPaddingDays));
    final end = lastOfMonth.add(Duration(days: calendarPaddingDays));

    startDateCalendar.value = start.toUtc().toIso8601String();
    print('Start Date (with padding): ${startDateCalendar.value}');
    endDateCalendar.value = end.toUtc().toIso8601String();
    print('End Date (with padding): ${endDateCalendar.value}');

    getCalenderMeetingsList();
  }

  @override
  void onInit() {
    super.onInit();
    // Ensure calendar is initialized when the controller is created
    initCalendar();

    // initialize local calendar storage (Hive) and import device events
    CalendarStorage.init().then((_) async {
      // import device events for the initial visible month
      await CalendarStorage.importDeviceEvents(
          start: DateTime.now().subtract(Duration(days: calendarPaddingDays)),
          end: DateTime.now().add(Duration(days: calendarPaddingDays)));
      _buildEventsFromStorage();
    });
  }

  // When format button clicked
  void onFormatChanged(CalendarFormat format) {
    calendarFormat = format;

    update();
  }

  // When calendar page changed (month swipe)
  void onPageChanged(DateTime day) {
    focusedDay = day;

    // update startDateCalendar and endDateCalendar for the focused month with padding
    final firstOfMonth = DateTime(day.year, day.month, 1);
    final lastOfMonth = DateTime(day.year, day.month + 1, 0);

    final start = firstOfMonth.subtract(Duration(days: calendarPaddingDays));
    final end = lastOfMonth.add(Duration(days: calendarPaddingDays));

    startDateCalendar.value = start.toUtc().toIso8601String();
    endDateCalendar.value = end.toUtc().toIso8601String();
    // Fetch events for the newly focused month but do NOT replace existing cached events.
    // This prevents removing events for the currently selected day when user is only paging.
    getCalenderMeetingsList(isLoadingShow: false);
    // after paging (new month), import device events for the visible range and reload storage
    update();
    CalendarStorage.importDeviceEvents(start: start, end: end)
        .then((_) => _buildEventsFromStorage());
  }

  // When day selected
  void onDaySelected(DateTime selected, DateTime focused) {
    selectedDay = selected;
    focusedDay = focused;

    // Ensure events for the selected day are available. If not present in cache, fetch
    // for the focused month (with padding) so the list below updates only when user taps a date.
    final key = DateTime(selected.year, selected.month, selected.day);
    if (!events.containsKey(key)) {
      final firstOfMonth = DateTime(focused.year, focused.month, 1);
      final lastOfMonth = DateTime(focused.year, focused.month + 1, 0);

      final start = firstOfMonth.subtract(Duration(days: calendarPaddingDays));
      final end = lastOfMonth.add(Duration(days: calendarPaddingDays));

      startDateCalendar.value = start.toUtc().toIso8601String();
      endDateCalendar.value = end.toUtc().toIso8601String();
      getCalenderMeetingsList(isLoadingShow: false);
    }

    update();
  }

  Future<void> getCalenderMeetingsList({bool isLoadingShow = true}) async {
    try {
      isLoadingShow
          ? isMeetingsListLoading(true)
          : isMeetingsListLoading(false);
      var res = await _meetingsRepo.getCalendarMeetingsList(
          limit: limit.value,
          slug: slug.value,
          startDate: startDateCalendar.value,
          endDate: endDateCalendar.value);
      RxList<MeetingModel> listData = <MeetingModel>[].obs;

      if (res.data!.success == true) {
        listData.value = res.data!.meetingModel!;

        listData = listData.toList().obs;

        print('Calendar Meetings List: ${listData.length}');

        // If this is an initial load (isLoadingShow == true) replace the cache.
        // If this was triggered by paging (isLoadingShow == false) merge results with existing cache
        // so we don't lose events for the currently selected day.
        if (isLoadingShow) {
          meetingsList.clear();
          meetingsList.addAll(listData);
        } else {
          // Merge results with existing cache: update any existing meetings and add new ones.
          for (var m in listData) {
            if (m.sId == null) continue;
            final idx = meetingsList.indexWhere((ex) => ex.sId == m.sId);
            if (idx >= 0) {
              // Preserve local known actions if server response is missing them
              final existing = meetingsList[idx];
              if ((m.userAction == null ||
                      (m.userAction?.action ?? '').isEmpty) &&
                  existing.userAction != null) {
                m.userAction = existing.userAction;
              }
              if ((m.participantActions == null ||
                      m.participantActions!.isEmpty) &&
                  (existing.participantActions != null &&
                      existing.participantActions!.isNotEmpty)) {
                m.participantActions = existing.participantActions;
              }
              meetingsList[idx] = m;
            } else {
              meetingsList.add(m);
            }
          }
        }

        // persist app events into Hive
        await CalendarStorage.upsertAppEvents(meetingsList.toList());

        // import device events for the focused month (with padding)
        final firstOfMonth = DateTime(focusedDay.year, focusedDay.month, 1);
        final lastOfMonth = DateTime(focusedDay.year, focusedDay.month + 1, 0);

        final start =
            firstOfMonth.subtract(Duration(days: calendarPaddingDays));
        final end = lastOfMonth.add(Duration(days: calendarPaddingDays));
        await CalendarStorage.importDeviceEvents(start: start, end: end);

        // rebuild events map from storage (combined app + device events)
        _buildEventsFromStorage();
        update();
        isMeetingsListLoading(false);
      } else {
        // On failure: only clear cache if this was an explicit loading (initial load),
        // otherwise keep existing cached meetings so selected day events are preserved.
        if (isLoadingShow) meetingsList.value = [];
        // still rebuild events from storage so device events still show
        _buildEventsFromStorage();
        isMeetingsListLoading(false);
      }
    } catch (e) {
      isMeetingsListLoading(false);
    }
  }

  // Accept meeting: call API and update meeting userAction
  Future<void> acceptMeeting(MeetingModel meeting) async {
    final userId = LocalStorage().getUserId();
    if (meeting.sId == null || userId.isEmpty) return;

    final id = meeting.sId!;
    processingMeetingIds.add(id);
    update();

    try {
      final res = await _meetingsRepo.groupAction(
          groupId: id, action: 'accept', userId: userId);
      if (res.data != null) {
        meeting.userAction = res.data;
        // Also update the cached meetingsList entry so rebuilding uses the latest action immediately
        if (meeting.sId != null) {
          final idx = meetingsList.indexWhere((m) => m.sId == meeting.sId);
          if (idx >= 0) {
            meetingsList[idx].userAction = res.data;
          }
        }
        _buildEventsFromMeetings();
        update();
        // Refresh from server to ensure data consistency
        await getCalenderMeetingsList(isLoadingShow: false);
        TostWidget()
            .successToast(title: 'Success', message: 'Meeting accepted');
      } else {
        TostWidget().errorToast(title: 'Error', message: res.errorMessage);
      }
    } catch (e) {
      TostWidget().errorToast(title: 'Error', message: e.toString());
    } finally {
      processingMeetingIds.remove(id);
      update();
    }
  }

  // Decline meeting with a reason
  Future<void> declineMeeting(MeetingModel meeting, String reason) async {
    final userId = LocalStorage().getUserId();
    if (meeting.sId == null || userId.isEmpty) return;

    final id = meeting.sId!;
    processingMeetingIds.add(id);
    update();

    try {
      final res = await _meetingsRepo.groupAction(
          groupId: id,
          action: 'reject',
          userId: userId,
          actionDescription: reason);
      if (res.data != null) {
        meeting.userAction = res.data;
        // Also update cached meetingsList entry
        if (meeting.sId != null) {
          final idx = meetingsList.indexWhere((m) => m.sId == meeting.sId);
          if (idx >= 0) {
            meetingsList[idx].userAction = res.data;
          }
        }
        _buildEventsFromMeetings();
        update();
        // Refresh from server to ensure data consistency
        await getCalenderMeetingsList(isLoadingShow: false);
        TostWidget()
            .successToast(title: 'Success', message: 'Meeting rejected');
      } else {
        TostWidget().errorToast(title: 'Error', message: res.errorMessage);
      }
    } catch (e) {
      TostWidget().errorToast(title: 'Error', message: e.toString());
    } finally {
      processingMeetingIds.remove(id);
      update();
    }
  }

  // Sync app events to device calendar and refresh storage
  Future<void> syncToDeviceCalendar() async {
    try {
      await CalendarStorage.syncAppEventsToDeviceCalendar();
      // re-import device events and rebuild
      final firstOfMonth = DateTime(focusedDay.year, focusedDay.month, 1);
      final lastOfMonth = DateTime(focusedDay.year, focusedDay.month + 1, 0);
      final start = firstOfMonth.subtract(Duration(days: calendarPaddingDays));
      final end = lastOfMonth.add(Duration(days: calendarPaddingDays));
      await CalendarStorage.importDeviceEvents(start: start, end: end);
      _buildEventsFromStorage();
      TostWidget()
          .successToast(title: 'Success', message: 'Synced to device calendar');
    } catch (e) {
      TostWidget().errorToast(title: 'Error', message: e.toString());
    }
  }

  // Fetch API events for range and sync to device
  Future<void> fetchAndSyncToDeviceCalendar(
      DateTime start, DateTime end) async {
    try {
      final localStart = DateTime(start.year, start.month, start.day);
      final localEnd = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
      final startDateStr = localStart.toUtc().toIso8601String();
      final endDateStr = localEnd.toUtc().toIso8601String();

      // Fetch from API
      var res = await _meetingsRepo.getCalendarMeetingsList(
          limit: 1000,
          slug: slug.value,
          startDate: startDateStr,
          endDate: endDateStr);

      if (res.data?.success == true && res.data?.meetingModel != null) {
        final meetings = res.data!.meetingModel!;
        // Upsert to Hive
        await CalendarStorage.upsertAppEvents(meetings);

        // Now sync to device
        await CalendarStorage.syncAppEventsToDeviceCalendar();

        // Refresh view
        final firstOfMonth = DateTime(focusedDay.year, focusedDay.month, 1);
        final lastOfMonth = DateTime(focusedDay.year, focusedDay.month + 1, 0);
        final s = firstOfMonth.subtract(Duration(days: calendarPaddingDays));
        final e = lastOfMonth.add(Duration(days: calendarPaddingDays));
        await CalendarStorage.importDeviceEvents(start: s, end: e);
        _buildEventsFromStorage();

        TostWidget().successToast(
            title: 'Success',
            message: 'Synced ${meetings.length} events to device calendar');
      } else {
        TostWidget().errorToast(
            title: 'Error',
            message: res.errorMessage ?? 'Failed to fetch events from server');
      }
    } catch (e) {
      TostWidget().errorToast(title: 'Error', message: e.toString());
    }
  }

  // Clear app-origin events from device calendars and remove app events from Hive, then refresh API
  Future<void> clearAppEventsFromDeviceCalendar() async {
    try {
      await CalendarStorage.deleteAppEventsFromDeviceCalendarAndClearHive();

      // re-import device events for visible month and rebuild
      final firstOfMonth = DateTime(focusedDay.year, focusedDay.month, 1);
      final lastOfMonth = DateTime(focusedDay.year, focusedDay.month + 1, 0);
      final start = firstOfMonth.subtract(Duration(days: calendarPaddingDays));
      final end = lastOfMonth.add(Duration(days: calendarPaddingDays));
      await CalendarStorage.importDeviceEvents(start: start, end: end);
      _buildEventsFromStorage();

      // Refresh server calendar API to repopulate app events
      await getCalenderMeetingsList();

      TostWidget().successToast(
          title: 'Success', message: 'Cleared app events from device calendar');
    } catch (e) {
      TostWidget().errorToast(title: 'Error', message: e.toString());
    }
  }
}
