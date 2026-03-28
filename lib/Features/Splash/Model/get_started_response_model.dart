class ResponseGetStarted {
  bool? status;
  int? statusCode;
  String? message;
  Data? data;

  ResponseGetStarted({this.status, this.statusCode, this.message, this.data});

  ResponseGetStarted.withError(String errorMessage) {
    message = errorMessage;
  }

  ResponseGetStarted.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    statusCode = json['statusCode'];
    message = json['message'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['statusCode'] = statusCode;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data?.toJson();
    }
    return data;
  }
}

class Data {
  Cms? cms;

  Data({this.cms});

  Data.fromJson(Map<String, dynamic> json) {
    cms = json['cms'] != null ? Cms.fromJson(json['cms']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (cms != null) {
      data['cms'] = cms?.toJson();
    }
    return data;
  }
}

class Cms {
  int? id;
  String? title;
  String? description;
  String? image;

  Cms({this.id, this.title, this.description, this.image});

  Cms.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    description = json['description'];
    image = json['image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['description'] = description;
    data['image'] = image;
    return data;
  }
}

class RequestGetStarted {
  String? isPanel;

  RequestGetStarted({this.isPanel});

  RequestGetStarted.fromJson(Map<String, dynamic> json) {
    isPanel = json['is_panel'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['is_panel'] = isPanel;
    return data;
  }
}
