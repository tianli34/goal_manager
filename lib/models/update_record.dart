import '../core/enums.dart';
import 'json_helpers.dart';

class UpdateRecord {
  UpdateRecord({
    required this.id,
    required this.goalId,
    required this.type,
    DateTime? timestamp,
    this.delta,
    this.reading,
    this.subjectivePercent,
    this.valueAfter,
    this.note = '',
    this.reason = '',
    this.attachments = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  final String id;
  final String goalId;
  final RecordType type;
  final DateTime timestamp;
  final double? delta;
  final double? reading;
  final int? subjectivePercent;
  final double? valueAfter;
  final String note;
  final String reason;
  final List<String> attachments;

  Map<String, dynamic> toJson() => {
    'id': id,
    'goalId': goalId,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'delta': delta,
    'reading': reading,
    'subjectivePercent': subjectivePercent,
    'valueAfter': valueAfter,
    'note': note,
    'reason': reason,
    'attachments': attachments,
  };

  factory UpdateRecord.fromJson(Map<String, dynamic> json) {
    return UpdateRecord(
      id: asString(json['id']),
      goalId: asString(json['goalId']),
      type: RecordType.parse(asString(json['type'])),
      timestamp: asDate(json['timestamp']) ?? DateTime.now(),
      delta: json['delta'] is num ? (json['delta'] as num).toDouble() : null,
      reading: json['reading'] is num
          ? (json['reading'] as num).toDouble()
          : null,
      subjectivePercent: json['subjectivePercent'] is num
          ? (json['subjectivePercent'] as num).toInt()
          : null,
      valueAfter: json['valueAfter'] is num
          ? (json['valueAfter'] as num).toDouble()
          : null,
      note: asString(json['note']),
      reason: asString(json['reason']),
      attachments: asStringList(json['attachments']),
    );
  }
}
