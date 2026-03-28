import 'package:cu_app/Api/urls.dart';
import 'package:cu_app/Features/ReportScreen/Model/user_report_model.dart';
import 'package:cu_app/Features/Splash/Model/get_started_response_model.dart';
import 'package:cu_app/Models/send_notification_model.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:dio/dio.dart';

class ApiProvider {
  final Dio _dio = Dio();

  ///--------- Fetch CMS Get Started  -----///
  Future<ResponseGetStarted> getStarted(
      RequestGetStarted requestGetStarted) async {
    try {
      Response response = await _dio.post(Urls.baseUrl + Urls.cmsGetStarted,
          data: requestGetStarted.toJson());
      return response.statusCode == 200
          ? ResponseGetStarted.fromJson(response.data)
          : throw Exception('Something Went Wrong');
    } catch (error) {
      return ResponseGetStarted.withError(
          "You're offline. Please check your Internet connection.");
    }
  }

  ///--------- User Report Api Call  -----///
  Future<UserReportResponseModel> userReport(
      Map<String, dynamic> requestUserReport) async {
    try {
      Response response =
          await _dio.post(Urls.baseUrl + Urls.report, data: requestUserReport);
      return response.statusCode == 200
          ? UserReportResponseModel.fromJson(response.data)
          : throw Exception('Something Went Wrong');
    } catch (error) {
      return UserReportResponseModel.withError(
          "You're offline. Please check your Internet connection.");
    }
  }

  ///--------- Send Notification Api Call  -----///
  Future<ResponseSendNotification> sendNotification(
      RequestSendNotification requestSendNotification) async {
    try {
      Response response = await _dio.post(Urls.sendPushNotificationUrl,
          data: requestSendNotification.toJson());
      return response.statusCode == 200
          ? ResponseSendNotification.fromJson(response.data)
          : throw Exception('Something Went Wrong');
    } catch (error) {
      return ResponseSendNotification.withError(
          "You're offline. Please check your Internet connection.");
    }
  }

  ///--------- Forget password-----///

  Future<Map> forgetPassword(String email) async {
    Map<String, dynamic> reqModel = {"email": email.trim()};
    try {
      _dio.options.headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      Response response =
          await _dio.post(Urls.forgetPasswordurl, data: reqModel);
      return response.statusCode == 200
          ? response.data
          : throw Exception('Something Went Wrong');
    } catch (e) {
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.unknown) {
          return {"status": false, "message": e.response!.data['message']};
          // throw Exception("No Internet connection or network error");
        } else if (e.type == DioExceptionType.badResponse) {
          // throw Exception("Faild to load data");
          return {"status": false, "message": e.response!.data['message']};
        }
      }
      return {"status": false, "message": "Something went wrong"};
    }
  }

  ///--------- Forget password-----///

  Future<Map> verifyOtp({required String email, required String otp}) async {
    Map<String, dynamic> reqModel = {"email": email.trim(), "otp": otp.trim()};
    try {
      _dio.options.headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      Response response = await _dio.post(Urls.verifyOtp, data: reqModel);
      return response.statusCode == 200
          ? response.data
          : throw Exception('Something Went Wrong');
    } catch (e) {
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.unknown) {
          return {"status": false, "message": e.response!.data['message']};
          // throw Exception("No Internet connection or network error");
        } else if (e.type == DioExceptionType.badResponse) {
          // throw Exception("Faild to load data");
          return {"status": false, "message": e.response!.data['message']};
        }
      }
      return {"status": false, "message": "Something went wrong"};
    }
  }

  ///--------- reset password-----///

  Future<Map> resetpassword(
      {required String email,
      required String password,
      required String cnfPassword,
      required String slug}) async {
    Map<String, dynamic> reqModel = {
      "email": email.trim(),
      "slug": slug,
      "password": password.trim(),
      "confirmPassword": cnfPassword.trim()
    };
    try {
      _dio.options.headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      Response response = await _dio.post(Urls.resetPassword, data: reqModel);
      return response.statusCode == 200
          ? response.data
          : throw Exception('Something Went Wrong');
    } catch (e) {
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.unknown) {
          return {"status": false, "message": e.response!.data['error']};
          // throw Exception("No Internet connection or network error");
        } else if (e.type == DioExceptionType.badResponse) {
          // throw Exception("Faild to load data");
          return {"status": false, "message": e.response!.data['error']};
        }
      }
      return {"status": false, "message": "Something went wrong"};
    }
  }

  ///--------- Change Password-----///
  Future<Map> changePassword({required Map<String, dynamic> reqModel}) async {
    var token = LocalStorage().getUserToken();
    Response response;
    try {
      _dio.options.headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'access-token': token
      };
      response = await _dio.post(ApiPath.changePassword, data: reqModel);
      return response.statusCode == 200
          ? response.data
          : throw Exception('Something Went Wrong');
    } catch (e) {
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.unknown) {
          return {"status": false, "message": e.response!.data['error']};
          // throw Exception("No Internet connection or network error");
        } else if (e.type == DioExceptionType.badResponse) {
          // throw Exception("Faild to load data");
          return {"status": false, "message": e.response!.data['error']};
        }
      }
      return {"status": false, "message": "Something went wrong"};
    }
  }
}
