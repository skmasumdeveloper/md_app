import 'package:cu_app/Api_Provider/api_client.dart';
import 'package:cu_app/Api_Provider/api_response.dart';
import 'package:cu_app/Api/urls.dart';
import 'package:cu_app/Features/EditMember/model/edit_member_model.dart';

// This repository handles the API calls related to editing member details.
class EditMemberRepo {
  final _apiClient = ApiClient();

// Fetches a single user by ID from the API
  Future<ApiResponse<EditMember>> getSingleUser(String userId) async {
    final response = await _apiClient.getRequest<EditMember>(
      endPoint: '${EndPoints.getSingleUser}?id=$userId',
      fromJson: (data) => EditMember.fromJson(data),
    );

    if (response.errorMessage != null) {
      return ApiResponse<EditMember>(
        statusCode: response.statusCode,
        errorMessage: response.errorMessage,
      );
    } else {
      return ApiResponse<EditMember>(
        data: response.data,
        statusCode: response.statusCode,
      );
    }
  }

// Updates user details in the API
  Future<ApiResponse<EditMember>> updateUserDetails({
    required String id,
    required String name,
    required String email,
    required String phone,
    required String password,
    required String userType,
    required String accountStatus,
  }) async {
    final requestData = {
      '_id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'userType': userType,
      'accountStatus': accountStatus,
    };

    final response = await _apiClient.postRequest<EditMember>(
      endPoint: EndPoints.updateUserDetails,
      fromJosn: (data) => EditMember.fromJson(data),
      reqModel: requestData,
    );

    if (response.errorMessage != null) {
      return ApiResponse<EditMember>(
        statusCode: response.statusCode,
        errorMessage: response.errorMessage,
      );
    } else {
      return ApiResponse<EditMember>(
        data: response.data,
        statusCode: response.statusCode,
      );
    }
  }
}
