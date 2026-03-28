class GroupListModel {
  bool? success;
  String? message;
  List<GroupModel>? groupModel;

  GroupListModel({this.success, this.message, this.groupModel});

  GroupListModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    if (json['data'] != null) {
      groupModel = <GroupModel>[];
      json['data'].forEach((v) {
        groupModel!.add(GroupModel.fromJson(v));
      });
    }
  }
}

class GroupModel {
  String? sId;
  int? serialId;
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
  String? meetingStartTime;
  String? meetingEndTime;
  String? createdByTimeZone;
  bool? isNew;
  bool? isDirect;
  String? createdBy;

  GroupModel(
      {this.sId,
      this.serialId,
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
      this.meetingStartTime,
      this.meetingEndTime,
      this.createdByTimeZone,
      this.isNew,
      this.isDirect,
      this.createdBy});

  GroupModel.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    serialId = json['serial_key'];
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
    meetingStartTime = json['meetingStartTime'] == null
        ? null
        : json['meetingStartTime'].toString();
    meetingEndTime = json['meetingEndTime'] == null
        ? null
        : json['meetingEndTime'].toString();
    createdByTimeZone = json['createdByTimeZone'] == null
        ? null
        : json['createdByTimeZone'] as String?;
    isNew = json['isNew'] == null ? false : json['isNew'] as bool?;
    isDirect = json['isDirect'] == null ? false : json['isDirect'] as bool?;
    createdBy = json['createdBy'] == null ? null : json['createdBy'] as String?;
  }
}

class CurrentUsers {
  String? sId;
  String? name;
  String? phone;
  String? email;
  String? image;
  String? userType;

  CurrentUsers(
      {this.sId,
      this.name,
      this.phone,
      this.email,
      this.userType,
      this.image =
          "https://images.unsplash.com/photo-1575936123452-b67c3203c357?q=80&w=1000&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8aW1hZ2V8ZW58MHx8MHx8fDA%3D"});

  CurrentUsers.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    name = json['name'];
    phone = json['phone'];
    email = json['email'] == null ? null : json['email'] as String?;
    image = json["image"] == null ? null : json['image'] as String?;
    userType = json['userType'];
  }
}

class LastMessage {
  String? sId;
  int? serialId;
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
      this.serialId,
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
    serialId = json['serial_key'];
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
        json['deletedBy'] == null ? null : json['deletedBy'] as List<dynamic>?;

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
