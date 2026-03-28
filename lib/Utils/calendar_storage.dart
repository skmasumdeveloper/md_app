import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart' show Color;
import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;

import '../Features/Meetings/Model/calendar_event_model.dart';
import '../Features/Meetings/Model/meetings_list_model.dart';
import '../Widgets/toast_widget.dart';
import 'storage_service.dart';

class CalendarStorage {
  static const String boxName = 'calendar_events';
  static const String localCalendarName = 'Local_Calendar';
  static const String selectionTypeAccount = 'account';
  static const String selectionTypeCalendar = 'calendar';
  static const String selectionTypeLocal = 'local';
  static final DeviceCalendarPlugin _deviceCalendarPlugin =
      DeviceCalendarPlugin();

  static Future<void> init() async {
    await Hive.openBox<CalendarEventModel>(boxName);
  }

  static Box<CalendarEventModel> get _box =>
      Hive.box<CalendarEventModel>(boxName);

  // Upsert app events from meeting list
  static Future<void> upsertAppEvents(List<MeetingModel> meetings) async {
    for (var m in meetings) {
      if (m.sId == null || m.meetingStartTime == null) continue;
      try {
        final start = DateTime.parse(m.meetingStartTime!).toLocal();
        final end = m.meetingEndTime != null
            ? DateTime.parse(m.meetingEndTime!).toLocal()
            : null;

        final evt = CalendarEventModel(
          id: m.sId!,
          title: m.groupName ?? 'Meeting',
          start: start,
          end: end,
          allDay: false,
          source: 'app',
          meetingId: m.sId,
          link: m.link,
          pin: m.pin,
          deviceEventId: null,
        );
        await _box.put(evt.id, evt);
      } catch (_) {}
    }
  }

  static List<CalendarEventModel> getAllEvents() {
    return _box.values.toList();
  }

  static Calendar? _pickWritableCalendar(List<Calendar> calendars,
      {String? preferredId}) {
    if (calendars.isEmpty) return null;

    if (preferredId != null && preferredId.isNotEmpty) {
      for (final c in calendars) {
        if (c.id == preferredId && (c.isReadOnly != true)) return c;
      }
    }

    for (final c in calendars) {
      if ((c.isDefault == true) && (c.isReadOnly != true)) return c;
    }

    for (final c in calendars) {
      if (c.isReadOnly != true) return c;
    }

    return calendars.first;
  }

  static List<Calendar> _filterWritable(List<Calendar> calendars) {
    return calendars.where((c) => c.isReadOnly != true).toList();
  }

  static List<Calendar> _resolveTargetCalendars(List<Calendar> calendars) {
    final storage = LocalStorage();
    final type = storage.getSelectedCalendarType();
    final account = storage.getSelectedCalendarAccount();
    final calendarId = storage.getSelectedCalendarId();

    final writable = _filterWritable(calendars);
    if (writable.isEmpty) return <Calendar>[];

    if (type == selectionTypeAccount && account.isNotEmpty) {
      final byAccount =
          writable.where((c) => c.accountName == account).toList();
      if (byAccount.isNotEmpty) return byAccount;
    }

    if (type == selectionTypeLocal) {
      final locals = writable
          .where((c) =>
              c.name == localCalendarName || c.accountName == localCalendarName)
          .toList();
      if (locals.isNotEmpty) return locals;
    }

    if (calendarId.isNotEmpty) {
      final byId = writable.where((c) => c.id == calendarId).toList();
      if (byId.isNotEmpty) return byId;
    }

    final fallback = _pickWritableCalendar(writable);
    return fallback == null ? <Calendar>[] : <Calendar>[fallback];
  }

  static Future<List<Calendar>> ensureCalendarsAvailable() async {
    final permissionsResult = await _deviceCalendarPlugin.hasPermissions();
    if (!(permissionsResult.isSuccess == true &&
        permissionsResult.data == true)) {
      final requestResult = await _deviceCalendarPlugin.requestPermissions();
      if (!(requestResult.isSuccess == true && requestResult.data == true)) {
        try {
          TostWidget().errorToast(
              title: 'Calendar sync failed',
              message: 'Calendar permission not granted');
        } catch (_) {}
        return <Calendar>[];
      }
    }

    var calendarsRes = await _deviceCalendarPlugin.retrieveCalendars();
    var calendars = calendarsRes.data ?? <Calendar>[];
    if (calendars.isEmpty) {
      final createRes = await _deviceCalendarPlugin.createCalendar(
        localCalendarName,
        calendarColor: const Color(0xFF5558FF),
        localAccountName: localCalendarName,
      );
      if (createRes.isSuccess == true && createRes.data != null) {
        calendarsRes = await _deviceCalendarPlugin.retrieveCalendars();
        calendars = calendarsRes.data ?? <Calendar>[];
      }
    }

    return calendars;
  }

  // Merge device events into storage (range optional)
  static Future<void> importDeviceEvents(
      {DateTime? start, DateTime? end}) async {
    final permissionsResult = await _deviceCalendarPlugin.hasPermissions();
    print(
        'calendarSync permissionsResult: ${permissionsResult.isSuccess}, ${permissionsResult.data}');
    if (!(permissionsResult.isSuccess == true &&
        permissionsResult.data == true)) {
      final requestResult = await _deviceCalendarPlugin.requestPermissions();
      if (!(requestResult.isSuccess == true && requestResult.data == true)) {
        try {
          TostWidget().errorToast(
              title: 'Calendar sync failed',
              message: 'Calendar permission not granted');
        } catch (_) {}
        return;
      }
    }

    final calendarsRes = await _deviceCalendarPlugin.retrieveCalendars();
    print('calendarSync calendarsRes: ${calendarsRes.data}');
    final calendars = calendarsRes.data;
    if (calendars == null || calendars.isEmpty) {
      return;
    }

    final startRange =
        start ?? DateTime.now().subtract(const Duration(days: 365));
    final endRange = end ?? DateTime.now().add(const Duration(days: 365));

    // Aggregate events from all calendars so holidays and events in other calendars are included
    final List<Event> allDeviceEvents = [];
    for (var cal in calendars) {
      final eventsResult = await _deviceCalendarPlugin.retrieveEvents(cal.id,
          RetrieveEventsParams(startDate: startRange, endDate: endRange));
      final List<Event> deviceEvents = eventsResult.data ?? <Event>[];
      allDeviceEvents.addAll(deviceEvents);
    }

    final Set<String> seenKeys = {};
    for (var de in allDeviceEvents) {
      final id = 'device:${de.eventId}';
      final title = de.title ?? 'Event';
      if (de.start == null) continue;
      final startDt = de.start!;
      final endDt = de.end;

      final bool isAllDay = de.allDay ?? false;
      final DateTime keyStart = isAllDay
          ? DateTime(startDt.year, startDt.month, startDt.day)
          : startDt;
      final DateTime? keyEnd = endDt == null
          ? null
          : (isAllDay ? DateTime(endDt.year, endDt.month, endDt.day) : endDt);
      final String dedupeKey =
          '${title.toLowerCase()}|${keyStart.toIso8601String()}|${keyEnd?.toIso8601String() ?? ''}|${isAllDay ? 'allDay' : 'timed'}';

      if (seenKeys.contains(dedupeKey)) {
        continue;
      }
      seenKeys.add(dedupeKey);

      // detect if event contains meetingId in description
      String? meetingId;
      if (de.description != null && de.description!.contains('CUEvent:')) {
        final parts = de.description!.split('CUEvent:');
        if (parts.length > 1) {
          meetingId = parts[1].split('\n').first.trim();
        }
      }

      final model = CalendarEventModel(
        id: id,
        title: title,
        start: startDt,
        end: endDt,
        allDay: isAllDay,
        source: 'device',
        meetingId: meetingId,
        link: null,
        pin: null,
        deviceEventId: de.eventId,
      );

      // avoid duplicates by device event id
      await _box.put(model.id, model);
    }
  }

  // Write app events (source == 'app') to device calendar; attach marker in description to avoid duplicates
  static Future<void> syncAppEventsToDeviceCalendar() async {
    final calendars = await ensureCalendarsAvailable();
    if (calendars.isEmpty) {
      try {
        TostWidget().errorToast(
            title: 'Calendar sync failed',
            message: 'No device calendars available');
      } catch (_) {}
      return;
    }

    final targetCalendars = _resolveTargetCalendars(calendars);
    if (targetCalendars.isEmpty) {
      try {
        TostWidget().errorToast(
            title: 'Calendar sync failed',
            message: 'No writable calendar available');
      } catch (_) {}
      return;
    }

    final primaryCalendar = targetCalendars.first;
    LocalStorage().setSelectedCalendar(
      calendarId: primaryCalendar.id ?? '',
      calendarName: primaryCalendar.name,
    );

    final appEvents = _box.values.where((e) => e.source == 'app').toList();

    // retrieve existing device events across all calendars to check duplicates
    final now = DateTime.now();
    final Map<String, List<Event>> existingByCalendar = {};
    for (final cal in targetCalendars) {
      final id = cal.id;
      if (id == null) continue;
      final deviceEventsRes = await _deviceCalendarPlugin.retrieveEvents(
          id,
          RetrieveEventsParams(
              startDate: now.subtract(const Duration(days: 365)),
              endDate: now.add(const Duration(days: 365))));
      existingByCalendar[id] = deviceEventsRes.data ?? <Event>[];
    }

    for (var ae in appEvents) {
      // skip if already linked
      if (ae.deviceEventId != null && ae.deviceEventId!.isNotEmpty) continue;

      for (final cal in targetCalendars) {
        final calId = cal.id;
        if (calId == null) continue;
        final existing = existingByCalendar[calId] ?? <Event>[];

        // check if any existing device events contains CUEvent:meetingId
        bool exists = false;
        for (var de in existing) {
          if ((de.description ?? '').contains('CUEvent:${ae.meetingId}')) {
            exists = true;
            break;
          }
        }
        if (exists) continue;

        final newEvent = Event(calId,
            title: ae.title,
            start: tz.TZDateTime.from(ae.start, tz.local),
            end: ae.end != null ? tz.TZDateTime.from(ae.end!, tz.local) : null,
            allDay: ae.allDay,
            description:
                'CUEvent:${ae.meetingId}\nLink:${ae.link ?? ''}\nPin:${ae.pin ?? ''}');

        final res = await _deviceCalendarPlugin.createOrUpdateEvent(newEvent);
        if (res?.isSuccess == true &&
            res?.data?.isNotEmpty == true &&
            (ae.deviceEventId == null || ae.deviceEventId!.isEmpty)) {
          ae.deviceEventId = res!.data!;
          await _box.put(ae.id, ae);
        }

        if (res?.isSuccess != true) {
          final msg = _formatCalendarError(res);
          try {
            TostWidget()
                .errorToast(title: 'Calendar sync failed', message: msg);
          } catch (_) {}
        }
      }
    }
  }

  // Delete all app-origin events from device calendars and clear app events from local Hive storage
  static Future<void> deleteAppEventsFromDeviceCalendarAndClearHive() async {
    final calendars = await ensureCalendarsAvailable();
    if (calendars.isEmpty) return;

    final targetCalendars = _resolveTargetCalendars(calendars);
    if (targetCalendars.isEmpty) return;

    final primaryCalendar = targetCalendars.first;
    LocalStorage().setSelectedCalendar(
      calendarId: primaryCalendar.id ?? '',
      calendarName: primaryCalendar.name,
    );

    final now = DateTime.now();
    final rangeStart = now.subtract(const Duration(days: 3650));
    final rangeEnd = now.add(const Duration(days: 3650));

    for (final cal in targetCalendars) {
      final calId = cal.id;
      if (calId == null) continue;
      try {
        final deviceEventsRes = await _deviceCalendarPlugin.retrieveEvents(
            calId,
            RetrieveEventsParams(startDate: rangeStart, endDate: rangeEnd));
        final events = deviceEventsRes.data ?? <Event>[];
        for (final de in events) {
          if ((de.description ?? '').contains('CUEvent:')) {
            await _deviceCalendarPlugin.deleteEvent(calId, de.eventId!);
          }
        }
      } catch (_) {}
    }

    try {
      TostWidget().successToast(
          title: 'Success',
          message: 'Cleared app calendar events from selected account');
    } catch (_) {}
  }

  // Link a device event id to an existing app event in Hive (so we don't show duplicates)
  static Future<void> linkDeviceEventToAppEvent(
      String meetingId, String deviceEventId) async {
    try {
      final existing = _box.get(meetingId);
      if (existing != null && existing.source == 'app') {
        existing.deviceEventId = deviceEventId;
        await _box.put(existing.id, existing);
      }
    } catch (_) {}
  }

  static String _formatCalendarError(dynamic result) {
    if (result == null) return 'Unknown error while creating device event';

    try {
      final List<String>? errorMessages = result.errorMessages;
      if (errorMessages != null && errorMessages.isNotEmpty) {
        return errorMessages.join(', ');
      }
    } catch (_) {}

    try {
      final errors = result.errors;
      if (errors != null) {
        final messages = <String>[];
        for (final e in errors) {
          final msg = (e as dynamic).errorMessage ?? e.toString();
          if (msg != null && msg.toString().isNotEmpty) {
            messages.add(msg.toString());
          }
        }
        if (messages.isNotEmpty) return messages.join(', ');
      }
    } catch (_) {}

    try {
      final data = result.data;
      if (data != null && data.toString().isNotEmpty) {
        return data.toString();
      }
    } catch (_) {}

    return result.toString();
  }
}
