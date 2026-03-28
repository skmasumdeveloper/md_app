// This file contains the ApiResponse class used for handling API responses in the application.
class ApiResponse<T> {
  final T? data;
  final int statusCode;
  final String? errorMessage;

  ApiResponse({this.data, required this.statusCode, this.errorMessage});
}
