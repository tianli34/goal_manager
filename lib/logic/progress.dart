import '../core/date_utils.dart';
import '../core/enums.dart';
import '../core/numbers.dart';
import '../models/goal.dart';
import '../models/update_record.dart';

List<Goal> milestoneChildren(Goal parent, Iterable<Goal> allGoals) {
  return allGoals
      .where((g) => g.parentGoalId == parent.id && !g.isArchived)
      .toList();
}

List<Goal> requiredChildren(Goal parent, Iterable<Goal> allGoals) {
  final children = milestoneChildren(parent, allGoals);
  final required = children.where((g) => g.isRequired).toList();
  return required.isEmpty ? children : required;
}

bool milestoneRequirementsMet(Goal parent, Iterable<Goal> allGoals) {
  final children = milestoneChildren(parent, allGoals);
  if (children.isEmpty) return false;
  return requiredChildren(
    parent,
    allGoals,
  ).every((g) => g.lifecycle == Lifecycle.completed);
}

/// 同方向判定：目标值可能大于或小于起始值。
bool reachedTarget(Goal goal, double value) {
  final direction = goal.targetValue >= goal.startValue ? 1 : -1;
  return direction * (value - goal.targetValue) >= -1e-9;
}

double _valueRatio(Goal goal, double value) {
  final span = goal.targetValue - goal.startValue;
  if (span == 0) return reachedTarget(goal, value) ? 1 : 0;
  return (value - goal.startValue) / span;
}

class StableReadingInfo {
  const StableReadingInfo({
    required this.count,
    required this.required,
    required this.readingCount,
  });

  final int count;
  final int required;
  final int readingCount;

  bool get achieved => required > 0 && count >= required;
  bool get hasEnoughData => readingCount >= required;
}

StableReadingInfo stableReadingInfo(Goal goal, List<UpdateRecord> records) {
  final readings =
      records
          .where(
            (r) =>
                r.goalId == goal.id &&
                r.type == RecordType.progress &&
                r.reading != null,
          )
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final window = goal.stableWindow.clamp(1, 30);
  var count = 0;
  for (final record in readings.reversed) {
    if (reachedTarget(goal, record.reading!)) {
      count++;
      if (count >= window) break;
    } else {
      break;
    }
  }
  return StableReadingInfo(
    count: count,
    required: window,
    readingCount: readings.length,
  );
}

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.ratio,
    required this.isComplete,
    required this.rawValueText,
    required this.detailText,
    this.childDone = 0,
    this.childTotal = 0,
    this.stableCount = 0,
    this.stableWindow = 0,
    this.readingCount = 0,
    this.readyToComplete = false,
  });

  final double? ratio;
  final bool isComplete;
  final String rawValueText;
  final String detailText;
  final int childDone;
  final int childTotal;
  final int stableCount;
  final int stableWindow;
  final int readingCount;
  final bool readyToComplete;

  bool get hasRatio => ratio != null;
  double get clampedRatio => (ratio ?? 0).clamp(0, 1).toDouble();
  bool get isStable => stableWindow > 0 && stableCount >= stableWindow;
}

ProgressSnapshot computeSnapshot(
  Goal goal,
  List<Goal> allGoals,
  List<UpdateRecord> records, {
  int metricMinObservations = 3,
}) {
  final isComplete = goal.lifecycle == Lifecycle.completed;
  switch (goal.mechanism) {
    case Mechanism.completion:
      return ProgressSnapshot(
        ratio: isComplete ? 1 : 0,
        isComplete: isComplete,
        rawValueText: isComplete ? '已完成' : '未完成',
        detailText: isComplete ? '完成型目标没有中间进度' : '完成后即达成，无中间进度',
      );
    case Mechanism.cumulative:
      final ratio = _valueRatio(goal, goal.currentValue);
      return ProgressSnapshot(
        ratio: ratio,
        isComplete: isComplete,
        rawValueText:
            '${formatNumber(goal.currentValue)} / ${formatNumber(goal.targetValue)} ${goal.unit}'
                .trim(),
        detailText: isComplete ? '已达目标值' : '原始累计量',
      );
    case Mechanism.metric:
      final stable = stableReadingInfo(goal, records);
      return ProgressSnapshot(
        ratio: _valueRatio(goal, goal.currentValue),
        isComplete: isComplete,
        rawValueText: '当前 ${formatNumber(goal.currentValue)} ${goal.unit}'
            .trim(),
        detailText:
            '${formatNumber(goal.startValue)} → ${formatNumber(goal.targetValue)} ${goal.unit}'
                .trim(),
        stableCount: stable.count,
        stableWindow: stable.required,
        readingCount: stable.readingCount,
        readyToComplete: stable.achieved && !isComplete,
      );
    case Mechanism.subjective:
      return ProgressSnapshot(
        ratio: goal.subjectivePercent / 100,
        isComplete: isComplete,
        rawValueText: '${goal.subjectivePercent}%',
        detailText: '进度由你主观判断，系统不会自动修改',
      );
    case Mechanism.milestone:
      final children = milestoneChildren(goal, allGoals);
      double? ratio;
      if (children.isNotEmpty) {
        var weightSum = 0.0;
        var weighted = 0.0;
        for (final child in children) {
          final childRatio =
              computeSnapshot(
                child,
                allGoals,
                records,
                metricMinObservations: metricMinObservations,
              ).ratio ??
              0;
          final weight = child.weight <= 0 ? 1.0 : child.weight;
          weighted += childRatio * weight;
          weightSum += weight;
        }
        ratio = weightSum == 0 ? null : weighted / weightSum;
      }
      final done = children
          .where((g) => g.lifecycle == Lifecycle.completed)
          .length;
      final requiredMet = milestoneRequirementsMet(goal, allGoals);
      return ProgressSnapshot(
        ratio: ratio,
        isComplete: isComplete,
        rawValueText: children.isEmpty
            ? '尚无子项'
            : '${formatPercent(ratio ?? 0)} · $done/${children.length} 子项',
        detailText: requiredMet
            ? '所有必需子项已完成'
            : children.isEmpty
            ? '添加子项后自动上卷进度'
            : '进度由子项加权上卷，父级不可直接修改',
        childDone: done,
        childTotal: children.length,
        readyToComplete: requiredMet && !isComplete,
      );
  }
}

/// 时间消耗比例，允许 <0 或 >1；无起止日期时为 null。
double? timeElapsedRatio(Goal goal, DateTime now) {
  final start = goal.startDate;
  final due = goal.dueDate;
  if (start == null || due == null) return null;
  final total = due.difference(start).inMilliseconds;
  if (total <= 0) return now.isBefore(due) ? 0 : 1;
  return now.difference(start).inMilliseconds / total;
}

double? plannedRatioFor(
  Goal goal,
  List<Goal> allGoals,
  DateTime now, [
  Set<String>? visiting,
]) {
  final guard = visiting ?? <String>{};
  if (!guard.add(goal.id)) return null;
  try {
    switch (goal.mechanism) {
      case Mechanism.cumulative:
      case Mechanism.metric:
        final ratio = timeElapsedRatio(goal, now);
        return ratio?.clamp(0, 1).toDouble();
      case Mechanism.completion:
      case Mechanism.subjective:
        return null;
      case Mechanism.milestone:
        final children = milestoneChildren(goal, allGoals);
        var weightSum = 0.0;
        var weighted = 0.0;
        for (final child in children) {
          final planned = plannedRatioFor(child, allGoals, now, guard);
          if (planned == null) continue;
          final weight = child.weight <= 0 ? 1.0 : child.weight;
          weighted += planned * weight;
          weightSum += weight;
        }
        return weightSum == 0 ? null : weighted / weightSum;
    }
  } finally {
    guard.remove(goal.id);
  }
}

class PacingInfo {
  const PacingInfo({
    this.timeRatio,
    this.plannedRatio,
    this.timeText,
    this.plannedText,
    this.gap,
    this.remainingText,
    this.paceText,
    this.note,
  });

  final double? timeRatio;
  final double? plannedRatio;
  final String? timeText;
  final String? plannedText;

  /// 实际进度 - 计划进度。仅累积型、里程碑型直接展示。
  final double? gap;
  final String? remainingText;
  final String? paceText;
  final String? note;

  bool get isBehind => gap != null && gap! < -0.05;
  bool get isAhead => gap != null && gap! > 0.05;
}

PacingInfo computePacing(
  Goal goal,
  ProgressSnapshot snapshot,
  List<Goal> allGoals,
  DateTime now,
) {
  final timeRatio = timeElapsedRatio(goal, now);
  final planned = plannedRatioFor(goal, allGoals, now);
  String? timeText;
  if (timeRatio == null) {
    timeText = '未设置起止日期，不计算时间线';
  } else if (timeRatio < 0) {
    timeText = '开始日期在未来';
  } else if (timeRatio > 1) {
    timeText = '已超过截止时间';
  } else {
    timeText = '时间已过 ${formatPercent(timeRatio)}';
  }

  final remaining = remainingText(goal.dueDate, now);
  String? plannedText;
  String? paceText;
  String? note;
  double? gap;

  switch (goal.mechanism) {
    case Mechanism.completion:
      break;
    case Mechanism.cumulative:
      if (planned != null) {
        final expectedValue =
            goal.startValue + (goal.targetValue - goal.startValue) * planned;
        plannedText = '线性计划：预计 ${formatNumber(expectedValue)} ${goal.unit}'
            .trim();
        note = '计划假设：匀速推进';
        gap = (snapshot.ratio ?? 0) - planned;
        if (goal.dueDate != null &&
            goal.dueDate!.isAfter(now) &&
            !snapshot.isComplete) {
          final days = dateOnly(goal.dueDate!)
              .difference(dateOnly(now))
              .inDays
              .clamp(1, 36500);
          final need = (goal.targetValue - goal.currentValue) / days;
          paceText = need >= 0
              ? '剩余 $days 天，每天约需 +${formatNumber(need)} ${goal.unit}'.trim()
              : '已超过目标值 ${formatNumber(-need * days)} ${goal.unit}'.trim();
        }
      }
      break;
    case Mechanism.metric:
      if (planned != null) {
        final expected =
            goal.startValue + (goal.targetValue - goal.startValue) * planned;
        plannedText = '线性参考：预计读数 ${formatNumber(expected)} ${goal.unit}'.trim();
        note = '仅作参考：指标会波动，重点看稳定达标';
      }
      final stable = snapshot.stableWindow;
      if (stable > 0) {
        paceText = snapshot.isStable
            ? '已连续 $stable 次达标'
            : '连续达标 ${snapshot.stableCount}/$stable 次';
      }
      break;
    case Mechanism.subjective:
      plannedText = null;
      note = '不判断落后，进度以你的自评和记录为准';
      break;
    case Mechanism.milestone:
      if (planned != null) {
        plannedText = '子项计划加权：${formatPercent(planned)}';
        gap = (snapshot.ratio ?? 0) - planned;
        note = '父级进度为子项加权只读值';
      } else {
        plannedText = '子项未设置完整日期，仅显示时间消耗';
      }
      break;
  }

  return PacingInfo(
    timeRatio: timeRatio,
    plannedRatio: planned,
    timeText: timeText,
    plannedText: plannedText,
    gap: gap,
    remainingText: remaining,
    paceText: paceText,
    note: note,
  );
}

String gapText(PacingInfo pacing) {
  final gap = pacing.gap;
  if (gap == null) return '';
  final percent = formatPercent(gap.abs());
  if (gap < -0.05) return '落后计划 $percent';
  if (gap > 0.05) return '超前计划 $percent';
  return '与计划基本同步';
}

/// 串行里程碑中，前面还有未完成子项时，当前子项处于待解锁状态。
bool isChildLocked(Goal child, List<Goal> allGoals) {
  if (child.lifecycle != Lifecycle.pending) return false;
  final parentId = child.parentGoalId;
  if (parentId == null) return false;
  Goal? parent;
  for (final candidate in allGoals) {
    if (candidate.id == parentId) {
      parent = candidate;
      break;
    }
  }
  if (parent == null ||
      !parent.isMilestone ||
      parent.executionMode != ExecutionMode.sequential) {
    return false;
  }
  final siblings = milestoneChildren(parent, allGoals);
  for (final sibling in siblings) {
    if (sibling.id == child.id) return false;
    if (sibling.lifecycle == Lifecycle.completed ||
        sibling.lifecycle == Lifecycle.terminated) {
      continue;
    }
    return true;
  }
  return false;
}

/// 串行里程碑的“当前聚焦”子项（第一个未完成的子项）。
Goal? focusedChild(Goal parent, Iterable<Goal> allGoals) {
  if (!parent.isMilestone || parent.executionMode != ExecutionMode.sequential) {
    return null;
  }
  for (final child in milestoneChildren(parent, allGoals)) {
    if (child.lifecycle != Lifecycle.completed &&
        child.lifecycle != Lifecycle.terminated) {
      return child;
    }
  }
  return null;
}
