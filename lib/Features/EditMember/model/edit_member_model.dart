class EditMember {
  bool? success;
  String? message;
  Data? data;

  EditMember({this.success, this.message, this.data});

  EditMember.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
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

class Data {
  String? sId;
  int? sl;
  String? name;
  String? email;
  String? password;
  String? phone;
  String? userType;
  List<String>? addedMemberBy;
  String? accountStatus;
  bool? isActiveInCall;
  String? createdAt;
  int? iV;

  Data(
      {this.sId,
      this.sl,
      this.name,
      this.email,
      this.password,
      this.phone,
      this.userType,
      this.addedMemberBy,
      this.accountStatus,
      this.isActiveInCall,
      this.createdAt,
      this.iV});

  Data.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    sl = json['sl'];
    name = json['name'];
    email = json['email'];
    password = json['password'];
    phone = json['phone'];
    userType = json['userType'];
    addedMemberBy = json['added_member_by'].cast<String>();
    accountStatus = json['accountStatus'];
    isActiveInCall = json['isActiveInCall'];
    createdAt = json['createdAt'];
    iV = json['__v'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['_id'] = sId;
    data['sl'] = sl;
    data['name'] = name;
    data['email'] = email;
    data['password'] = password;
    data['phone'] = phone;
    data['userType'] = userType;
    data['added_member_by'] = addedMemberBy;
    data['accountStatus'] = accountStatus;
    data['isActiveInCall'] = isActiveInCall;
    data['createdAt'] = createdAt;
    data['__v'] = iV;
    return data;
  }
}
