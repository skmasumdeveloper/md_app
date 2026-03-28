import 'dart:io';

import 'package:cu_app/Api_Provider/api_client.dart';
import 'package:cu_app/Api_Provider/api_response.dart';
import 'package:cu_app/Features/Home/Model/group_list_model.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:dio/dio.dart';

import '../../../Api/urls.dart';

// This repository handles the API calls related to group management, including fetching group lists, getting group details, checking active calls, and updating group details.
class GroupRepo {
  final Dio dio = Dio();
  final localStorage = LocalStorage();
  final _apiClient = ApiClient();

//GET GROUP LIST
  Future<ApiResponse<GroupListModel>> groupListService(
      {String? searchQuery, int? limit, int? offset}) async {
    Map<String, dynamic> reqModel = {
      "searchQuery": searchQuery,
      "limit": limit,
      "offset": offset
    };
    final res = await _apiClient.getRequest(
        endPoint: EndPoints.groupListApi,
        fromJson: (data) => GroupListModel.fromJson(data),
        queryParameters: reqModel);

    if (res.errorMessage != null) {
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse(statusCode: res.statusCode, data: res.data);
    }
  }

  //UPLOAD GROUP WITH FILE OR NON FILE DATA
  Future<ApiResponse<GroupModel>> getGroupDetailsById(
      {required String groupId}) async {
    Map<String, dynamic> reqModel = {"id": groupId};
    final res = await _apiClient.getRequest(
        queryParameters: reqModel,
        endPoint: EndPoints.groupDetailsApi,
        fromJson: (data) => GroupModel.fromJson(data['data']));
    if (res.errorMessage != null) {
      return ApiResponse<GroupModel>(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse<GroupModel>(
          statusCode: res.statusCode, data: res.data);
    }
  }

// This method checks if there is an active call in the group by its ID.
  Future<ApiResponse<Map<String, dynamic>>> checkActiveCall(
      {required String groupId}) async {
    try {
      final res = await _apiClient.getRequest(
          endPoint: EndPoints.checkActiveCall,
          queryParameters: {"group_id": groupId},
          fromJson: (data) => data);

      if (res.errorMessage != null) {
        return ApiResponse(
            statusCode: res.statusCode, errorMessage: res.errorMessage);
      } else {
        return ApiResponse(statusCode: res.statusCode, data: res.data);
      }
    } catch (e) {
      return ApiResponse(
        statusCode: 500,
        errorMessage: e.toString(),
      );
    }
  }

// This method updates the group details, including the group name, description, and image.
  Future<ApiResponse<Map<String, dynamic>>> updateGroupDetails(
      {required String groupId,
      required String groupName,
      File? groupImage,
      required String groupDes}) async {
    Map<String, dynamic> reqModel = {
      "groupId": groupId,
      "groupName": groupName,
      "groupDescription": groupDes
    };
    final res = await _apiClient.uploadImage(
        endPoint: EndPoints.updateGroupDetails,
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

  /// DELETE group by id (admin endpoint)
  Future<ApiResponse<Map<String, dynamic>>> deleteGroupById(
      {required String groupId}) async {
    final res = await _apiClient.deleteRequest(
        endPoint: EndPoints.deleteGroup, queryParameters: {"id": groupId});
    if (res.errorMessage != null) {
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse(statusCode: res.statusCode, data: res.data);
    }
  }
}
