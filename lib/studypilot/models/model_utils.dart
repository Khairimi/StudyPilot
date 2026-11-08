/// Small, dependency-free helpers shared by StudyPilot models.
library;

/// Parses ISO-8601 strings, DateTime or epoch milliseconds. Returns null for
/// anything else so bad data never throws during deserialisation.
DateTime? parseDate(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  // Firestore Timestamp (later phase) exposes toDate(); handled dynamically
  // so models stay free of Firebase imports.
  try {
    final d = (v as dynamic).toDate();
    if (d is DateTime) return d;
  } catch (_) {}
  return null;
}

String? isoOrNull(DateTime? d) => d?.toIso8601String();

double parseDouble(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

List<String> parseStringList(Object? v) =>
    v is List ? v.whereType<String>().toList() : <String>[];

List<Map<String, dynamic>> parseMapList(Object? v) => v is List
    ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : <Map<String, dynamic>>[];

/// Sentinel so copyWith can distinguish "not passed" from "set to null".
const Object unset = Object();
