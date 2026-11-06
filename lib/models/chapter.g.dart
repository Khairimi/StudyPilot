// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChapterAdapter extends TypeAdapter<Chapter> {
  @override
  final int typeId = 1;

  @override
  Chapter read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Chapter(
      id: fields[0] as String,
      subjectId: fields[1] as String,
      title: fields[2] as String,
      description: fields[3] as String,
      createdDate: fields[4] as DateTime,
      isCompleted: fields[5] as bool,
      dueDate: fields[6] as DateTime?,
      priority: fields[7] as String?,
      sourceType: fields[8] as String?,
      classroomCourseId: fields[9] as String?,
      classroomCourseWorkId: fields[10] as String?,
      pdfAttachmentCount: fields[11] as int?,
    )..isSubmitted = fields[12] as bool?;
  }

  @override
  void write(BinaryWriter writer, Chapter obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.subjectId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.createdDate)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.dueDate)
      ..writeByte(7)
      ..write(obj.priority)
      ..writeByte(8)
      ..write(obj.sourceType)
      ..writeByte(9)
      ..write(obj.classroomCourseId)
      ..writeByte(10)
      ..write(obj.classroomCourseWorkId)
      ..writeByte(11)
      ..write(obj.pdfAttachmentCount)
      ..writeByte(12)
      ..write(obj.isSubmitted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
