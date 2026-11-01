import 'json_helpers.dart';

class AppSettings {
  AppSettings({
    this.staleDays = 14,
    this.riskDays = 7,
    this.metricMinObservations = 3,
    this.newGoalInAppBar = false,
  });

  final int staleDays;
  final int riskDays;
  final int metricMinObservations;

  /// 顶层目标首次超过阈值后置为 true，把「新建」按钮永久移到标题栏。
  final bool newGoalInAppBar;

  AppSettings copyWith({
    int? staleDays,
    int? riskDays,
    int? metricMinObservations,
    bool? newGoalInAppBar,
  }) {
    return AppSettings(
      staleDays: staleDays ?? this.staleDays,
      riskDays: riskDays ?? this.riskDays,
      metricMinObservations:
          metricMinObservations ?? this.metricMinObservations,
      newGoalInAppBar: newGoalInAppBar ?? this.newGoalInAppBar,
    );
  }

  Map<String, dynamic> toJson() => {
    'staleDays': staleDays,
    'riskDays': riskDays,
    'metricMinObservations': metricMinObservations,
    'newGoalInAppBar': newGoalInAppBar,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      staleDays: asInt(json['staleDays'], 14).clamp(1, 365),
      riskDays: asInt(json['riskDays'], 7).clamp(1, 90),
      metricMinObservations: asInt(
        json['metricMinObservations'],
        3,
      ).clamp(1, 30),
      newGoalInAppBar: asBool(json['newGoalInAppBar']),
    );
  }
}
