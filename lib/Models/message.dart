class Message {
  String? message;
  String? profilePicture;
  bool? sendBy;
  String? sendById;
  bool? isSeen;
  int? time;
  String? type;

  Message({
    this.message,
    this.profilePicture,
    this.sendBy,
    this.sendById,
    this.isSeen,
    this.time,
    this.type,
  });

  Message.fromJson(Map<String, dynamic> json) {
    isSeen = json['isSeen'] ?? false;
    message = json['message'] ?? '';
    profilePicture = json['profile_picture'] ?? '';
    sendById = json['sendById'] ?? '';
    sendBy = json['sendBy'] ?? '';
    type = json['type'] ?? '';
    time = json['time'] ?? 0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['message'] = message;
    data['profile_picture'] = profilePicture;
    data['sendById'] = sendById;
    data['sendBy'] = sendBy;
    data['isSeen'] = isSeen;
    data['type'] = type;
    data['time'] = time;
    return data;
  }
}

enum Type { text, img, pdf, doc, docx, ppt }
