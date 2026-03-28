class UserModel {
  bool? success;
  String? message;
  String? error;
  Data? data;

  UserModel({this.success, this.message, this.data, this.error});

  UserModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    error = json['error'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }
}

class Data {
  User? user;
  String? token;

  Data({this.user, this.token});

  Data.fromJson(Map<String, dynamic> json) {
    user = json['user'] != null ? User.fromJson(json['user']) : null;
    token = json['token'];
  }
}

class User {
  String? sId;
  int? sl;
  String? email;
  String? name;
  String? userType;
  String? createdAt;

  User(
      {this.sId,
      this.sl,
      this.email,
      this.name,
      this.userType,
      this.createdAt});

  User.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    sl = json['sl'];
    email = json['email'];
    name = json['name'];
    userType = json['userType'];
    createdAt = json['createdAt'];
  }
}
