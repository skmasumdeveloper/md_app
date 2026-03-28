import 'package:cu_app/Api_Provider/api_client.dart';
import 'package:cu_app/Api_Provider/api_response.dart';
import 'package:cu_app/Features/GuestMeetingManage/model/guest_meeting_model.dart';

// Guest meeting repository
class GuestMeetingRepo {
  final _apiClient = ApiClient();

  // Create guest meeting
  Future<ApiResponse<CreateGuestMeetingResponse>> createGuestMeeting(
      {required Map<String, dynamic> reqModel}) async {
    final res = await _apiClient.postRequest(
      endPoint: '/groups/create-guest-meeting',
      reqModel: reqModel,
      fromJosn: (data) => CreateGuestMeetingResponse.fromJson(data),
    );

    if (res.errorMessage != null) {
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse(statusCode: res.statusCode, data: res.data);
    }
  }

  // Get guest meetings list (API returns {success,message,data: [...]})
  Future<ApiResponse<List<GuestMeeting>>> getGuestMeetingsList(
      {String searchQuery = '', int offset = 0, int limit = 20}) async {
    final now = DateTime.now();
    final monthStartLocal = DateTime(now.year, now.month, 1);
    final monthEndLocal = DateTime(now.year, now.month + 1, 1)
        .subtract(const Duration(milliseconds: 1));

    final query = {
      if (searchQuery.isNotEmpty) 'searchQuery': searchQuery,
      'startDate': monthStartLocal.toUtc().toIso8601String(),
      'endDate': monthEndLocal.toUtc().toIso8601String(),
    };

    try {
      final res = await _apiClient.getRequest<Map<String, dynamic>>(
        endPoint: '/groups/guest-meeting/getall',
        queryParameters: query,
        fromJson: (data) => Map<String, dynamic>.from(data),
      );

      if (res.errorMessage != null) {
        return ApiResponse(
            statusCode: res.statusCode, errorMessage: res.errorMessage);
      }

      final raw = res.data ?? <String, dynamic>{};
      final listData =
          (raw['data'] is List) ? raw['data'] as List<dynamic> : <dynamic>[];
      final meetings = listData
          .map((e) => GuestMeeting.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse(statusCode: res.statusCode, data: meetings);
    } catch (e) {
      return ApiResponse(statusCode: 0, errorMessage: e.toString());
    }
  }

  // Update guest meeting
  Future<ApiResponse<CreateGuestMeetingResponse>> updateGuestMeeting(
      {required Map<String, dynamic> reqModel}) async {
    final res = await _apiClient.postRequest(
      endPoint: '/groups/update-guest-meeting',
      reqModel: reqModel,
      fromJosn: (data) => CreateGuestMeetingResponse.fromJson(data),
    );

    if (res.errorMessage != null) {
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse(statusCode: res.statusCode, data: res.data);
    }
  }

  // Get guest meeting details by PIN
  Future<ApiResponse<GuestMeeting>> getGuestMeetingByPin(
      {required String pin, required String email}) async {
    try {
      final res = await _apiClient.getRequest<Map<String, dynamic>>(
        endPoint: '/groups/guest-meeting',
        queryParameters: {
          'pin': pin,
          'email': email,
        },
        fromJson: (data) => Map<String, dynamic>.from(data),
      );

      if (res.errorMessage != null) {
        return ApiResponse(
            statusCode: res.statusCode, errorMessage: res.errorMessage);
      }

      final raw = res.data ?? <String, dynamic>{};
      final data = raw['data'];
      if (data is Map<String, dynamic>) {
        return ApiResponse(
            statusCode: res.statusCode, data: GuestMeeting.fromJson(data));
      }
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: 'Guest meeting not found');
    } catch (e) {
      return ApiResponse(statusCode: 0, errorMessage: e.toString());
    }
  }
}
