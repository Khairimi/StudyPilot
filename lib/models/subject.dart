import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'subject.g.dart';

@HiveType(typeId: 0)
class Subject extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int colorValue;

  @HiveField(3)
  DateTime createdDate;

  @HiveField(4)
  int weightage;

  @HiveField(5)
  DateTime? dueDate;

  @HiveField(6)
  TimeOfDay? dueTime;

  @HiveField(7)
  String? priority;

  @HiveField(8)
  String? notes;

  Subject({
    required this.id,
    required this.name,
    required this.colorValue,
    DateTime? createdDate,

    this.weightage = 0,
    this.dueDate,
    this.dueTime,
    this.priority,
    this.notes,
  }) : createdDate = createdDate ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'createdDate': createdDate.toIso8601String(),
    'weightage': weightage,
    'dueDate': dueDate?.toIso8601String(),
    'dueTime': dueTime != null
        ? '${dueTime!.hour.toString().padLeft(2, '0')}:${dueTime!.minute.toString().padLeft(2, '0')}'
        : null,
    'priority': priority,
    'notes': notes,
  };

  factory Subject.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return Subject(
      id: data['id'] as String,
      name: data['name'] as String,
      colorValue: data['colorValue'] as int,
      createdDate: parseDate(data['createdDate']) ?? DateTime.now(),
      weightage: (data['weightage'] is int)
          ? data['weightage'] as int
          : int.tryParse('${data['weightage']}') ?? 0,
      dueDate: parseDate(data['dueDate']),
      dueTime: _parseTimeOfDay(data['dueTime'] as String?),
      priority: data['priority'] as String?,
      notes: data['notes'] as String?,
    );
  }

  static TimeOfDay? _parseTimeOfDay(String? timeString) {
    if (timeString == null) return null;
    try {
      final parts = timeString.split(':');
      if (parts.length < 2) return null;
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return null;
    }
  }
}
