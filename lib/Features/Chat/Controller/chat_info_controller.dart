import 'package:cu_app/Features/Chat/Repo/chat_repo.dart';
import 'package:get/get.dart';

import '../Model/chat_info_model.dart';

// This controller handles the logic for fetching chat information based on a message ID.
class ChatInfoController extends GetxController {
  final chatRepo = ChatRepo();
  RxBool isLoading = false.obs;
  RxString errorMessage = "".obs;
  Rx<ChatInfoModel?> chatInfoModel = Rx<ChatInfoModel?>(null);

// This method fetches chat information based on the provided message ID.
  chatInfo({required String msgId, bool isRefresh = true}) async {
    if (msgId.isEmpty) {
      return;
    }
    errorMessage.value = "";
    Map<String, dynamic> reqModel = {"msgId": msgId};
    try {
      isRefresh ? isLoading(true) : null;
      final res = await chatRepo.chatInfo(reqModel: reqModel);
      if (res.errorMessage != null) {
        errorMessage.value = res.errorMessage ?? "";
      }
      if (res.data!.success == true) {
        chatInfoModel.value = res.data!;
      } else {
        errorMessage.value = res.data!.message ?? "";
        chatInfoModel.value = ChatInfoModel();
      }
    } finally {
      isLoading(false);
    }
  }
}
