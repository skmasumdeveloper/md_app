import 'package:cu_app/Api_Provider/api_client.dart';
import 'package:cu_app/Api_Provider/api_response.dart';
import 'package:cu_app/Features/Meetings/Model/create_meeting_model.dart';
import 'package:dio/dio.dart';

import '../../../Api/urls.dart';
import '../../../Utils/storage_service.dart';

// This repository handles the creation of meetings by interacting with the API.
class CreateMeetingRepo {
  final Dio dio = Dio();
  final localStorage = LocalStorage();
  final _apiClient = ApiClient();

  // This method creates a new meeting by sending a request to the API with the provided meeting details.
  Future<ApiResponse<CreateMeetingResponse>> createScheduledMeeting({
    required CreateMeetingRequest request,
  }) async {
    final res = await _apiClient.postRequest(
      endPoint: EndPoints.createNewGroup,
      reqModel: request.toJson(),
      fromJosn: (data) => CreateMeetingResponse.fromJson(data),
    );

    if (res.errorMessage != null) {
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse(statusCode: res.statusCode, data: res.data);
    }
  }
}
