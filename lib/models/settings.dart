import 'json_helpers.dart';

class AppSettings {
  AppSettings({
    this.staleDays = 14,
    this.riskDays = 7,
    this.metricMinObservations = 3,
  });

  final int staleDays;
  final int riskDays;
  final int metricMinObservations;

  AppSettings copyWith({
    int? staleDays,
    int? riskDays,
    int? metricMinObservations,
  }) {
    return AppSettings(
      staleDays: staleDays ?? this.staleDays,
      riskDays: riskDays ?? this.riskDays,
      metricMinObservations:
          metricMinObservations ?? this.metricMinObservations,
    );
  }

  Map<String, dynamic> toJson() => {
    'staleDays': staleDays,
    'riskDays': riskDays,
    'metricMinObservations': metricMinObservations,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      staleDays: asInt(json['staleDays'], 14).clamp(1, 365),
      riskDays: asInt(json['riskDays'], 7).clamp(1, 90),
      metricMinObservations: asInt(
        json['metricMinObservations'],
        3,
      ).clamp(1, 30),
    );
  }
}
