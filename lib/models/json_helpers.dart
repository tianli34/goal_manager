String asString(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

double asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int asInt(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool asBool(Object? value, [bool fallback = false]) =>
    value is bool ? value : fallback;

DateTime? asDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

List<String> asStringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList();
}

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, v) => MapEntry(key.toString(), v));
  return const {};
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is! List) return const [];
  return value.map(asMap).toList();
}
