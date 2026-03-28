import 'package:cu_app/Api_Provider/api_client.dart';
import 'package:cu_app/Api_Provider/api_response.dart';
import 'package:dio/dio.dart';

import '../../../Api/urls.dart';
import '../../../Utils/storage_service.dart';

// This repository handles the editing of meetings by interacting with the API.
class EditMeetingRepo {
  final Dio dio = Dio();
  final localStorage = LocalStorage();
  final _apiClient = ApiClient();

  // This method edits an existing meeting by sending a request to the API with the updated meeting details.
  Future<ApiResponse<Map<String, dynamic>>> editScheduledMeeting(
      {required String groupId,
      required String groupName,
      required String groupDes,
      required String meetingStartTime,
      required String meetingEndTime}) async {
    Map<String, dynamic> reqModel = {
      "groupId": groupId,
      "groupName": groupName,
      "groupDescription": groupDes,
      "meetingStartTime": meetingStartTime,
      "meetingEndTime": meetingEndTime
    };
    final res = await _apiClient.uploadImage(
      endPoint: EndPoints.editMeeting,
      reqModel: reqModel,
      imageFile: null,
      imageFieldName: "file",
      fromJson: (data) => data,
    );
    if (res.errorMessage != null) {
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse(statusCode: res.statusCode, data: res.data);
    }
  }
}
