class GuestParticipant {
  String? id;
  String? name;
  String? email;

  GuestParticipant({this.id, this.name, this.email});

  GuestParticipant.fromJson(Map<String, dynamic> json) {
    id = json['_id']?.toString() ?? json['id']?.toString();
    name = json['name']?.toString() ?? '';
    email = json['email']?.toString() ?? '';
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    return {
      if (includeId && id != null && id!.isNotEmpty) '_id': id,
      'name': name,
      'email': email,
    };
  }
}

class GuestMeeting {
  String? id;
  String? topic;
  String? description;
  List<GuestParticipant> guests = <GuestParticipant>[];
  String? startTime;
  String? endTime;
  String? hostId;
  String? meetingLink;
  String? pin;
  String? status;
  int? serialKey;
  List<dynamic>? userActivity;
  String? createdAt;
  String? updatedAt;
  String? startedAt;
  String? endedAt;

  GuestMeeting({
    this.id,
    this.topic,
    this.description,
    List<GuestParticipant>? guests,
    this.startTime,
    this.endTime,
    this.hostId,
    this.meetingLink,
    this.pin,
    this.status,
    this.serialKey,
    this.userActivity,
    this.createdAt,
    this.updatedAt,
    this.startedAt,
    this.endedAt,
  }) : guests = guests ?? <GuestParticipant>[];

  String? get guestName => guests.isNotEmpty ? guests.first.name : null;
  String? get guestEmail => guests.isNotEmpty ? guests.first.email : null;

  GuestParticipant? findGuestByEmail(String email) {
    final needle = email.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final g in guests) {
      if ((g.email ?? '').trim().toLowerCase() == needle) {
        return g;
      }
    }
    return null;
  }

  GuestMeeting.fromJson(Map<String, dynamic> json) {
    id = json['_id'] ?? json['id'];
    topic = json['topic'] ?? json['groupName'] ?? '';
    description = json['description'] ?? json['groupDescription'] ?? '';
    guests = <GuestParticipant>[];
    if (json['guest'] is List) {
      guests = (json['guest'] as List)
          .map((e) => GuestParticipant.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      final singleName = json['guestName']?.toString();
      final singleEmail = json['guestEmail']?.toString();
      if ((singleName != null && singleName.isNotEmpty) ||
          (singleEmail != null && singleEmail.isNotEmpty)) {
        guests = [
          GuestParticipant(name: singleName ?? '', email: singleEmail ?? ''),
        ];
      }
    }
    startTime = json['startTime'] ?? json['meetingStartTime'];
    endTime = json['endTime'] ?? json['meetingEndTime'];
    hostId = json['hostId'] is Map
        ? json['hostId']['_id']
        : json['hostId']?.toString();
    meetingLink = json['meetingLink'];
    pin = json['pin']?.toString();
    status = json['status'];
    serialKey = json['serial_key'] ?? json['serialKey'];
    userActivity = json['userActivity'] ?? [];
    createdAt = json['createdAt']?.toString();
    updatedAt = json['updatedAt']?.toString();
    startedAt = json['startedAt']?.toString();
    endedAt = json['endedAt']?.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'topic': topic,
      'description': description,
      'guest': guests.map((e) => e.toJson()).toList(),
      'startTime': startTime,
      'endTime': endTime,
      'hostId': hostId,
      'meetingLink': meetingLink,
      'pin': pin,
      'status': status,
      'serial_key': serialKey,
    };
  }
}

class CreateGuestMeetingResponse {
  bool? success;
  String? message;
  GuestMeeting? data;

  CreateGuestMeetingResponse({this.success, this.message, this.data});

  CreateGuestMeetingResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    data = json['data'] != null ? GuestMeeting.fromJson(json['data']) : null;
  }
}

class GuestMeetingsListResponse {
  bool? success;
  String? message;
  List<GuestMeeting>? data;

  GuestMeetingsListResponse({this.success, this.message, this.data});

  GuestMeetingsListResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    if (json['data'] != null && json['data'] is List) {
      data =
          (json['data'] as List).map((e) => GuestMeeting.fromJson(e)).toList();
    } else {
      data = [];
    }
  }
}
