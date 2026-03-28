class AddContactModel {
  bool? success;
  String? message;
  UserData? data;

  AddContactModel({this.success, this.message, this.data});

  AddContactModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    data = json['data'] != null ? UserData.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['success'] = success;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class UserData {
  int? sl;
  String? name;
  String? email;
  String? password;
  String? phone;
  List<String>? connectedDevices;
  String? userType;
  List<String>? addedMemberBy;
  String? accountStatus;
  bool? isActiveInCall;
  String? sId;
  String? createdAt;
  int? iV;

  UserData({
    this.sl,
    this.name,
    this.email,
    this.password,
    this.phone,
    this.connectedDevices,
    this.userType,
    this.addedMemberBy,
    this.accountStatus,
    this.isActiveInCall,
    this.sId,
    this.createdAt,
    this.iV,
  });

  UserData.fromJson(Map<String, dynamic> json) {
    sl = json['sl'];
    name = json['name'];
    email = json['email'];
    password = json['password'];
    phone = json['phone'];
    connectedDevices = json['connectedDevices']?.cast<String>();
    userType = json['userType'];
    addedMemberBy = json['added_member_by']?.cast<String>();
    accountStatus = json['accountStatus'];
    isActiveInCall = json['isActiveInCall'];
    sId = json['_id'];
    createdAt = json['createdAt'];
    iV = json['__v'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['sl'] = sl;
    data['name'] = name;
    data['email'] = email;
    data['password'] = password;
    data['phone'] = phone;
    data['connectedDevices'] = connectedDevices;
    data['userType'] = userType;
    data['added_member_by'] = addedMemberBy;
    data['accountStatus'] = accountStatus;
    data['isActiveInCall'] = isActiveInCall;
    data['_id'] = sId;
    data['createdAt'] = createdAt;
    data['__v'] = iV;
    return data;
  }
}
