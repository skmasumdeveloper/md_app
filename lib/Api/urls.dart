import 'package:flutter_dotenv/flutter_dotenv.dart';

class MainUrl {
  final String env = dotenv.env['ENV'] ?? "production";

  String getUrl() {
    if (env == "production") {
      return dotenv.env['API_BASE_URL'] ?? '';
    } else {
      return 'http://localhost:4000';
    }
  }
}

class Urls {
  static String baseUrl = '${MainUrl().getUrl()}/api/';
  static const String cmsGetStarted = 'cms/get-started';
  static const String userReport = 'report/user-report';
  static const String groupReport = 'report/group-report';
  static const String report = 'report';
  static const String sendPushNotificationUrl =
      'https://fcm.googleapis.com/fcm/send';
  static String forgetPasswordurl = "${baseUrl}users/forgot-password";
  static String verifyOtp = "${baseUrl}users/verify-email-otp";
  static String resetPassword = "${baseUrl}users/reset-password";
}

class ApiPath {
  static String baseUrls = Urls.baseUrl;
  static String socketUrl = dotenv.env['SOCKET_URL'] ?? '';
  static String mediasoupSocketUrl =
      dotenv.env['MEDIASOUP_SOCKET_URL'] ?? socketUrl;
  static String updateProfileDetails = "$baseUrls/users/update-user";
  static String changePassword = "${baseUrls}users/change-password";
  static String messageReportApi = "$baseUrls/groups/report-message";
}

class EndPoints {
  static const userLogin = '/users/sign-in';
  static const forgetPasswordurl = "/users/forgot-password";
  static const getUserProfileData = '/users/get-user';
  static const groupListApi = "/groups/getall";
  static const meetingListApi = "/groups/getallmeetings";
  static const groupDetailsApi = "/groups/get-group-details";
  static const updateGroupDetails = "/groups/update-group";
  static const updateUserProfile = '/users/update-user';
  static const getMemberList = "/admin/users/get-all-users";
  static const createNewGroup = "/groups/create";
  static const deleteMemeberFromGroup = "/groups/removeuser";
  static const addMemberInGroup = "/groups/adduser";
  static const createDirectChat = "/groups/direct";
  static const getAllChat = '/groups/getonegroup';
  static const sendMessage = "/groups/addnewmsg";
  static const reportGroup = "/groups/report";
  static const messageReportApi = '/groups/report-message';
  static const chatInfo = '/groups/info-message';
  static const logoutApi = "/users/logout";
  static const checkActiveCall = '/groups/check-active-call';
  static const createUser = '/admin/users/create-user';
  static const checkUserExists = '/admin/users/get-user-by-mail';
  static const getAllMembers = '/admin/users/get-all-users';
  static const getSingleUser = '/admin/users/get-single-user';
  static const updateUserDetails = '/admin/users/update-user-details';
  static const deleteMember = '/admin/users/delete-user';
  static const getGroupCallsHistory = '/groups/getall/Activity';
  static const meetingCallDetails = "/groups/get-group-call-details";
  static const groupAction = "/groups/group-action";
  static const deleteGroup = "/admin/groups/delete-group";
  static const editMeeting = "/groups/update-group";
  static const deleteMessage = "/groups/deletemsg";
  static const addGuestMessage = "/groups/add-guest-message";
  static const getGuestMessages = "/groups/get-guest-messages";
}
