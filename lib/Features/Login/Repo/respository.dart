import 'dart:io';

import 'package:cu_app/Api_Provider/api_client.dart';
import 'package:cu_app/Api_Provider/api_response.dart';
import 'package:cu_app/Api/urls.dart';
import 'package:cu_app/Features/Login/user_model.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:dio/dio.dart';

import '../Model/user_profle_model.dart';

// This repository handles authentication-related operations such as user login, logout, and profile management.
class AuthRepo {
  final Dio dio = Dio();
  final localStorage = LocalStorage();
  final _apiClient = ApiClient();

// This method logs in the user by sending a request to the server with the provided credentials.
  Future<ApiResponse<UserModel>> userLogin(
      {required Map<String, dynamic> reqModel}) async {
    final response = await _apiClient.postRequest<UserModel>(
        endPoint: EndPoints.userLogin,
        fromJosn: (data) => UserModel.fromJson(data),
        reqModel: reqModel);
    if (response.errorMessage != null) {
      return ApiResponse<UserModel>(
          statusCode: response.statusCode, errorMessage: response.errorMessage);
    } else {
      return ApiResponse<UserModel>(
          data: response.data, statusCode: response.statusCode);
    }
  }

  // This method logs out the user by calling the logout API.
  Future<ApiResponse<Map<String, dynamic>>> userLogout(
      {required Map<String, dynamic> reqModel}) async {
    final response = await _apiClient.postRequest<Map<String, dynamic>>(
        endPoint: EndPoints.logoutApi,
        fromJosn: (data) => data,
        reqModel: reqModel);
    return ApiResponse<Map<String, dynamic>>(
        statusCode: response.statusCode,
        errorMessage: response.errorMessage,
        data: response.data);
  }

  // This method retrieves the user's profile information from the server.
  Future<ApiResponse<UserProfileModel>> getUserProfile() async {
    final response = await _apiClient.getRequest(
        endPoint: EndPoints.getUserProfileData,
        fromJson: (data) => UserProfileModel.fromJson(data));
    if (response.errorMessage != null) {
      return ApiResponse(
          statusCode: response.statusCode, errorMessage: response.errorMessage);
    } else {
      return ApiResponse(statusCode: response.statusCode, data: response.data);
    }
  }

  // This method updates the user's profile information, including status and profile image.
  Future<ApiResponse<Map<String, dynamic>>> updateProfileDetails({
    required String status,
    File? groupImage,
    String? firebaseToken,
    String? applePushToken,
  }) async {
    Map<String, dynamic> reqModel = {
      "accountStatus": status,
      "firebaseToken": firebaseToken,
      "applePushToken": applePushToken,
    };
    final res = await _apiClient.uploadImage(
        endPoint: EndPoints.updateUserProfile,
        reqModel: reqModel,
        imageFile: groupImage,
        fromJson: (data) => data,
        imageFieldName: "file");

    if (res.errorMessage != null) {
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse(statusCode: res.statusCode, data: res.data);
    }
  }
}
