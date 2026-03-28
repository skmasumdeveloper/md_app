import 'dart:io';

import 'package:cu_app/Api/urls.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
// import 'package:talker/talker.dart';
// import 'package:talker_dio_logger/talker_dio_logger.dart';

import '../Utils/storage_service.dart';
import 'api_response.dart';

class ApiClient {
  final Dio _dio = Dio();

  // Constructor to initialize Dio with base URL and interceptors
  ApiClient() {
    _dio.options.baseUrl = ApiPath.baseUrls;
    _dio.options.connectTimeout = const Duration(seconds: 60);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.responseType = ResponseType.json;
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      String token = LocalStorage().getUserToken();
      // print('my token: $token');
      if (token.isNotEmpty) {
        options.headers['access-token'] = token;
      }
      return handler.next(options);
    }, onError: (DioException e, handler) {
      if (e.response?.statusCode == 401) {}
      return handler.next(e);
    }));
    // _dio.interceptors.add(
    //   // TalkerDioLogger(
    //   //   settings: TalkerDioLoggerSettings(
    //   //     printResponseData: true,
    //   //     printErrorMessage: true,
    //   //     printRequestData: true,
    //   //     printErrorData: true,
    //   //     requestPen: AnsiPen()..yellow(),
    //   //     responsePen: AnsiPen()..green(),
    //   //     errorPen: AnsiPen()..red(),
    //   //   ),
    //   // ),
    //   LogInterceptor(
    //     requestBody: true,
    //     responseBody: true, // set false for speed
    //   ),
    // );

    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        // Simple caching example
        // Save to local storage if needed
        handler.next(response);
      },
    ));
  }

  // API request method GET
  Future<ApiResponse<T>> getRequest<T>(
      {required String endPoint,
      required T Function(Map<String, dynamic>) fromJson,
      Map<String, dynamic>? queryParameters}) async {
    try {
      final response =
          await _dio.get(endPoint, queryParameters: queryParameters);
      final data = fromJson(response.data);
      return ApiResponse<T>(data: data, statusCode: response.statusCode ?? 0);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? 0;
      final errorMessage = _handleDioError(e, statusCode);
      return ApiResponse<T>(statusCode: statusCode, errorMessage: errorMessage);
    }
  }

  // API request method GET for List
  Future<ApiResponse<List<T>>> getRequestList<T>(
      {required String endPoint,
      required List<T> Function(List<dynamic>) fromJosnList,
      Map<String, dynamic>? queryParameters}) async {
    try {
      final response =
          await _dio.get(endPoint, queryParameters: queryParameters);
      final data = fromJosnList(response.data);
      return ApiResponse<List<T>>(
          data: data, statusCode: response.statusCode ?? 0);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? 0;
      final errorMessage = _handleDioError(e, statusCode);
      return ApiResponse<List<T>>(
          statusCode: statusCode, errorMessage: errorMessage);
    }
  }

  // API request method POST
  Future<ApiResponse<T>> postRequest<T>(
      {required String endPoint,
      Map<String, dynamic>? reqModel,
      required T Function(Map<String, dynamic>) fromJosn}) async {
    try {
      final response = await _dio.post(endPoint, data: reqModel);
      final data = fromJosn(response.data);
      return ApiResponse<T>(data: data, statusCode: response.statusCode ?? 0);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? 0;
      final errorMessage = _handleDioError(e, statusCode);
      return ApiResponse<T>(statusCode: statusCode, errorMessage: errorMessage);
    }
  }

  // API request method POST for List
  Future<ApiResponse<List<T>>> postRequestList<T>(
      {required String endPoint,
      Map<String, dynamic>? reqModel,
      required List<T> Function(List<dynamic>) fromJosnList}) async {
    try {
      final response = await _dio.post(endPoint, data: reqModel);
      final data = fromJosnList(response.data);
      return ApiResponse<List<T>>(
          data: data, statusCode: response.statusCode ?? 0);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? 0;
      final errorMessage = _handleDioError(e, statusCode);
      return ApiResponse<List<T>>(
          statusCode: statusCode, errorMessage: errorMessage);
    }
  }

  // API request method DELETE
  Future<ApiResponse<Map<String, dynamic>>> deleteRequest(
      {required String endPoint, Map<String, dynamic>? queryParameters}) async {
    try {
      final response =
          await _dio.delete(endPoint, queryParameters: queryParameters);
      final data = response.data as Map<String, dynamic>;
      return ApiResponse<Map<String, dynamic>>(
          data: data, statusCode: response.statusCode ?? 0);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? 0;
      final errorMessage = _handleDioError(e, statusCode);
      return ApiResponse<Map<String, dynamic>>(
          statusCode: statusCode, errorMessage: errorMessage);
    }
  }

  // API request method for uploading images
  Future<ApiResponse<T>> uploadImage<T>({
    required String endPoint,
    File? imageFile, // Make this nullable
    Map<String, dynamic>? reqModel,
    required T Function(Map<String, dynamic>) fromJson,
    required String imageFieldName,
  }) async {
    try {
      // Prepare the form data
      Map<String, dynamic> formDataMap = {
        ...?reqModel
      }; // Spread reqModel if it's not null

      // If imageFile is provided, add it to the form data
      if (imageFile != null) {
        String fileName = imageFile.path.split('/').last;
        formDataMap[imageFieldName] =
            await MultipartFile.fromFile(imageFile.path, filename: fileName);
      }

      FormData formData = FormData.fromMap(formDataMap);

      // Make the POST request
      final response = await _dio.post(endPoint, data: formData);

      // Parse the response
      final responseData = fromJson(response.data);

      return ApiResponse<T>(
        data: responseData,
        statusCode: response.statusCode ?? 0,
      );
    } on DioException catch (e) {
      // Handle Dio errors
      final statusCode = e.response?.statusCode ?? 0;
      final errorMessage = _handleDioError(e, statusCode);

      return ApiResponse<T>(
        statusCode: statusCode,
        errorMessage: errorMessage,
      );
    }
  }

  // Handle Dio errors and return a user-friendly message
  String _handleDioError(DioException error, int statusCode) {
    String errorMessage;
    switch (error.type) {
      case DioExceptionType.cancel:
        errorMessage = "Request to API server was cancelled";
        break;
      case DioExceptionType.connectionTimeout:
        errorMessage = "Connection timeout with API server";
        break;
      case DioExceptionType.receiveTimeout:
        errorMessage = "Receive timeout in connection with API server";
        break;
      case DioExceptionType.sendTimeout:
        errorMessage = "Send timeout in connection with API server";
        break;
      case DioExceptionType.badResponse:
        errorMessage = _handleStatusCode(statusCode);
        break;
      case DioExceptionType.unknown:
        errorMessage =
            "Connection to API server failed due to internet connection";
        break;
      default:
        errorMessage = "Unexpected error occurred";
        break;
    }
    return errorMessage;
  }

  // Handle different status codes and return appropriate messages
  String _handleStatusCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return "Bad Request";
      case 401:
        return "Unauthorized";
      case 403:
        return "Forbidden";
      case 404:
        return "Not Found";
      case 500:
        _showInternalServerErrorDialog();
        return "Internal Server Error";
      case 503:
        return "Service Unavailable";
      default:
        return "Recive invalid status code $statusCode";
    }
  }

  void _showInternalServerErrorDialog() {
    if (Get.isDialogOpen == true || Get.context == null) {
      return;
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Server Error'),
        content:
            const Text('Internal Server Error (500). Please try again later.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }
}
