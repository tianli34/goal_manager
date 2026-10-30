import 'json_helpers.dart';

class InboxItem {
  InboxItem({required this.id, required this.text, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory InboxItem.fromJson(Map<String, dynamic> json) {
    return InboxItem(
      id: asString(json['id']),
      text: asString(json['text']),
      createdAt: asDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}
