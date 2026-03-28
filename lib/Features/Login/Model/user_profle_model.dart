class UserProfileModel {
  bool? success;
  String? message;
  Data? data;

  UserProfileModel({this.success, this.message, this.data});

  UserProfileModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }
}

class Data {
  User? user;
  Data({this.user});
  Data.fromJson(Map<String, dynamic> json) {
    user = json['user'] != null ? User.fromJson(json['user']) : null;
  }
}

class User {
  String? sId;
  int? sl;
  String? name;
  String? email;
  String? password;
  String? phone;
  String? userType;
  String? accountStatus;
  String? createdAt;
  int? iV;
  String? image;

  User(
      {this.sId,
      this.sl,
      this.name,
      this.email,
      this.password,
      this.phone,
      this.userType,
      this.accountStatus,
      this.createdAt,
      this.image,
      this.iV});

  User.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    sl = json['sl'];
    name = json['name'];
    email = json['email'];
    password = json['password'];
    phone = json['phone'];
    userType = json['userType'];
    accountStatus = json['accountStatus'];
    createdAt = json['createdAt'];
    iV = json['__v'];
    image = json['image'] == null ? null : json['image'] as String?;
  }
}
