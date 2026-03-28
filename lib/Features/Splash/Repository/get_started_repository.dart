import 'package:cu_app/Features/Splash/Model/get_started_response_model.dart';

import '../../../Api/api_provider.dart';

// This repository handles the Get Started functionality by interacting with the API provider.
class GetStartedRepository {
  final apiProvider = ApiProvider();

  Future<ResponseGetStarted> getStarted(RequestGetStarted requestGetStarted) {
    return apiProvider.getStarted(requestGetStarted);
  }
}

class NetworkError extends Error {}
