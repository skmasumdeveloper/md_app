class MeetingsListModel {
  bool? success;
  String? message;
  List<MeetingModel>? meetingModel;

  MeetingsListModel({this.success, this.message, this.meetingModel});

  MeetingsListModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    if (json['data'] != null) {
      meetingModel = <MeetingModel>[];
      json['data'].forEach((v) {
        meetingModel!.add(MeetingModel.fromJson(v));
      });
    }
  }
}

class MeetingModel {
  String? googleEventId;
  String? sId;
  String? groupName;
  String? groupDescription;
  String? groupImage;
  List<CurrentUsers>? currentUsers;
  List<dynamic>? previousUsers;
  String? createdAt;
  String? updatedAt;
  int? iV;
  String? id;
  List<dynamic>? currentUsersId;
  LastMessage? lastMessage;
  List<dynamic>? admins;
  int? unreadCount;
  String? groupCallStatus;
  bool? isTemp;
  bool? isDirect;
  String? meetingStartTime;
  String? meetingEndTime;
  String? createdByTimeZone;
  String? createdBy;
  String? link;
  String? pin;
  VideoCallDetails? videoCallDetails;
  UserAction? userAction;
  List<ParticipantActions>? participantActions;

  // Local runtime flag: true if this meeting item was created/imported from the device calendar
  bool? isDeviceEvent;

  MeetingModel({
    this.googleEventId,
    this.sId,
    this.groupName,
    this.unreadCount,
    this.currentUsers,
    this.previousUsers,
    this.createdAt,
    this.updatedAt,
    this.groupImage,
    this.groupDescription,
    this.admins,
    this.iV,
    this.id,
    this.currentUsersId,
    this.lastMessage,
    this.groupCallStatus,
    this.isTemp,
    this.isDirect,
    this.meetingStartTime,
    this.meetingEndTime,
    this.createdByTimeZone,
    this.createdBy,
    this.link,
    this.pin,
    this.videoCallDetails,
    this.userAction,
    this.participantActions,
    this.isDeviceEvent,
  });

  MeetingModel.fromJson(Map<String, dynamic> json) {
    googleEventId =
        json['googleEventId'] == null ? null : json['googleEventId'] as String?;
    sId = json['_id'];
    groupImage =
        json['groupImage'] == null ? null : json['groupImage'] as String?;
    admins = json['admins'] == null ? null : json['admins'] as List<dynamic>?;
    groupName = json['groupName'];
    if (json['currentUsers'] != null) {
      currentUsers = <CurrentUsers>[];
      json['currentUsers'].forEach((v) {
        currentUsers!.add(CurrentUsers.fromJson(v));
      });
    }
    previousUsers = json['previousUsers'] == null
        ? null
        : json['previousUsers'] as List<dynamic>?;
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    groupDescription = json['groupDescription'] == null
        ? null
        : json['groupDescription'] as String?;
    iV = json['__v'];
    id = json['id'];
    currentUsersId = json['currentUsersId'] == null
        ? null
        : json['currentUsersId'] as List<dynamic>;
    lastMessage = json['lastMessage'] != null
        ? LastMessage.fromJson(json['lastMessage'])
        : null;
    unreadCount =
        json['unreadCount'] == null ? null : json['unreadCount'] as int?;
    groupCallStatus = json['Video_call_details'] == null
        ? null
        : json['Video_call_details']['status'] == null
            ? null
            : json['Video_call_details']['status'] as String?;
    isTemp = json['isTemp'] == null ? false : json['isTemp'] as bool?;
    isDirect = json['isDirect'] == null ? false : json['isDirect'] as bool?;
    meetingStartTime = json['meetingStartTime'] == null
        ? null
        : json['meetingStartTime'] as String?;
    meetingEndTime = json['meetingEndTime'] == null
        ? null
        : json['meetingEndTime'] as String?;
    createdByTimeZone = json['createdByTimeZone'] == null
        ? null
        : json['createdByTimeZone'] as String?;
    createdBy = json['createdBy'] == null ? null : json['createdBy'] as String?;
    link = json['link'] == null ? null : json['link'] as String?;
    pin = json['pin'] == null ? null : json['pin'] as String?;
    videoCallDetails = json['Video_call_details'] != null
        ? VideoCallDetails.fromJson(json['Video_call_details'])
        : null;
    userAction = json['userAction'] != null
        ? UserAction.fromJson(json['userAction'])
        : null;
    if (json['participantActions'] != null) {
      participantActions = <ParticipantActions>[];
      json['participantActions'].forEach((v) {
        participantActions!.add(ParticipantActions.fromJson(v));
      });
    }
  }
}

class CurrentUsers {
  String? sId;
  String? name;
  String? phone;
  String? image;
  String? userType;

  CurrentUsers(
      {this.sId,
      this.name,
      this.phone,
      this.userType,
      this.image =
          "https://images.unsplash.com/photo-1575936123452-b67c3203c357?q=80&w=1000&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8aW1hZ2V8ZW58MHx8MHx8fDA%3D"});

  CurrentUsers.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    name = json['name'];
    phone = json['phone'];
    image = json["image"] == null ? null : json['image'] as String?;
    userType = json['userType'];
  }
}

class LastMessage {
  String? sId;
  String? groupId;
  SenderId? senderId;
  String? senderName;
  String? message;
  String? messageType;
  dynamic forwarded;
  List<DeliveredTo>? deliveredTo;
  List<ReadBy>? readBy;
  List<dynamic>? deletedBy;
  String? timestamp;
  String? createdAt;
  String? updatedAt;
  int? iV;
  String? id;

  LastMessage(
      {this.sId,
      this.groupId,
      this.senderId,
      this.senderName,
      this.message,
      this.messageType,
      this.forwarded,
      this.deliveredTo,
      this.readBy,
      this.deletedBy,
      this.timestamp,
      this.createdAt,
      this.updatedAt,
      this.iV,
      this.id});

  LastMessage.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    groupId = json['groupId'];
    senderId =
        json['senderId'] != null ? SenderId.fromJson(json['senderId']) : null;
    senderName = json['senderName'];
    message = json['message'];
    messageType = json['messageType'];
    forwarded = json['forwarded'];
    timestamp = json['timestamp'];
    if (json['deliveredTo'] != null) {
      deliveredTo = <DeliveredTo>[];
      json['deliveredTo'].forEach((v) {
        deliveredTo!.add(DeliveredTo.fromJson(v));
      });
    }
    if (json['readBy'] != null) {
      readBy = <ReadBy>[];
      json['readBy'].forEach((v) {
        readBy!.add(ReadBy.fromJson(v));
      });
    }

    deletedBy =
        json['deletedBy'] == null ? null : json[deletedBy] as List<dynamic>?;

    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    iV = json['__v'];
    id = json['id'];
  }
}

class ReadBy {
  String? id;
  String? user;
  String? timestamp;

  ReadBy({
    this.id,
    this.user,
    this.timestamp,
  });

  ReadBy.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    user = json['user'];
    timestamp = json['timestamp'];
  }
}

class DeliveredTo {
  String? user;
  String? timestamp;
  String? sId;
  String? id;

  DeliveredTo({this.user, this.timestamp, this.sId, this.id});

  DeliveredTo.fromJson(Map<String, dynamic> json) {
    user = json['user'];
    timestamp = json['timestamp'];
    sId = json['_id'];
    id = json['id'];
  }
}

class SenderId {
  String? name;
  String? id;
  SenderId({this.name, this.id});

  SenderId.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    name = json['name'];
  }
}

class VideoCallDetails {
  String? sId;
  String? groupId;
  List<UserActivity>? userActivity;
  String? status;
  String? callType;
  bool? incommingCall;
  String? startedAt;
  String? createdAt;
  String? updatedAt;
  int? iV;
  String? endedAt;

  VideoCallDetails(
      {this.sId,
      this.groupId,
      this.userActivity,
      this.status,
      this.callType,
      this.incommingCall,
      this.startedAt,
      this.createdAt,
      this.updatedAt,
      this.iV,
      this.endedAt});

  VideoCallDetails.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    groupId = json['groupId'];
    if (json['userActivity'] != null) {
      userActivity = <UserActivity>[];
      json['userActivity'].forEach((v) {
        userActivity!.add(UserActivity.fromJson(v));
      });
    }
    status = json['status'];
    callType = json['callType'];
    incommingCall = json['incommingCall'];
    startedAt = json['startedAt'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    iV = json['__v'];
    endedAt = json['endedAt'];
  }
}

class UserActivity {
  String? user;
  String? status;
  String? sId;
  String? joinedAt;
  String? leftAt;

  UserActivity({this.user, this.status, this.sId, this.joinedAt, this.leftAt});

  UserActivity.fromJson(Map<String, dynamic> json) {
    user = json['user'];
    status = json['status'];
    sId = json['_id'];
    joinedAt = json['joinedAt'];
    leftAt = json['leftAt'];
  }
}

class UserAction {
  String? sId;
  String? groupId;
  String? action;
  String? userId;
  String? actionDescription;
  String? actionTime;
  String? createdAt;
  String? updatedAt;
  int? iV;
  String? id;

  UserAction(
      {this.sId,
      this.groupId,
      this.action,
      this.userId,
      this.actionDescription,
      this.actionTime,
      this.createdAt,
      this.updatedAt,
      this.iV,
      this.id});

  UserAction.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    groupId = json['groupId'];
    action = json['action']; // 'accept' or 'reject'
    userId = json['userId'];
    actionDescription = json['actionDescription'];
    actionTime = json['actionTime'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    iV = json['__v'];
    id = json['id'];
  }
}

class ParticipantActions {
  String? sId;
  String? groupId;
  String? action;
  String? userId;
  String? actionDescription;
  String? actionTime;
  String? createdAt;
  String? updatedAt;
  int? iV;
  String? id;

  ParticipantActions(
      {this.sId,
      this.groupId,
      this.action,
      this.userId,
      this.actionDescription,
      this.actionTime,
      this.createdAt,
      this.updatedAt,
      this.iV,
      this.id});

  ParticipantActions.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    groupId = json['groupId'];
    action = json['action']; // 'accept' or 'reject'
    userId = json['userId'];
    actionDescription = json['actionDescription'];
    actionTime = json['actionTime'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    iV = json['__v'];
    id = json['id'];
  }
}
