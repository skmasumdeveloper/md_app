class ResponseGroupMediaFiles {
  bool? status;
  int? statusCode;
  List<Data>? data;

  ResponseGroupMediaFiles({this.status, this.statusCode, this.data});

  ResponseGroupMediaFiles.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    statusCode = json['statusCode'];
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(Data.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['statusCode'] = statusCode;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Data {
  String? img;
  String? time;

  Data({this.img, this.time});

  Data.fromJson(Map<String, dynamic> json) {
    img = json['img'];
    time = json['time'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['img'] = img;
    data['time'] = time;
    return data;
  }
}
