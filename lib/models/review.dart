import '../core/enums.dart';
import 'json_helpers.dart';

class Review {
  Review({
    required this.id,
    required this.start,
    required this.end,
    this.goalIds = const [],
    this.whatHappened = '',
    this.stillWorthPlan = true,
    this.planReflection = '',
    this.decision = ReviewDecision.continuePlan,
    this.nextStep = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final DateTime start;
  final DateTime end;
  final List<String> goalIds;
  final String whatHappened;
  final bool stillWorthPlan;
  final String planReflection;
  final ReviewDecision decision;
  final String nextStep;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'goalIds': goalIds,
    'whatHappened': whatHappened,
    'stillWorthPlan': stillWorthPlan,
    'planReflection': planReflection,
    'decision': decision.name,
    'nextStep': nextStep,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: asString(json['id']),
      start: asDate(json['start']) ?? DateTime.now(),
      end: asDate(json['end']) ?? DateTime.now(),
      goalIds: asStringList(json['goalIds']),
      whatHappened: asString(json['whatHappened']),
      stillWorthPlan: asBool(json['stillWorthPlan'], true),
      planReflection: asString(json['planReflection']),
      decision: ReviewDecision.parse(asString(json['decision'])),
      nextStep: asString(json['nextStep']),
      createdAt: asDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}
