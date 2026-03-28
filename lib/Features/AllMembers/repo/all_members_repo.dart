import 'package:cu_app/Api_Provider/api_client.dart';
import 'package:cu_app/Api_Provider/api_response.dart';
import 'package:cu_app/Api/urls.dart';
import 'package:cu_app/Features/AllMembers/model/all_members_model.dart';
import 'package:cu_app/Features/Home/Model/group_list_model.dart';

/// This repository handles the API calls related to fetching and managing all members.
class AllMembersRepo {
  final _apiClient = ApiClient();

// Fetch all members from the API
  Future<ApiResponse<AllMembersModel>> getAllMembers(
      {String? searchQuery, int? limit, int? offset}) async {
    Map<String, dynamic> reqModel = {
      "searchQuery": searchQuery,
      "limit": limit,
      "offset": offset
    };

    final response = await _apiClient.postRequest<AllMembersModel>(
        endPoint: EndPoints.getAllMembers,
        fromJosn: (data) => AllMembersModel.fromJson(data),
        reqModel: reqModel);

    if (response.errorMessage != null) {
      return ApiResponse<AllMembersModel>(
        statusCode: response.statusCode,
        errorMessage: response.errorMessage,
      );
    } else {
      return ApiResponse<AllMembersModel>(
        data: response.data,
        statusCode: response.statusCode,
      );
    }
  }

  // Create or get direct chat
  Future<ApiResponse<GroupModel>> createDirectChat(String targetUserId) async {
    Map<String, dynamic> reqModel = {
      "targetUserId": targetUserId,
    };

    final response = await _apiClient.postRequest<GroupModel>(
      endPoint: EndPoints.createDirectChat,
      fromJosn: (data) => GroupModel.fromJson(data['data']),
      reqModel: reqModel,
    );

    if (response.errorMessage != null) {
      return ApiResponse<GroupModel>(
        statusCode: response.statusCode,
        errorMessage: response.errorMessage,
      );
    } else {
      return ApiResponse<GroupModel>(
        data: response.data,
        statusCode: response.statusCode,
      );
    }
  }

  // delete a member by ID
  Future<ApiResponse<AllMembersModel>> deleteMember(String memberId) async {
    final response = await _apiClient.deleteRequest(
      endPoint: EndPoints.deleteMember,
      queryParameters: {'id': memberId},
    );

    if (response.errorMessage != null) {
      return ApiResponse<AllMembersModel>(
        statusCode: response.statusCode,
        errorMessage: response.errorMessage,
      );
    } else {
      return ApiResponse<AllMembersModel>(
        data: response.data != null
            ? AllMembersModel.fromJson(response.data!)
            : null,
        statusCode: response.statusCode,
      );
    }
  }
}
