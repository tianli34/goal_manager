import '../core/enums.dart';
import 'json_helpers.dart';

const Object _unset = Object();

class CommitmentChange {
  CommitmentChange({
    DateTime? at,
    required this.note,
    this.oldAmount,
    this.newAmount,
  }) : at = at ?? DateTime.now();

  final DateTime at;
  final String note;
  final double? oldAmount;
  final double? newAmount;

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'note': note,
    'oldAmount': oldAmount,
    'newAmount': newAmount,
  };

  factory CommitmentChange.fromJson(Map<String, dynamic> json) {
    return CommitmentChange(
      at: asDate(json['at']) ?? DateTime.now(),
      note: asString(json['note']),
      oldAmount: json['oldAmount'] is num
          ? (json['oldAmount'] as num).toDouble()
          : null,
      newAmount: json['newAmount'] is num
          ? (json['newAmount'] as num).toDouble()
          : null,
    );
  }
}

class Commitment {
  Commitment({
    required this.id,
    required this.goalId,
    required this.start,
    required this.end,
    this.plannedAmount,
    this.baselineValue,
    this.targetChildId,
    this.status = CommitmentStatus.active,
    this.note = '',
    List<CommitmentChange> changes = const [],
    DateTime? createdAt,
  }) : changes = List.unmodifiable(changes),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String goalId;
  final DateTime start;
  final DateTime end;

  /// 语义随机制变化：
  /// 累积型 = 目标增量；主观型 = 自评推进点数；
  /// 指标型 = 期望读数；完成型/里程碑型不使用。
  final double? plannedAmount;

  /// 创建承诺时目标的原始量快照，用于判定推进量，避免目标值被修改后自动兑现。
  final double? baselineValue;

  /// 里程碑承诺可以指定某个子项。
  final String? targetChildId;

  final CommitmentStatus status;
  final String note;
  final List<CommitmentChange> changes;
  final DateTime createdAt;

  Commitment copyWith({
    double? plannedAmount,
    CommitmentStatus? status,
    String? note,
    List<CommitmentChange>? changes,
    Object? targetChildId = _unset,
  }) {
    return Commitment(
      id: id,
      goalId: goalId,
      start: start,
      end: end,
      plannedAmount: plannedAmount ?? this.plannedAmount,
      baselineValue: baselineValue,
      targetChildId: identical(targetChildId, _unset)
          ? this.targetChildId
          : targetChildId as String?,
      status: status ?? this.status,
      note: note ?? this.note,
      changes: changes ?? this.changes,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'goalId': goalId,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'plannedAmount': plannedAmount,
    'baselineValue': baselineValue,
    'targetChildId': targetChildId,
    'status': status.name,
    'note': note,
    'changes': changes.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Commitment.fromJson(Map<String, dynamic> json) {
    return Commitment(
      id: asString(json['id']),
      goalId: asString(json['goalId']),
      start: asDate(json['start']) ?? DateTime.now(),
      end: asDate(json['end']) ?? DateTime.now(),
      plannedAmount: json['plannedAmount'] is num
          ? (json['plannedAmount'] as num).toDouble()
          : null,
      baselineValue: json['baselineValue'] is num
          ? (json['baselineValue'] as num).toDouble()
          : null,
      targetChildId:
          json['targetChildId'] is String &&
              (json['targetChildId'] as String).isNotEmpty
          ? json['targetChildId'] as String
          : null,
      status: CommitmentStatus.parse(asString(json['status'])),
      note: asString(json['note']),
      changes: asMapList(json['changes'])
          .map(CommitmentChange.fromJson)
          .toList(),
      createdAt: asDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}
