class CreateMeetingRequest {
  String? groupName;
  String? groupDescription;
  String? meetingStartTime;
  String? meetingEndTime;
  String? createdByTimeZone;
  List<String>? users;
  bool? isTemp;

  CreateMeetingRequest({
    this.groupName,
    this.groupDescription,
    this.meetingStartTime,
    this.meetingEndTime,
    this.createdByTimeZone,
    this.users,
    this.isTemp = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'groupName': groupName,
      'groupDescription': groupDescription,
      'meetingStartTime': meetingStartTime,
      'meetingEndTime': meetingEndTime,
      'createdByTimeZone': createdByTimeZone,
      'users': users,
      'isTemp': isTemp,
    };
  }
}

class CreateMeetingResponse {
  bool? success;
  String? message;
  MeetingData? data;

  CreateMeetingResponse({this.success, this.message, this.data});

  CreateMeetingResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    data = json['data'] != null ? MeetingData.fromJson(json['data']) : null;
  }
}

class MeetingData {
  String? id;
  String? groupName;
  String? groupDescription;
  String? meetingStartTime;
  String? meetingEndTime;
  String? createdByTimeZone;
  List<dynamic>? currentUsers;
  bool? isTemp;

  MeetingData({
    this.id,
    this.groupName,
    this.groupDescription,
    this.meetingStartTime,
    this.meetingEndTime,
    this.createdByTimeZone,
    this.currentUsers,
    this.isTemp,
  });

  MeetingData.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    groupName = json['groupName'];
    groupDescription = json['groupDescription'];
    meetingStartTime = json['meetingStartTime'];
    meetingEndTime = json['meetingEndTime'];
    createdByTimeZone = json['createdByTimeZone'];
    currentUsers = json['currentUsers'];
    isTemp = json['isTemp'];
  }
}
