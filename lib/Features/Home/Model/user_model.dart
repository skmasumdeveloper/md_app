class UserModel {
  String? email;
  bool? isAdmin;
  bool? isSuperAdmin;
  String? name;
  String? profilePicture;
  String? pushToken;
  String? status;
  String? uid;
  bool? isOnline;

  UserModel(
      {this.email,
      this.isAdmin,
      this.isSuperAdmin,
      this.name,
      this.profilePicture,
      this.pushToken,
      this.status,
      this.uid,
      this.isOnline});

  UserModel.fromJson(Map<String, dynamic> json) {
    email = json['email'];
    isAdmin = json['isAdmin'];
    isSuperAdmin = json['isSuperAdmin'];
    name = json['name'];
    profilePicture = json['profile_picture'];
    pushToken = json['pushToken'];
    status = json['status'];
    uid = json['uid'];
    isOnline = json['isOnline'];
  }
}
