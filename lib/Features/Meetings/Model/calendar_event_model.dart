import 'package:hive/hive.dart';

part 'calendar_event_model.g.dart';

@HiveType(typeId: 2)
class CalendarEventModel extends HiveObject {
  @HiveField(0)
  String
      id; // unique id (app: meeting sId, device: device event id or generated)

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime start;

  @HiveField(3)
  DateTime? end;

  @HiveField(4)
  bool allDay;

  @HiveField(5)
  String source; // 'app' or 'device'

  @HiveField(6)
  String? meetingId; // link to meeting (group id)

  @HiveField(7)
  String? link;

  @HiveField(8)
  String? pin;

  @HiveField(9)
  String? deviceEventId; // if saved in device calendar

  CalendarEventModel({
    required this.id,
    required this.title,
    required this.start,
    this.end,
    this.allDay = false,
    required this.source,
    this.meetingId,
    this.link,
    this.pin,
    this.deviceEventId,
  });
}
