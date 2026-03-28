class GroupCallHistoryModel {
  bool? success;
  String? message;
  List<GroupCallHistoryList>? data;

  GroupCallHistoryModel({this.success, this.message, this.data});

  GroupCallHistoryModel.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    if (json['data'] != null) {
      data = <GroupCallHistoryList>[];
      json['data'].forEach((v) {
        data!.add(GroupCallHistoryList.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['success'] = success;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class GroupCallHistoryList {
  String? sId;
  String? groupId;
  String? status;
  String? callType;
  bool? incommingCall;
  String? startedAt;
  int? iV;
  String? endedAt;
  GroupDetails? groupDetails;
  bool? missedCalled;
  String? callStatus;
  dynamic callDurationInMinutes;

  GroupCallHistoryList(
      {this.sId,
      this.groupId,
      this.status,
      this.callType,
      this.incommingCall,
      this.startedAt,
      this.iV,
      this.endedAt,
      this.groupDetails,
      this.missedCalled,
      this.callStatus,
      this.callDurationInMinutes});

  GroupCallHistoryList.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    groupId = json['groupId'];
    status = json['status'];
    callType = json['callType'];
    incommingCall = json['incommingCall'];
    startedAt = json['startedAt'];
    iV = json['__v'];
    endedAt = json['endedAt'];
    groupDetails = json['groupDetails'] != null
        ? GroupDetails.fromJson(json['groupDetails'])
        : null;
    missedCalled = json['missedCalled'];
    callStatus = json['callStatus'];
    callDurationInMinutes = json['callDurationInMinutes'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['_id'] = sId;
    data['groupId'] = groupId;
    data['status'] = status;
    data['callType'] = callType;
    data['incommingCall'] = incommingCall;
    data['startedAt'] = startedAt;
    data['__v'] = iV;
    data['endedAt'] = endedAt;
    if (groupDetails != null) {
      data['groupDetails'] = groupDetails!.toJson();
    }
    data['missedCalled'] = missedCalled;
    data['callStatus'] = callStatus;
    data['callDurationInMinutes'] = callDurationInMinutes;
    return data;
  }
}

class GroupDetails {
  String? sId;
  String? groupName;
  String? groupDescription;
  String? groupImage;
  List<String>? currentUsers;

  GroupDetails(
      {this.sId,
      this.groupName,
      this.groupDescription,
      this.groupImage,
      this.currentUsers});

  GroupDetails.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    groupName = json['groupName'];
    groupDescription = json['groupDescription'];
    groupImage =
        json['groupImage'] == null ? null : json['groupImage'] as String;
    currentUsers = json['currentUsers'].cast<String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['_id'] = sId;
    data['groupName'] = groupName;
    data['groupDescription'] = groupDescription;
    data['groupImage'] = groupImage;
    data['currentUsers'] = currentUsers;
    return data;
  }
}
