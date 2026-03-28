import 'package:cu_app/Api_Provider/api_client.dart';
import 'package:cu_app/Api_Provider/api_response.dart';
import 'package:cu_app/Api/urls.dart';
import 'package:cu_app/Features/AddContact/model/add_contact_model.dart';

// This repository handles the API calls related to adding a new contact.
class AddContactRepo {
  final _apiClient = ApiClient();

  // Check if the user already exists and return user data if found
  Future<ApiResponse<AddContactModel?>> checkUserExists(String email) async {
    final response = await _apiClient.getRequest<AddContactModel?>(
      endPoint: EndPoints.checkUserExists,
      fromJson: (data) => data['success'] == true && data['data'] != null
          ? AddContactModel.fromJson(data)
          : null,
      queryParameters: {'email': email},
    );

    if (response.errorMessage != null) {
      return ApiResponse<AddContactModel?>(
        statusCode: response.statusCode,
        errorMessage: response.errorMessage,
      );
    } else {
      return ApiResponse<AddContactModel?>(
        data: response.data,
        statusCode: response.statusCode,
      );
    }
  }

// Create a new user with the provided details
  Future<ApiResponse<AddContactModel>> createUser({
    required String name,
    required String email,
    required String password,
    required String userType,
  }) async {
    Map<String, dynamic> reqModel = {
      "name": name,
      "email": email,
      "password": password,
      "userType": userType,
    };

    final response = await _apiClient.postRequest<AddContactModel>(
      endPoint: EndPoints.createUser,
      fromJosn: (data) => AddContactModel.fromJson(data),
      reqModel: reqModel,
    );

    if (response.errorMessage != null) {
      return ApiResponse<AddContactModel>(
        statusCode: response.statusCode,
        errorMessage: response.errorMessage,
      );
    } else {
      return ApiResponse<AddContactModel>(
        data: response.data,
        statusCode: response.statusCode,
      );
    }
  }
}
