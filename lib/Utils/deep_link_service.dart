import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:get/get.dart';

import 'package:cu_app/Features/Meetings/Repository/meetings_repo.dart';
import 'package:cu_app/Features/Meetings/Presentation/meeting_details_screen.dart';
import 'package:cu_app/Features/Login/Presentation/login_screen.dart';
import 'package:cu_app/Utils/storage_service.dart';
import 'package:cu_app/Widgets/toast_widget.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri?>? _sub;

  void init() async {
    // subscribe to incoming link stream
    _sub = _appLinks.uriLinkStream.listen((uri) {
      handleUri(uri);
    }, onError: (err) {
      // ignore stream errors
    });
  }

  Future<void> handleUri(Uri uri) async {
    // Example: https://cu-app.us/messages?pin=150821&groupId=697079c06f953ec67e296e24
    try {
      if (!uri.path.contains('/messages')) return;

      final groupId = uri.queryParameters['groupId'];
      final pin = uri.queryParameters['pin'];

      if (groupId == null || groupId.isEmpty) return;

      final isAnyCallActive = await LocalStorage().getIsAnyCallActive();
      if (isAnyCallActive) {
        TostWidget().errorToast(
            title: 'Busy', message: 'A call is running. Cannot open meeting.');
        return;
      }

      final userId = LocalStorage().getUserId();
      if (userId.isEmpty) {
        // store pending deep link and navigate to login
        await LocalStorage().setPendingDeepLink(groupId: groupId, pin: pin);
        // Make sure we navigate to login screen
        // Use Get so we can navigate outside of BuildContext
        Get.to(() => const LoginScreen());
        return;
      }

      // If logged in, load meeting details and navigate
      final repo = MeetingsRepo();
      final res = await repo.getMeetingGroupDetails(groupId: groupId);
      if (res.data != null) {
        final meeting = res.data!;
        // Navigate to meeting details screen
        Get.to(() => MeetingDetailsScreen(meeting: meeting));
      } else {
        TostWidget().errorToast(
            title: 'Error', message: res.errorMessage ?? 'Meeting not found');
      }
    } catch (e) {
      // ignore
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
