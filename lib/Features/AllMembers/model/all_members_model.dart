class AllMembersModel {
  bool? success;
  String? message;
  Data? data;

  AllMembersModel({this.success, this.message, this.data});

  AllMembersModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    data = json['data'] != null ? new Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['success'] = success;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class Data {
  List<MemberData>? data;
  Pagination? pagination;

  Data({this.data, this.pagination});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <MemberData>[];
      json['data'].forEach((v) {
        data!.add(MemberData.fromJson(v));
      });
    }
    pagination = json['pagination'] != null
        ? Pagination.fromJson(json['pagination'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    if (pagination != null) {
      data['pagination'] = pagination!.toJson();
    }
    return data;
  }
}

class MemberData {
  String? sId;
  int? sl;
  String? email;
  String? name;
  String? phone;
  String? accountStatus;
  String? userType;
  String? createdAt;
  String? image;

  MemberData(
      {this.sId,
      this.sl,
      this.email,
      this.name,
      this.phone,
      this.accountStatus,
      this.userType,
      this.createdAt,
      this.image});

  MemberData.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    sl = json['sl'];
    email = json['email'];
    name = json['name'];
    phone = json['phone'];
    accountStatus = json['accountStatus'];
    userType = json['userType'];
    createdAt = json['createdAt'];
    image = json['image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['_id'] = sId;
    data['sl'] = sl;
    data['email'] = email;
    data['name'] = name;
    data['phone'] = phone;
    data['accountStatus'] = accountStatus;
    data['userType'] = userType;
    data['createdAt'] = createdAt;
    data['image'] = image;
    return data;
  }
}

class Pagination {
  int? currentPage;
  int? totalPages;
  int? totalCount;
  int? limit;
  bool? hasNextPage;
  bool? hasPrevPage;

  Pagination(
      {this.currentPage,
      this.totalPages,
      this.totalCount,
      this.limit,
      this.hasNextPage,
      this.hasPrevPage});

  Pagination.fromJson(Map<String, dynamic> json) {
    currentPage = json['currentPage'];
    totalPages = json['totalPages'];
    totalCount = json['totalCount'];
    limit = json['limit'];
    hasNextPage = json['hasNextPage'];
    hasPrevPage = json['hasPrevPage'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['currentPage'] = currentPage;
    data['totalPages'] = totalPages;
    data['totalCount'] = totalCount;
    data['limit'] = limit;
    data['hasNextPage'] = hasNextPage;
    data['hasPrevPage'] = hasPrevPage;
    return data;
  }
}
