import 'package:get/get.dart';

class ChatListModel {
  bool? success;
  String? message;
  List<ChatModel>? chat;
  ChatListModel({this.success, this.message, this.chat});
  ChatListModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    if (json['data'] != null) {
      chat = <ChatModel>[];
      json['data'].forEach((v) {
        chat!.add(ChatModel.fromJson(v));
      });
    }
  }
}

class ChatModel {
  dynamic sId;
  dynamic groupId;
  dynamic senderId;
  dynamic senderName;
  dynamic message;
  dynamic messageType;
  bool? forwarded;
  List<ChatDeliveredTo>? deliveredTo;
  List<ChatReadBy>? readBy;
  List<dynamic>? deletedBy;
  List<dynamic>? allRecipients;
  dynamic timestamp;
  dynamic createdAt;
  dynamic updatedAt;
  dynamic fileName;
  int? iV;
  dynamic id;
  ReplyOf? replyOf;
  SenderDataAll? senderDataAll;
  RxBool? isHighlighted;
  // List<CurrentUsers>? currentUsers;

  ChatModel({
    this.sId,
    this.groupId,
    this.senderId,
    this.allRecipients,
    this.senderName,
    this.message,
    this.messageType,
    this.fileName,
    this.forwarded,
    this.deliveredTo,
    this.readBy,
    this.deletedBy,
    this.timestamp,
    this.createdAt,
    this.updatedAt,
    this.iV,
    this.id,
    this.replyOf,
    this.senderDataAll,
    RxBool? isHighlighted,
  }) : isHighlighted = isHighlighted ?? false.obs;

  ChatModel.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    groupId = json['groupId'];
    senderId = json['senderId'];
    senderName = json['senderName'];
    message = json['message'];
    messageType = json['messageType'];
    forwarded = json['forwarded'];
    fileName = json['fileName'];
    allRecipients = json['allRecipients'];
    deletedBy =
        json['deletedBy'] == null ? null : json['deletedBy'] as List<dynamic>?;
    if (json['deliveredTo'] != null) {
      deliveredTo = <ChatDeliveredTo>[];
      json['deliveredTo'].forEach((v) {
        deliveredTo!.add(ChatDeliveredTo.fromJson(v));
      });
    }
    if (json['readBy'] != null) {
      readBy = <ChatReadBy>[];
      json['readBy'].forEach((v) {
        readBy!.add(ChatReadBy.fromJson(v));
      });
    }

    replyOf =
        json['replyOf'] != null ? ReplyOf.fromJson(json['replyOf']) : null;
    senderDataAll = json['senderDataAll'] != null
        ? SenderDataAll.fromJson(json['senderDataAll'])
        : null;

    timestamp = json['timestamp'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    iV = json['__v'];
    id = json['id'];
    isHighlighted = false.obs;
  }
}

class ChatDeliveredTo {
  String? user;
  String? timestamp;
  String? sId;
  String? id;

  ChatDeliveredTo({this.user, this.timestamp, this.sId, this.id});

  ChatDeliveredTo.fromJson(Map<String, dynamic> json) {
    // 'user' can be a String (user id) or an object in some responses
    if (json['user'] is String) {
      user = json['user'] as String;
    } else if (json['user'] is Map) {
      // if it's an object, try to extract the id
      final map = Map<String, dynamic>.from(json['user'] as Map);
      user = map['_id']?.toString();
    } else {
      user = json['user']?.toString();
    }

    timestamp = json['timestamp'];
    sId = json['_id'];
    id = json['id'];
  }
}

class ChatReadBy {
  User? user;
  String? timestamp;
  String? sId;
  String? id;

  ChatReadBy({this.user, this.timestamp, this.sId, this.id});

  ChatReadBy.fromJson(Map<String, dynamic> json) {
    // 'user' might be a String (user id) or a full User object
    if (json['user'] is String) {
      user = User(sId: json['user'] as String);
    } else if (json['user'] is Map) {
      user = User.fromJson(Map<String, dynamic>.from(json['user'] as Map));
    } else {
      user = null;
    }

    timestamp = json['timestamp'];
    sId = json['_id'];
    id = json['id'];
  }
}

class User {
  String? sId;
  String? name;
  String? image;

  User({this.sId, this.name, this.image});

  User.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    name = json['name'];
    image = json['image'];
  }
}

class ReplyOf {
  String? msgId;
  String? sender;
  String? msg;
  String? msgType;

  ReplyOf({this.msgId, this.sender, this.msg, this.msgType});

  ReplyOf.fromJson(Map<String, dynamic> json) {
    msgId = json['msgId'];
    sender = json['sender'];
    msg = json['msg'];
    msgType = json['msgType'];
  }
}

class SenderDataAll {
  String? sId;
  String? name;
  String? image;
  String? userName;
  String? email;
  String? phone;
  String? userType;
  String? accountStatus;
  String? createdAt;

  SenderDataAll(
      {this.sId,
      this.name,
      this.image,
      this.userName,
      this.email,
      this.phone,
      this.userType,
      this.accountStatus,
      this.createdAt});

  SenderDataAll.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    name = json['name'];
    image = json['image'] == null ? null : json['image'] as String?;
    userName = json['userName'] == null ? null : json['userName'] as String?;
    email = json['email'] == null ? null : json['email'] as String?;
    phone = json['phone'] == null ? null : json['phone'] as String?;
    userType = json['userType'] == null ? null : json['userType'] as String?;
    accountStatus =
        json['accountStatus'] == null ? null : json['accountStatus'] as String?;
    createdAt = json['createdAt'];
  }
}
