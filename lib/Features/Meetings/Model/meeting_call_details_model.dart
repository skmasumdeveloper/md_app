// ignore_for_file: unnecessary_this

class MeetingGroupCallDetails {
  bool? success;
  String? message;
  Data? data;

  MeetingGroupCallDetails({this.success, this.message, this.data});

  MeetingGroupCallDetails.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    data = json['data'] != null ? new Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['success'] = this.success;
    data['message'] = this.message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class Data {
  bool? hasCall;
  String? callId;
  String? groupId;
  String? status;
  String? callType;
  String? startedAt;
  String? endedAt;
  int? totalDurationMinutes;
  String? totalDurationFormatted;
  int? participantCount;
  int? invitedCount;
  List<JoinedUsers>? joinedUsers;
  List<dynamic>? invitedOnlyUsers;

  Data(
      {this.hasCall,
      this.callId,
      this.groupId,
      this.status,
      this.callType,
      this.startedAt,
      this.endedAt,
      this.totalDurationMinutes,
      this.totalDurationFormatted,
      this.participantCount,
      this.invitedCount,
      this.joinedUsers,
      this.invitedOnlyUsers});

  Data.fromJson(Map<String, dynamic> json) {
    hasCall = json['hasCall'];
    callId = json['callId'];
    groupId = json['groupId'];
    status = json['status'];
    callType = json['callType'];
    startedAt = json['startedAt'];
    endedAt = json['endedAt'];
    totalDurationMinutes = json['totalDurationMinutes'];
    totalDurationFormatted = json['totalDurationFormatted'];
    participantCount = json['participantCount'];
    invitedCount = json['invitedCount'];
    if (json['joinedUsers'] != null) {
      joinedUsers = <JoinedUsers>[];
      json['joinedUsers'].forEach((v) {
        joinedUsers!.add(new JoinedUsers.fromJson(v));
      });
    }
    if (json['invitedOnlyUsers'] != null) {
      invitedOnlyUsers = <dynamic>[];
      json['invitedOnlyUsers'].forEach((v) {
        invitedOnlyUsers!.add(v);
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['hasCall'] = this.hasCall;
    data['callId'] = this.callId;
    data['groupId'] = this.groupId;
    data['status'] = this.status;
    data['callType'] = this.callType;
    data['startedAt'] = this.startedAt;
    data['endedAt'] = this.endedAt;
    data['totalDurationMinutes'] = this.totalDurationMinutes;
    data['totalDurationFormatted'] = this.totalDurationFormatted;
    data['participantCount'] = this.participantCount;
    data['invitedCount'] = this.invitedCount;
    if (this.joinedUsers != null) {
      data['joinedUsers'] = this.joinedUsers!.map((v) => v.toJson()).toList();
    }
    if (this.invitedOnlyUsers != null) {
      data['invitedOnlyUsers'] = this.invitedOnlyUsers;
    }
    return data;
  }
}

class JoinedUsers {
  User? user;
  String? status;
  String? joinedAt;
  String? leftAt;
  int? durationMinutes;
  String? durationFormatted;

  JoinedUsers(
      {this.user,
      this.status,
      this.joinedAt,
      this.leftAt,
      this.durationMinutes,
      this.durationFormatted});

  JoinedUsers.fromJson(Map<String, dynamic> json) {
    user = json['user'] != null ? User.fromJson(json['user']) : null;
    status = json['status'];
    joinedAt = json['joinedAt'];
    leftAt = json['leftAt'];
    durationMinutes = json['durationMinutes'];
    durationFormatted = json['durationFormatted'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (this.user != null) {
      data['user'] = this.user!.toJson();
    }
    data['status'] = this.status;
    data['joinedAt'] = this.joinedAt;
    data['leftAt'] = this.leftAt;
    data['durationMinutes'] = this.durationMinutes;
    data['durationFormatted'] = this.durationFormatted;
    return data;
  }
}

class User {
  String? sId;
  String? name;
  String? phone;
  String? userType;

  User({this.sId, this.name, this.phone, this.userType});

  User.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    name = json['name'];
    phone = json['phone'];
    userType = json['userType'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['_id'] = this.sId;
    data['name'] = this.name;
    data['phone'] = this.phone;
    data['userType'] = this.userType;
    return data;
  }
}
