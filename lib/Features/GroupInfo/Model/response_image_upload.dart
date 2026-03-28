class ResponseImageUpload {
  bool? status;
  int? statusCode;
  String? message;

  ResponseImageUpload({this.status, this.statusCode, this.message});

  ResponseImageUpload.withError(String errorMessage) {
    message = errorMessage;
  }

  ResponseImageUpload.fromJson(Map<String, dynamic> json) {
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
