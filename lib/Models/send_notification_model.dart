class RequestSendNotification {
  String? to;
  Notification? notification;

  RequestSendNotification({this.to, this.notification});

  RequestSendNotification.fromJson(Map<String, dynamic> json) {
    to = json['to'];
    notification = json['notification'] != null
        ? Notification.fromJson(json['notification'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['to'] = to;
    if (notification != null) {
      data['notification'] = notification!.toJson();
    }
    return data;
  }
}

class Notification {
  String? title;
  String? body;

  Notification({this.title, this.body});

  Notification.fromJson(Map<String, dynamic> json) {
    title = json['title'];
    body = json['body'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['title'] = title;
    data['body'] = body;
    return data;
  }
}

class ResponseSendNotification {
  int? multicastId;
  int? success;
  String? message;
  int? failure;
  int? canonicalIds;
  List<Results>? results;

  ResponseSendNotification(
      {this.multicastId,
      this.success,
      this.message,
      this.failure,
      this.canonicalIds,
      this.results});

  ResponseSendNotification.withError(String errorMessage) {
    message = errorMessage;
  }

  ResponseSendNotification.fromJson(Map<String, dynamic> json) {
    multicastId = json['multicast_id'];
    success = json['success'];
    message = json['message'];
    failure = json['failure'];
    canonicalIds = json['canonical_ids'];
    if (json['results'] != null) {
      results = <Results>[];
      json['results'].forEach((v) {
        results!.add(Results.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['multicast_id'] = multicastId;
    data['success'] = success;
    data['message'] = message;
    data['failure'] = failure;
    data['canonical_ids'] = canonicalIds;
    if (results != null) {
      data['results'] = results!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Results {
  String? messageId;

  Results({this.messageId});

  Results.fromJson(Map<String, dynamic> json) {
    messageId = json['message_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['message_id'] = messageId;
    return data;
  }
}
