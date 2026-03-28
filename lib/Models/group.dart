import 'package:cu_app/Models/user.dart';

import 'message.dart';

class Group {
  String? id;
  String? name;
  String? profilePicture;
  int? createdAt;
  int? time;
  String? groupDescription;
  List<User>? members;
  List<Message>? messages;
  List<String>? medias;

  Group({
    this.id,
    this.name,
    this.profilePicture,
    this.createdAt,
    this.time,
    this.groupDescription,
    this.members,
    this.messages,
    this.medias,
  });

  Group.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    profilePicture = json['profile_picture'];
    createdAt = json['created_at'];
    time = json['time'];
    groupDescription = json['group_description'];
    medias = json['medias'];
    if (json['members'] != null) {
      members = <User>[];
      json['members'].forEach((v) {
        members!.add(User.fromJson(v));
      });
    }
    if (json['messages'] != null) {
      messages = <Message>[];
      json['messages'].forEach((v) {
        messages!.add(Message.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['profile_picture'] = profilePicture;
    data['created_at'] = createdAt;
    data['time'] = time;
    data['group_description'] = groupDescription;
    data['medias'] = medias;
    if (members != null) {
      data['members'] = members!.map((v) => v.toJson()).toList();
    }
    if (messages != null) {
      data['messages'] = messages!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}
