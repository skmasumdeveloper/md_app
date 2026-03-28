import 'dart:convert';
import 'dart:io';

import 'package:cu_app/Api_Provider/api_client.dart';
import 'package:cu_app/Api_Provider/api_response.dart';
import 'package:cu_app/Api/urls.dart';
import 'package:dio/dio.dart';

import '../../../Utils/storage_service.dart';
import '../Model/chat_info_model.dart';
import '../Model/chat_list_model.dart';

// This repository handles the API calls related to chat functionalities, including fetching chat lists, sending messages, and reporting chats.
class ChatRepo {
  final Dio dio = Dio();
  final localStorage = LocalStorage();
  final _apiClient = ApiClient();

// This method fetches the list of all chats for a user.
  Future<ApiResponse<ChatListModel>> getChatListApi(
      {required Map<String, dynamic> reqModel}) async {
    final res = await _apiClient.postRequest(
        endPoint: EndPoints.getAllChat,
        fromJosn: (data) => ChatListModel.fromJson(data),
        reqModel: reqModel);

    if (res.errorMessage != null) {
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse(statusCode: res.statusCode, data: res.data);
    }
  }

// This method sends a message in a group chat, optionally including a file attachment.
  Future<ApiResponse<Map<String, dynamic>>> sendMessage(
      {required String groupId,
      required String senderName,
      required String message,
      required String messageType,
      required Map<String, dynamic>? replyOf,
      File? file}) async {
    var senderId = localStorage.getUserId();
    Map<String, dynamic> reqModel = {
      "replyOf": jsonEncode(replyOf),
      "groupId": groupId,
      "senderName": senderName,
      "senderId": senderId,
      "message": message,
      "messageType": messageType
    };
    final res = await _apiClient.uploadImage(
        imageFile: file,
        imageFieldName: "file",
        endPoint: EndPoints.sendMessage,
        fromJson: (data) => data,
        reqModel: reqModel);
    if (res.errorMessage != null) {
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse(statusCode: res.statusCode, data: res.data);
    }
  }

// This method reports a group based on the provided group ID and description.
  Future<ApiResponse<Map>> grouopReport(
      {required Map<String, dynamic> reqModel}) async {
    final res = await _apiClient.postRequest(
        endPoint: EndPoints.reportGroup,
        fromJosn: (data) => data,
        reqModel: reqModel);
    if (res.errorMessage != null) {
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse(statusCode: res.statusCode, data: res.data);
    }
  }

// This method reports a message in a group chat based on the provided message ID and group ID.
  Future<ApiResponse<Map>> messageReport(
      {required Map<String, dynamic> reqModel}) async {
    final res = await _apiClient.postRequest(
        endPoint: EndPoints.messageReportApi,
        fromJosn: (data) => data,
        reqModel: reqModel);
    if (res.errorMessage != null) {
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse(statusCode: res.statusCode, data: res.data);
    }
  }

// This method fetches chat information based on the provided message ID.
  Future<ApiResponse<ChatInfoModel>> chatInfo(
      {required Map<String, dynamic> reqModel}) async {
    final res = await _apiClient.postRequest(
        endPoint: EndPoints.chatInfo,
        fromJosn: (data) => data,
        reqModel: reqModel);
    return ApiResponse(
        errorMessage: res.errorMessage,
        statusCode: res.statusCode,
        data: ChatInfoModel.fromJson(res.data ?? {}));
  }

  // Delete message
  Future<ApiResponse<Map>> deleteMessage(
      {required Map<String, dynamic> reqModel}) async {
    final res = await _apiClient.postRequest(
        endPoint: EndPoints.deleteMessage,
        fromJosn: (data) => data,
        reqModel: reqModel);
    if (res.errorMessage != null) {
      return ApiResponse(
          statusCode: res.statusCode, errorMessage: res.errorMessage);
    } else {
      return ApiResponse(statusCode: res.statusCode, data: res.data);
    }
  }
}
