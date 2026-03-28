import 'package:cu_app/Api_Provider/api_client.dart';
import 'package:cu_app/Api_Provider/api_response.dart';
import 'package:cu_app/Features/Meetings/Model/meetings_list_model.dart';
import 'package:dio/dio.dart';

import '../../../Api/urls.dart';
import '../../../Utils/storage_service.dart';
import '../Model/meeting_call_details_model.dart';

// This repository handles the API calls related to meetings, including fetching the list of meetings, getting meeting details, and deleting meetings.
class MeetingsRepo {
  final Dio dio = Dio();
  final localStorage = LocalStorage();
  final _apiClient = ApiClient();

  // This method fetches the list of meetings with optional search query, limit, and offset parameters.
  Future<ApiResponse<MeetingsListModel>> getMeetingsList(
      {String? searchQuery, int? limit, int? offset}) async {
    Map<String, dynamic> reqModel = {
      "searchQuery": searchQuery,
      "limit": limit,
      "offset": offset
    };
    final res = await _apiClient.getRequest(
        endPoint: EndPoints.meetingListApi,
        fromJson: (data) => MeetingsListModel.fromJson(data),
        queryParameters: reqModel);

    if (res.errorMessage != null) {
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse(statusCode: res.statusCode, data: res.data);
    }
  }

  // This method fetches the details of a specific meeting call by its ID.
  Future<ApiResponse<MeetingGroupCallDetails>> getMeetingCallDetails(
      {String? id}) async {
    Map<String, dynamic> reqModel = {
      "id": id,
    };
    final res = await _apiClient.getRequest(
        endPoint: EndPoints.meetingCallDetails,
        fromJson: (data) => MeetingGroupCallDetails.fromJson(data),
        queryParameters: reqModel);

    if (res.errorMessage != null) {
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse(statusCode: res.statusCode, data: res.data);
    }
  }

  // This method fetches the details of a specific meeting group by its ID.
  Future<ApiResponse<MeetingModel>> getMeetingGroupDetails(
      {required String groupId}) async {
    Map<String, dynamic> reqModel = {"id": groupId};
    final res = await _apiClient.getRequest(
        queryParameters: reqModel,
        endPoint: EndPoints.groupDetailsApi,
        fromJson: (data) => MeetingModel.fromJson(data['data']));
    if (res.errorMessage != null) {
      return ApiResponse<MeetingModel>(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse<MeetingModel>(
          statusCode: res.statusCode, data: res.data);
    }
  }

  // delete meeting
  Future<ApiResponse<Map<String, dynamic>>> deleteMeeting(
      {required String id}) async {
    Map<String, dynamic> reqModel = {"id": id};
    final res = await _apiClient.deleteRequest(
        endPoint: EndPoints.deleteGroup, queryParameters: reqModel);
    if (res.errorMessage != null) {
      return ApiResponse<Map<String, dynamic>>(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse<Map<String, dynamic>>(
          data: res.data!,
          statusCode: res.statusCode,
          errorMessage: res.errorMessage);
    }
  }

  // Group action: accept or reject meeting invite
  Future<ApiResponse<UserAction>> groupAction(
      {required String groupId,
      required String action,
      required String userId,
      String actionDescription = ""}) async {
    final reqModel = {
      "groupId": groupId,
      "action": action,
      "userId": userId,
      "actionDescription": actionDescription,
    };

    final res = await _apiClient.postRequest(
        endPoint: EndPoints.groupAction,
        reqModel: reqModel,
        fromJosn: (data) => UserAction.fromJson(data['data']));

    if (res.errorMessage != null) {
      return ApiResponse<UserAction>(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse<UserAction>(
          statusCode: res.statusCode, data: res.data);
    }
  }

  // This method fetches the list of meetings with optional search query, limit, and offset parameters.
  Future<ApiResponse<MeetingsListModel>> getCalendarMeetingsList(
      {int? limit, String? slug, dynamic? startDate, dynamic? endDate}) async {
    Map<String, dynamic> reqModel = {
      "limit": limit,
      "slug": slug,
      "startDate": startDate,
      "endDate": endDate
    };
    final res = await _apiClient.getRequest(
        endPoint: EndPoints.meetingListApi,
        fromJson: (data) => MeetingsListModel.fromJson(data),
        queryParameters: reqModel);

    if (res.errorMessage != null) {
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse(statusCode: res.statusCode, data: res.data);
    }
  }
}
