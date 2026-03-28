class MemberModel {
  bool? success;
  String? message;
  List<MemberListMdoel>? memberList;

  MemberModel({this.success, this.message, this.memberList});

  MemberModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    if (json['data'] != null) {
      memberList = <MemberListMdoel>[];
      json['data']['data'].forEach((v) {
        memberList!.add(MemberListMdoel.fromJson(v));
      });
    }
  }
}

class MemberListMdoel {
  String? sId;
  int? sl;
  String? name;
  String? email;
  String? password;
  String? phone;
  List<dynamic>? connectedDevices;
  String? userType;
  String? accountStatus;
  String? createdAt;
  int? iV;
  String? image;

  MemberListMdoel(
      {this.sId,
      this.sl,
      this.name,
      this.email,
      this.password,
      this.phone,
      this.connectedDevices,
      this.userType,
      this.accountStatus,
      this.createdAt,
      this.iV,
      this.image});

  MemberListMdoel.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    sl = json['sl'];
    name = json['name'];
    email = json['email'];
    password = json['password'];
    phone = json['phone'];
    connectedDevices = json['connectedDevices'] == null
        ? null
        : json['connectedDevices'] as List<dynamic>?;

    userType = json['userType'];
    accountStatus = json['accountStatus'];
    createdAt = json['createdAt'];
    iV = json['__v'];
    image = json['image'];
  }
}
