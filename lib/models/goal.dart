import '../core/date_utils.dart';
import '../core/enums.dart';
import 'json_helpers.dart';

const Object _unset = Object();

class Goal {
  Goal({
    required this.id,
    required this.title,
    this.why = '',
    this.successCriteria = '',
    this.mechanism = Mechanism.completion,
    this.lifecycle = Lifecycle.active,
    this.startDate,
    this.dueDate,
    this.durationAmount,
    this.durationUnit,
    this.domain = '',
    this.tags = const [],
    this.parentGoalId,
    this.weight = 1,
    this.isRequired = true,
    this.isArchived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
    this.executionMode = ExecutionMode.parallel,
    this.unit = '',
    this.startValue = 0,
    this.targetValue = 1,
    this.currentValue = 0,
    this.subjectivePercent = 0,
    this.stableWindow = 3,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String why;
  final String successCriteria;
  final Mechanism mechanism;
  final Lifecycle lifecycle;
  final DateTime? startDate;
  final DateTime? dueDate;

  /// 「期限」录入方式下保存的时长规则：结束日期只从开始日期推导，
  /// 没有开始日期时规则先挂着、不产生结束日期。两者为空表示用「截止日期」录入。
  final int? durationAmount;
  final DurationUnit? durationUnit;

  final String domain;
  final List<String> tags;
  final String? parentGoalId;
  final double weight;
  final bool isRequired;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  /// 里程碑子项的激活方式；其他机制不使用。
  final ExecutionMode executionMode;

  final String unit;
  final double startValue;
  final double targetValue;
  final double currentValue;
  final int subjectivePercent;
  final int stableWindow;

  bool get isMilestone => mechanism == Mechanism.milestone;

  /// 只有完成型、主观型可以完全靠一次操作完成，其余机制由原始量推导。
  bool get isAtomic => mechanism != Mechanism.milestone;

  /// 非法（非正数、单位缺失）的规则一律视为没有规则。
  ({int amount, DurationUnit unit})? get durationRule {
    final amount = durationAmount;
    final unit = durationUnit;
    if (amount == null || amount <= 0 || unit == null) return null;
    return (amount: amount, unit: unit);
  }

  String? get durationLabel {
    final rule = durationRule;
    return rule == null ? null : '${rule.amount} ${rule.unit.label}';
  }

  Goal copyWith({
    String? id,
    String? title,
    String? why,
    String? successCriteria,
    Mechanism? mechanism,
    Lifecycle? lifecycle,
    Object? startDate = _unset,
    Object? dueDate = _unset,
    Object? durationAmount = _unset,
    Object? durationUnit = _unset,
    String? domain,
    List<String>? tags,
    Object? parentGoalId = _unset,
    double? weight,
    bool? isRequired,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? completedAt = _unset,
    ExecutionMode? executionMode,
    String? unit,
    double? startValue,
    double? targetValue,
    double? currentValue,
    int? subjectivePercent,
    int? stableWindow,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      why: why ?? this.why,
      successCriteria: successCriteria ?? this.successCriteria,
      mechanism: mechanism ?? this.mechanism,
      lifecycle: lifecycle ?? this.lifecycle,
      startDate: identical(startDate, _unset)
          ? this.startDate
          : startDate as DateTime?,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
      durationAmount: identical(durationAmount, _unset)
          ? this.durationAmount
          : durationAmount as int?,
      durationUnit: identical(durationUnit, _unset)
          ? this.durationUnit
          : durationUnit as DurationUnit?,
      domain: domain ?? this.domain,
      tags: tags ?? this.tags,
      parentGoalId: identical(parentGoalId, _unset)
          ? this.parentGoalId
          : parentGoalId as String?,
      weight: weight ?? this.weight,
      isRequired: isRequired ?? this.isRequired,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      executionMode: executionMode ?? this.executionMode,
      unit: unit ?? this.unit,
      startValue: startValue ?? this.startValue,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      subjectivePercent: subjectivePercent ?? this.subjectivePercent,
      stableWindow: stableWindow ?? this.stableWindow,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'why': why,
    'successCriteria': successCriteria,
    'mechanism': mechanism.name,
    'lifecycle': lifecycle.name,
    'startDate': startDate?.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'durationAmount': durationAmount,
    'durationUnit': durationUnit?.name,
    'domain': domain,
    'tags': tags,
    'parentGoalId': parentGoalId,
    'weight': weight,
    'isRequired': isRequired,
    'isArchived': isArchived,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'executionMode': executionMode.name,
    'unit': unit,
    'startValue': startValue,
    'targetValue': targetValue,
    'currentValue': currentValue,
    'subjectivePercent': subjectivePercent,
    'stableWindow': stableWindow,
  };

  factory Goal.fromJson(Map<String, dynamic> json) {
    final amount =
        json['durationAmount'] is num && (json['durationAmount'] as num) > 0
        ? (json['durationAmount'] as num).toInt()
        : null;
    return Goal(
      id: asString(json['id']),
      title: asString(json['title']),
      why: asString(json['why']),
      successCriteria: asString(json['successCriteria']),
      mechanism: Mechanism.parse(asString(json['mechanism'])),
      lifecycle: Lifecycle.parse(asString(json['lifecycle'])),
      startDate: asDate(json['startDate']),
      dueDate: asDate(json['dueDate']),
      durationAmount: amount,
      durationUnit: amount == null
          ? null
          : DurationUnit.parse(asString(json['durationUnit'])),
      domain: asString(json['domain']),
      tags: asStringList(json['tags']),
      parentGoalId:
          json['parentGoalId'] is String && json['parentGoalId'].isNotEmpty
          ? json['parentGoalId'] as String
          : null,
      weight: asDouble(json['weight'], 1),
      isRequired: asBool(json['isRequired'], true),
      isArchived: asBool(json['isArchived']),
      createdAt: asDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: asDate(json['updatedAt']) ?? DateTime.now(),
      completedAt: asDate(json['completedAt']),
      executionMode: ExecutionMode.parse(asString(json['executionMode'])),
      unit: asString(json['unit']),
      startValue: asDouble(json['startValue']),
      targetValue: asDouble(json['targetValue'], 1),
      currentValue: asDouble(json['currentValue']),
      subjectivePercent: asInt(json['subjectivePercent']),
      stableWindow: asInt(json['stableWindow'], 3),
    );
  }
}
