import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../model/guest_meeting_model.dart';
import '../repo/guest_meeting_repo.dart';
import '../../../Widgets/toast_widget.dart';

class GuestMeetingController extends GetxController {
  GuestMeetingController({this.autoFetchList = true});

  final bool autoFetchList;
  final _repo = GuestMeetingRepo();

  RxList<GuestMeeting> guestMeetings = <GuestMeeting>[].obs;
  RxBool isLoading = false.obs;
  RxString searchText = ''.obs;
  final searchController = TextEditingController();

  // Guest inputs + list
  final guestNameController = TextEditingController();
  final guestEmailController = TextEditingController();
  final RxList<GuestParticipant> selectedGuests = <GuestParticipant>[].obs;

  // Meeting form controllers
  final subjectController = TextEditingController();
  final descriptionController = TextEditingController();

  // Date/time and duration
  Rx<DateTime?> selectedStartDate = Rx<DateTime?>(null);
  Rx<TimeOfDay?> selectedStartTime = Rx<TimeOfDay?>(null);
  RxInt selectedDurationMinutes = 15.obs;
  final List<int> durationOptions = [
    15,
    20,
    25,
    30,
    35,
    40,
    45,
    50,
    55,
    60,
    90,
    120
  ];

  // Selected meeting for details/edit
  Rx<GuestMeeting?> selectedMeeting = Rx<GuestMeeting?>(null);

  // Guest PIN flow
  final pinController = TextEditingController();
  final pinEmailController = TextEditingController();
  Rx<GuestMeeting?> pinMeeting = Rx<GuestMeeting?>(null);
  Rx<GuestParticipant?> pinMatchedGuest = Rx<GuestParticipant?>(null);
  RxBool isPinLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    if (autoFetchList) {
      getGuestMeetings();
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    guestNameController.dispose();
    guestEmailController.dispose();
    subjectController.dispose();
    descriptionController.dispose();
    pinController.dispose();
    pinEmailController.dispose();
    super.onClose();
  }

  Future<void> getGuestMeetings({bool isLoadingShow = true}) async {
    try {
      isLoadingShow ? isLoading(true) : isLoading(false);
      final res =
          await _repo.getGuestMeetingsList(searchQuery: searchText.value);
      if (res.errorMessage != null) {
        TostWidget().errorToast(title: 'Error', message: res.errorMessage!);
      } else {
        final list = res.data ?? [];
        list.sort((a, b) => (b.serialKey ?? 0).compareTo(a.serialKey ?? 0));
        guestMeetings.assignAll(list);
      }
    } catch (e) {
      TostWidget().errorToast(title: 'Error', message: e.toString());
    } finally {
      isLoading(false);
    }
  }

  bool _isValidEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return false;
    return GetUtils.isEmail(email);
  }

  bool addGuestToMeeting() {
    final name = guestNameController.text.trim();
    final email = guestEmailController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      TostWidget().errorToast(
        title: 'Validation',
        message: 'Enter guest name and email',
      );
      return false;
    }

    if (!_isValidEmail(email)) {
      TostWidget().errorToast(
        title: 'Validation',
        message: 'Enter a valid guest email',
      );
      return false;
    }

    final normalizedEmail = email.toLowerCase();
    final alreadyExists = selectedGuests.any(
      (g) => (g.email ?? '').trim().toLowerCase() == normalizedEmail,
    );

    if (alreadyExists) {
      TostWidget().errorToast(
        title: 'Validation',
        message: 'Guest email already added',
      );
      return false;
    }

    selectedGuests.add(GuestParticipant(name: name, email: email));
    guestNameController.clear();
    guestEmailController.clear();
    return true;
  }

  void removeGuestAt(int index) {
    if (index < 0 || index >= selectedGuests.length) return;
    selectedGuests.removeAt(index);
  }

  void clearForm() {
    guestNameController.clear();
    guestEmailController.clear();
    selectedGuests.clear();
    subjectController.clear();
    descriptionController.clear();
    selectedStartDate.value = null;
    selectedStartTime.value = null;
    selectedDurationMinutes.value = 15;
  }

  void clearPinSearch() {
    pinController.clear();
    pinEmailController.clear();
    pinMeeting.value = null;
    pinMatchedGuest.value = null;
  }

  String? _composeStartIso() {
    final date = selectedStartDate.value;
    final time = selectedStartTime.value;
    if (date == null || time == null) return null;
    final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    return dt.toUtc().toIso8601String();
  }

  Future<bool> createGuestMeeting() async {
    final startIso = _composeStartIso();

    if (subjectController.text.trim().isEmpty || startIso == null) {
      TostWidget().errorToast(
          title: 'Validation', message: 'Please complete required fields');
      return false;
    }

    if (selectedGuests.isEmpty) {
      TostWidget()
          .errorToast(title: 'Validation', message: 'Add at least one guest');
      return false;
    }

    final start = DateTime.parse(startIso);

    // Ensure meeting start is in the future (UTC comparison)
    final nowUtc = DateTime.now().toUtc();
    if (!start.isAfter(nowUtc)) {
      TostWidget().errorToast(
        title: 'Validation',
        message: 'Meeting start time must be in the future',
      );
      return false;
    }

    final end = start.add(Duration(minutes: selectedDurationMinutes.value));

    final payload = {
      'guests': selectedGuests
          .map((g) => {
                'name': (g.name ?? '').trim(),
                'email': (g.email ?? '').trim(),
              })
          .toList(),
      'groupName': subjectController.text.trim(),
      'meetingStartTime': start.toUtc().toIso8601String(),
      'meetingEndTime': end.toUtc().toIso8601String(),
      'groupDescription': descriptionController.text.trim(),
    };

    try {
      isLoading(true);
      final res = await _repo.createGuestMeeting(reqModel: payload);
      if (res.errorMessage != null) {
        TostWidget().errorToast(title: 'Error', message: res.errorMessage!);
        return false;
      } else if (res.data != null && res.data!.data != null) {
        getGuestMeetings(isLoadingShow: false);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      TostWidget().errorToast(title: 'Error', message: e.toString());
      return false;
    } finally {
      isLoading(false);
    }
  }

  Future<void> setSelectedMeeting(GuestMeeting meeting) async {
    selectedMeeting.value = meeting;
  }

  Future<bool> updateGuestMeeting() async {
    final meeting = selectedMeeting.value;
    if (meeting == null) return false;

    try {
      if (meeting.endTime != null &&
          DateTime.now().toUtc().isAfter(DateTime.parse(meeting.endTime!))) {
        TostWidget().errorToast(
          title: 'Validation',
          message: 'Expired meeting cannot be edited',
        );
        return false;
      }
    } catch (_) {}

    final startIso = _composeStartIso() ?? meeting.startTime;
    if (startIso == null) {
      TostWidget().errorToast(
          title: 'Validation', message: 'Meeting start time is required');
      return false;
    }

    final start = DateTime.parse(startIso);
    final end = start.add(Duration(minutes: selectedDurationMinutes.value));

    final guestsForUpdate = selectedGuests.isNotEmpty
        ? selectedGuests
        : List<GuestParticipant>.from(meeting.guests);

    if (guestsForUpdate.isEmpty) {
      TostWidget()
          .errorToast(title: 'Validation', message: 'Add at least one guest');
      return false;
    }

    final payload = {
      '_id': meeting.id,
      'topic': subjectController.text.trim().isEmpty
          ? meeting.topic
          : subjectController.text.trim(),
      'description': descriptionController.text.trim().isEmpty
          ? meeting.description
          : descriptionController.text.trim(),
      'guest': guestsForUpdate
          .map((g) => {
                if (g.id != null && g.id!.isNotEmpty) '_id': g.id,
                'name': (g.name ?? '').trim(),
                'email': (g.email ?? '').trim(),
              })
          .toList(),
      'startTime': start.toUtc().toIso8601String(),
      'endTime': end.toUtc().toIso8601String(),
    };

    try {
      isLoading(true);
      final res = await _repo.updateGuestMeeting(reqModel: payload);
      if (res.errorMessage != null) {
        TostWidget().errorToast(title: 'Error', message: res.errorMessage!);
        return false;
      } else if (res.data != null && res.data!.data != null) {
        await getGuestMeetings(isLoadingShow: false);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      TostWidget().errorToast(title: 'Error', message: e.toString());
      return false;
    } finally {
      isLoading(false);
    }
  }

  Future<bool> fetchGuestMeetingByPin() async {
    final pin = pinController.text.trim();
    final email = pinEmailController.text.trim();

    if (pin.isEmpty) {
      TostWidget()
          .errorToast(title: 'Validation', message: 'Enter meeting PIN');
      return false;
    }

    if (!_isValidEmail(email)) {
      TostWidget().errorToast(
          title: 'Validation', message: 'Enter a valid guest email');
      return false;
    }

    try {
      isPinLoading(true);
      final res = await _repo.getGuestMeetingByPin(pin: pin, email: email);
      if (res.errorMessage != null) {
        TostWidget().errorToast(title: 'Error', message: res.errorMessage!);
        return false;
      }

      if (res.data != null) {
        pinMeeting.value = res.data;
        pinMatchedGuest.value =
            res.data!.findGuestByEmail(email) ?? GuestParticipant(email: email);
        return true;
      }
      return false;
    } catch (e) {
      TostWidget().errorToast(title: 'Error', message: e.toString());
      return false;
    } finally {
      isPinLoading(false);
    }
  }

  void populateFormForEdit(GuestMeeting meeting) {
    guestNameController.clear();
    guestEmailController.clear();

    selectedGuests.assignAll(
      meeting.guests
          .map((e) => GuestParticipant(id: e.id, name: e.name, email: e.email))
          .toList(),
    );

    subjectController.text = meeting.topic ?? '';
    descriptionController.text = meeting.description ?? '';

    try {
      if (meeting.startTime != null) {
        final dt = DateTime.parse(meeting.startTime!).toLocal();
        selectedStartDate.value = DateTime(dt.year, dt.month, dt.day);
        selectedStartTime.value = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }

      if (meeting.startTime != null && meeting.endTime != null) {
        final s = DateTime.parse(meeting.startTime!).toUtc();
        final e = DateTime.parse(meeting.endTime!).toUtc();
        final diff = e.difference(s).inMinutes;
        if (diff > 0) {
          selectedDurationMinutes.value = diff;
        }
      }
    } catch (_) {}
  }
}
