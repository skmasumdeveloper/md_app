class ResponseCreateGroup {
  bool? status;
  int? statusCode;
  String? message;

  ResponseCreateGroup({this.status, this.statusCode, this.message});

  ResponseCreateGroup.withError(String errorMessage) {
    message = errorMessage;
  }

  ResponseCreateGroup.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    statusCode = json['statusCode'];
    message = json['message'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['statusCode'] = statusCode;
    data['message'] = message;
    return data;
  }
}
