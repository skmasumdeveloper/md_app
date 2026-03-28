class UserReportResponseModel {
  bool? status;
  String? message;

  UserReportResponseModel({this.status, this.message});

  UserReportResponseModel.withError(String errorMessage) {
    message = errorMessage;
  }

  UserReportResponseModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    return data;
  }
}
