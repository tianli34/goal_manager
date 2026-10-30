import 'commitment.dart';
import 'goal.dart';
import 'inbox_item.dart';
import 'json_helpers.dart';
import 'review.dart';
import 'settings.dart';
import 'update_record.dart';

class AppData {
  AppData({
    List<Goal>? goals,
    List<UpdateRecord>? records,
    List<Commitment>? commitments,
    List<Review>? reviews,
    List<InboxItem>? inbox,
    AppSettings? settings,
  }) : goals = goals ?? [],
       records = records ?? [],
       commitments = commitments ?? [],
       reviews = reviews ?? [],
       inbox = inbox ?? [],
       settings = settings ?? AppSettings();

  static const int schemaVersion = 1;

  final List<Goal> goals;
  final List<UpdateRecord> records;
  final List<Commitment> commitments;
  final List<Review> reviews;
  final List<InboxItem> inbox;
  AppSettings settings;

  bool get isEmpty =>
      goals.isEmpty &&
      records.isEmpty &&
      commitments.isEmpty &&
      reviews.isEmpty &&
      inbox.isEmpty;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'goals': goals.map((e) => e.toJson()).toList(),
    'records': records.map((e) => e.toJson()).toList(),
    'commitments': commitments.map((e) => e.toJson()).toList(),
    'reviews': reviews.map((e) => e.toJson()).toList(),
    'inbox': inbox.map((e) => e.toJson()).toList(),
    'settings': settings.toJson(),
  };

  factory AppData.fromJson(Map<String, dynamic> json) {
    final version = asInt(json['schemaVersion'], schemaVersion);
    if (version > schemaVersion) {
      throw FormatException('备份来自更高版本（v$version），当前应用无法读取。');
    }
    return AppData(
      goals: asMapList(json['goals']).map(Goal.fromJson).toList(),
      records: asMapList(json['records']).map(UpdateRecord.fromJson).toList(),
      commitments: asMapList(json['commitments'])
          .map(Commitment.fromJson)
          .toList(),
      reviews: asMapList(json['reviews']).map(Review.fromJson).toList(),
      inbox: asMapList(json['inbox']).map(InboxItem.fromJson).toList(),
      settings: AppSettings.fromJson(asMap(json['settings'])),
    );
  }
}
