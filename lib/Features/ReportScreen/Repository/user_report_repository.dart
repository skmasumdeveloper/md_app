import 'package:cu_app/Features/ReportScreen/Model/user_report_model.dart';

import '../../../Api/api_provider.dart';

// This repository handles the user report functionality by interacting with the API provider.
class UserReportRepository {
  final apiProvider = ApiProvider();

  Future<UserReportResponseModel> userReport(
      Map<String, dynamic> requestUserReport) {
    return apiProvider.userReport(requestUserReport);
  }
}

class NetworkError extends Error {}
