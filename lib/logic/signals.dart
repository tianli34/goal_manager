import '../core/enums.dart';
import '../core/numbers.dart';
import '../models/app_data.dart';
import '../models/goal.dart';
import '../models/update_record.dart';
import 'progress.dart';

class GoalSignal {
  const GoalSignal({
    required this.goalId,
    required this.type,
    required this.message,
    required this.actionLabel,
  });

  final String goalId;
  final AttentionSignal type;
  final String message;
  final String actionLabel;

  int get priority => switch (type) {
    AttentionSignal.dateRisk => 0,
    AttentionSignal.possibleStall => 1,
    AttentionSignal.noRecentUpdate => 2,
    AttentionSignal.insufficientData => 3,
  };
}

DateTime? _latestProgress(Iterable<UpdateRecord> records) {
  DateTime? latest;
  for (final record in records) {
    if (record.type != RecordType.progress) continue;
    if (latest == null || record.timestamp.isAfter(latest)) {
      latest = record.timestamp;
    }
  }
  return latest;
}

DateTime? lastActivityAt(
  Goal goal,
  List<Goal> allGoals,
  List<UpdateRecord> records, [
  Set<String>? visiting,
]) {
  final guard = visiting ?? <String>{};
  if (!guard.add(goal.id)) return null;
  DateTime? latest = _latestProgress(records.where((r) => r.goalId == goal.id));
  latest ??= goal.createdAt;
  if (goal.isMilestone) {
    for (final child in milestoneChildren(goal, allGoals)) {
      final childLatest = lastActivityAt(child, allGoals, records, guard);
      if (childLatest != null &&
          (latest == null || childLatest.isAfter(latest))) {
        latest = childLatest;
      }
    }
  }
  guard.remove(goal.id);
  return latest;
}

int _metricReadingCount(String goalId, List<UpdateRecord> records) => records
    .where(
      (r) =>
          r.goalId == goalId &&
          r.type == RecordType.progress &&
          r.reading != null,
    )
    .length;

List<GoalSignal> computeSignals(AppData data, DateTime now) {
  final settings = data.settings;
  final signals = <GoalSignal>[];
  for (final goal in data.goals) {
    if (goal.isArchived || goal.lifecycle != Lifecycle.active) continue;

    final snapshot = computeSnapshot(
      goal,
      data.goals,
      data.records,
      metricMinObservations: settings.metricMinObservations,
    );
    final planned = plannedRatioFor(goal, data.goals, now);
    final actual = snapshot.ratio;
    final last = lastActivityAt(goal, data.goals, data.records);
    final daysSince = last == null ? null : now.difference(last).inDays;
    final lastOwn = _latestProgress(
      data.records.where((r) => r.goalId == goal.id),
    );
    final ownDaysSince = lastOwn == null
        ? null
        : now.difference(lastOwn).inDays;
    final due = goal.dueDate;
    final dueDays = due == null
        ? null
        : DateTime(
            due.year,
            due.month,
            due.day,
          ).difference(DateTime(now.year, now.month, now.day)).inDays;
    final overdue = dueDays != null && dueDays < 0;

    GoalSignal? signal;

    // 1. 日期风险：临近或超过截止，且进展明显落后（完成型看是否完成）。
    if (dueDays != null &&
        dueDays <= settings.riskDays &&
        snapshot.isComplete == false) {
      var risky = false;
      var reason = '';
      if (overdue) {
        risky = true;
        reason = '已逾期 ${-dueDays} 天';
      } else if (goal.mechanism == Mechanism.completion) {
        risky = true;
        reason = dueDays == 0 ? '今天到期，仍未完成' : '还剩 $dueDays 天，仍未完成';
      } else if (goal.mechanism != Mechanism.subjective &&
          planned != null &&
          actual != null &&
          planned - actual > 0.15) {
        risky = true;
        reason = '还剩 $dueDays 天，落后计划 ${formatPercent(planned - actual)}';
      }
      if (risky) {
        final percentText = actual == null
            ? ''
            : '，当前进度 ${formatPercent(actual)}';
        signal = GoalSignal(
          goalId: goal.id,
          type: AttentionSignal.dateRisk,
          message: '$reason$percentText',
          actionLabel: '调整日期',
        );
      }
    }

    // 2. 可能停滞：有近期记录，但计划进展明显高于实际。
    if (signal == null &&
        (goal.mechanism == Mechanism.cumulative ||
            goal.mechanism == Mechanism.metric) &&
        (goal.mechanism != Mechanism.metric ||
            _metricReadingCount(goal.id, data.records) >=
                settings.metricMinObservations) &&
        ownDaysSince != null &&
        ownDaysSince <= settings.staleDays &&
        planned != null &&
        actual != null &&
        planned - actual > 0.2) {
      signal = GoalSignal(
        goalId: goal.id,
        type: AttentionSignal.possibleStall,
        message: '有记录，但落后计划 ${formatPercent(planned - actual)}，可能停滞',
        actionLabel: '写说明',
      );
    }

    // 3. 许久未记录（里程碑以子项最近记录为准）。
    if (signal == null &&
        daysSince != null &&
        daysSince > settings.staleDays &&
        daysSince >= 0) {
      signal = GoalSignal(
        goalId: goal.id,
        type: AttentionSignal.noRecentUpdate,
        message: '$daysSince 天没有推进记录',
        actionLabel: '更新',
      );
    }

    // 4. 数据不足：指标型读数少于观察窗口。
    if (signal == null && goal.mechanism == Mechanism.metric) {
      final count = _metricReadingCount(goal.id, data.records);
      if (count < settings.metricMinObservations) {
        signal = GoalSignal(
          goalId: goal.id,
          type: AttentionSignal.insufficientData,
          message: '读数不足（$count/${settings.metricMinObservations}），尚无法判断',
          actionLabel: '记录读数',
        );
      }
    }

    if (signal != null) signals.add(signal);
  }

  signals.sort((a, b) {
    final byPriority = a.priority.compareTo(b.priority);
    if (byPriority != 0) return byPriority;
    return a.goalId.compareTo(b.goalId);
  });
  return signals;
}
