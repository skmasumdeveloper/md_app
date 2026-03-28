import 'package:cu_app/Api_Provider/api_client.dart';
import 'package:cu_app/Api_Provider/api_response.dart';
import 'package:cu_app/Api/urls.dart';

import '../model/call_history_model.dart';

// This repository handles the API calls related to fetching and managing call history.
class CallHistoryRepo {
  final _apiClient = ApiClient();

// Fetch call history from the API
  Future<ApiResponse<GroupCallHistoryModel>> getCallHistory(
      {String? searchQuery, int? limit, int? offset}) async {
    final response = await _apiClient.getRequest<GroupCallHistoryModel>(
      endPoint: EndPoints.getGroupCallsHistory,
      fromJson: (data) => GroupCallHistoryModel.fromJson(data),
    );

    if (response.errorMessage != null) {
      return ApiResponse<GroupCallHistoryModel>(
        statusCode: response.statusCode,
        errorMessage: response.errorMessage,
      );
    } else {
      return ApiResponse<GroupCallHistoryModel>(
        data: response.data,
        statusCode: response.statusCode,
      );
    }
  }
}
