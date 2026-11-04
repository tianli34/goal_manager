import '../core/enums.dart';
import 'json_helpers.dart';

class AppSettings {
  AppSettings({
    this.staleDays = 14,
    this.riskDays = 7,
    this.metricMinObservations = 3,
    this.newGoalInAppBar = false,
    this.dueFieldMode = DueFieldMode.duration,
  });

  final int staleDays;
  final int riskDays;
  final int metricMinObservations;

  /// 顶层目标首次超过阈值后置为 true，把「新建」按钮永久移到标题栏。
  final bool newGoalInAppBar;

  /// 目标表单里「结束时间」用「期限」（时长）还是「截止日期」（日期）填写。
  /// 默认「期限」；旧备份缺字段时由 DueFieldMode.parse 回落到「期限」。
  final DueFieldMode dueFieldMode;

  AppSettings copyWith({
    int? staleDays,
    int? riskDays,
    int? metricMinObservations,
    bool? newGoalInAppBar,
    DueFieldMode? dueFieldMode,
  }) {
    return AppSettings(
      staleDays: staleDays ?? this.staleDays,
      riskDays: riskDays ?? this.riskDays,
      metricMinObservations:
          metricMinObservations ?? this.metricMinObservations,
      newGoalInAppBar: newGoalInAppBar ?? this.newGoalInAppBar,
      dueFieldMode: dueFieldMode ?? this.dueFieldMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'staleDays': staleDays,
    'riskDays': riskDays,
    'metricMinObservations': metricMinObservations,
    'newGoalInAppBar': newGoalInAppBar,
    'dueFieldMode': dueFieldMode.name,
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
      dueFieldMode: DueFieldMode.parse(asString(json['dueFieldMode'])),
    );
  }
}
