class User {
  String? id;
  String? name;
  String? email;
  bool? isAdmin;
  String? profilePicture;
  bool? isSuperAdmin;
  String? status;
  bool? isOnline;
  bool isSelected = false;
  String? lastActive;
  String? pushToken;

  User(
      {this.id,
      this.name,
      this.email,
      this.isAdmin,
      this.profilePicture,
      this.isSuperAdmin,
      this.status,
      required this.isSelected,
      this.isOnline,
      this.lastActive,
      this.pushToken});

  User.fromJson(Map<String, dynamic> json) {
    id = json['uid'];
    name = json['name'];
    email = json['email'];
    isAdmin = json['isAdmin'];
    profilePicture = json['profile_picture'];
    isSuperAdmin = json['isSuperAdmin'];
    status = json['status'];
    isOnline = json['isOnline'];
    lastActive = json['last_active'];
    pushToken = json['push_token'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['uid'] = id;
    data['name'] = name;
    data['email'] = email;
    data['isAdmin'] = isAdmin;
    data['profile_picture'] = profilePicture;
    data['isSuperAdmin'] = isSuperAdmin;
    data['status'] = status;
    data['isOnline'] = isOnline;
    data['last_active'] = lastActive;
    data['push_token'] = pushToken;
    return data;
  }
}
