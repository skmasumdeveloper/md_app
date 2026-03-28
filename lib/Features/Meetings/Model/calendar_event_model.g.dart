// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_event_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CalendarEventModelAdapter extends TypeAdapter<CalendarEventModel> {
  @override
  final int typeId = 2;

  @override
  CalendarEventModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CalendarEventModel(
      id: fields[0] as String,
      title: fields[1] as String,
      start: fields[2] as DateTime,
      end: fields[3] as DateTime?,
      allDay: fields[4] as bool,
      source: fields[5] as String,
      meetingId: fields[6] as String?,
      link: fields[7] as String?,
      pin: fields[8] as String?,
      deviceEventId: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CalendarEventModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.start)
      ..writeByte(3)
      ..write(obj.end)
      ..writeByte(4)
      ..write(obj.allDay)
      ..writeByte(5)
      ..write(obj.source)
      ..writeByte(6)
      ..write(obj.meetingId)
      ..writeByte(7)
      ..write(obj.link)
      ..writeByte(8)
      ..write(obj.pin)
      ..writeByte(9)
      ..write(obj.deviceEventId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEventModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
