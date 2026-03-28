import 'package:cu_app/Features/Chat/Repo/chat_repo.dart';
import 'package:cu_app/Utils/navigator.dart';
import 'package:cu_app/Widgets/toast_widget.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

// This controller handles the logic for reporting groups and messages in the application.
class ReportController extends GetxController {
  final _groupRepo = ChatRepo();

  //controller for the report
  var groupReportController = TextEditingController().obs;
  var messageReportController = TextEditingController().obs;

  //loader
  RxBool isGroupReportLoading = false.obs;
  RxBool isMessageReportLoading = false.obs;

// This method reports a group based on the provided group ID and description.
  groupReport({required String groupId, required BuildContext context}) async {
    final description = groupReportController.value.text.trim();
    if (description.isEmpty) {
      TostWidget().errorToast(
          title: "Required", message: "Please enter a report message.");
      return;
    }
    Map<String, dynamic> reqModel = {
      "groupId": groupId,
      "description": description
    };
    try {
      isGroupReportLoading(true);
      var res = await _groupRepo.grouopReport(reqModel: reqModel);
      if (res.data!['success'] == true) {
        TostWidget().successToast(
            title: "Success", message: res.data!['message'].toString());
        isGroupReportLoading(false);
        groupReportController.value.clear();
        backFromPrevious(context: context);
      } else {
        final errorMessage =
            (res.data?['message']?.toString().trim().isNotEmpty ?? false)
                ? res.data!['message'].toString()
                : "Unable to submit your report. Please try again.";
        TostWidget().errorToast(title: "Error", message: errorMessage);
        groupReportController.value.clear();
        isGroupReportLoading(false);
        backFromPrevious(context: context);
      }
    } catch (e) {
      groupReportController.value.clear();
      isGroupReportLoading(false);
      backFromPrevious(context: context);
    }
  }

// This method reports a message in a group chat.
  messageReport(
      {required String messageId,
      required String groupId,
      required BuildContext context}) async {
    final description = messageReportController.value.text.trim();
    if (description.isEmpty) {
      TostWidget().errorToast(
          title: "Required", message: "Please enter a report message.");
      return;
    }
    Map<String, dynamic> reqModel = {
      "msgId": messageId,
      "groupId": groupId,
      "description": description
    };
    try {
      isMessageReportLoading(true);
      var res = await _groupRepo.messageReport(reqModel: reqModel);
      if (res.data!['success'] == true) {
        TostWidget().successToast(
            title: "Success", message: res.data!['message'].toString());
        isMessageReportLoading(false);
        messageReportController.value.clear();
        backFromPrevious(context: Get.context!);
      } else {
        final errorMessage =
            (res.data?['message']?.toString().trim().isNotEmpty ?? false)
                ? res.data!['message'].toString()
                : "Unable to submit your report. Please try again.";
        TostWidget().errorToast(title: "Error", message: errorMessage);

        isMessageReportLoading(false);
        backFromPrevious(context: Get.context!);
      }
    } catch (e) {
      messageReportController.value.clear();
      isMessageReportLoading(false);
      backFromPrevious(context: Get.context!);
    }
  }
}
