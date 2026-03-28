import 'package:get_storage/get_storage.dart';

// This class provides methods to manage local storage for user data, including user ID, token, and group ID from notifications.

class LocalStorage {
  final GetStorage storage = GetStorage();
  void setUserId({String? userId}) {
    storage.write("userId", userId);
  }

  void setToken({String? token}) {
    storage.write("userToken", token);
  }

  Future<void> setGroupIdFromNotification({String? groupId}) async {
    await storage.write("groupfromnoti", groupId);
  }

  String getGroupIdFromNotification() {
    return storage.read("groupfromnoti") ?? "";
  }

  void setUserName({String? userName}) {
    storage.write("userName", userName);
  }

  String getUserId() {
    return storage.read("userId") ?? "";
  }

  String getUserToken() {
    return storage.read("userToken") ?? "";
  }

  String getUserName() {
    return storage.read("userName") ?? "";
  }

  void deleteAllLocalData() {
    storage.remove("userToken");
    storage.remove("userId");
    storage.remove("userName");
    storage.remove("groupfromnoti");
    storage.remove("isAnyCallActive");
  }

  Future<void> setIsAnyCallActive(bool value) async {
    await storage.write("isAnyCallActive", value);
  }

  Future<bool> getIsAnyCallActive() async {
    return await storage.read("isAnyCallActive") ?? false;
  }

  Future<void> setActiveCallRoomId(String? roomId) async {
    await storage.write("active_call_room_id", roomId ?? "");
  }

  String getActiveCallRoomId() {
    return storage.read("active_call_room_id") ?? "";
  }

  Future<void> clearActiveCallRoomId() async {
    await storage.remove("active_call_room_id");
  }

  // Store the latest callkit UUID for end-call handling
  Future<void> setLatestCallUuid(String? uuid) async {
    await storage.write("latest_call_uuid", uuid);
  }

  String getLatestCallUuid() {
    return storage.read("latest_call_uuid") ?? "";
  }

  Future<void> clearLatestCallUuid() async {
    await storage.remove("latest_call_uuid");
  }

  /// Pending deep link storage
  Future<void> setPendingDeepLink({String? groupId, String? pin}) async {
    await storage.write("pending_deeplink", {"groupId": groupId, "pin": pin});
  }

  Map<String, dynamic>? getPendingDeepLink() {
    final data = storage.read("pending_deeplink");
    if (data == null) return null;
    try {
      return Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPendingDeepLink() async {
    await storage.remove("pending_deeplink");
  }

  void setSelectedCalendar(
      {required String calendarId,
      String? calendarName,
      String? calendarAccount,
      String? calendarType}) {
    storage.write("selectedCalendarId", calendarId);
    if (calendarName != null) {
      storage.write("selectedCalendarName", calendarName);
    }
    if (calendarAccount != null) {
      storage.write("selectedCalendarAccount", calendarAccount);
    }
    if (calendarType != null) {
      storage.write("selectedCalendarType", calendarType);
    }
  }

  String getSelectedCalendarId() {
    return storage.read("selectedCalendarId") ?? "";
  }

  String getSelectedCalendarName() {
    return storage.read("selectedCalendarName") ?? "";
  }

  String getSelectedCalendarAccount() {
    return storage.read("selectedCalendarAccount") ?? "";
  }

  String getSelectedCalendarType() {
    return storage.read("selectedCalendarType") ?? "";
  }
}
