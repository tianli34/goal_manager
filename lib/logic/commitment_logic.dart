import '../core/enums.dart';
import '../core/numbers.dart';
import '../models/app_data.dart';
import '../models/commitment.dart';
import '../models/goal.dart';
import '../models/update_record.dart';

class CommitmentProgress {
  const CommitmentProgress({
    required this.fulfilled,
    required this.expired,
    required this.statusLabel,
    required this.summary,
    this.ratio,
    this.detail,
  });

  final bool fulfilled;
  final bool expired;
  final String statusLabel;
  final String summary;
  final double? ratio;
  final String? detail;
}

bool _atOrBeyond(Goal goal, double value, double expected) {
  final direction = goal.targetValue >= goal.startValue ? 1 : -1;
  return direction * (value - expected) >= -1e-9;
}

bool _inWindow(DateTime time, Commitment commitment) =>
    !time.isBefore(commitment.start) && time.isBefore(commitment.end);

List<UpdateRecord> _windowRecords(Commitment c, AppData data) =>
    data.records
        .where((r) => r.goalId == c.goalId && _inWindow(r.timestamp, c))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

CommitmentProgress computeCommitmentProgress(
  Commitment commitment,
  AppData data,
  DateTime now,
) {
  Goal? goal;
  for (final candidate in data.goals) {
    if (candidate.id == commitment.goalId) {
      goal = candidate;
      break;
    }
  }
  final expired =
      !now.isBefore(commitment.end) &&
      commitment.status != CommitmentStatus.cancelled;

  if (commitment.status == CommitmentStatus.cancelled) {
    return CommitmentProgress(
      fulfilled: false,
      expired: false,
      statusLabel: '已取消',
      summary: commitment.note.isEmpty ? '承诺已取消' : commitment.note,
    );
  }
  if (goal == null) {
    return CommitmentProgress(
      fulfilled: false,
      expired: expired,
      statusLabel: expired ? '已到期' : '进行中',
      summary: '关联目标已不存在',
    );
  }

  final records = _windowRecords(commitment, data);
  var fulfilled = false;
  var summary = '';
  double? ratio;
  String? detail;

  switch (goal.mechanism) {
    case Mechanism.completion:
      fulfilled =
          goal.completedAt != null && _inWindow(goal.completedAt!, commitment);
      summary = fulfilled ? '已完成' : '尚未完成';
      ratio = fulfilled ? 1 : 0;
      detail = '完成型承诺：在周期内标记完成';
      break;
    case Mechanism.cumulative:
      final amount = commitment.plannedAmount ?? 0;
      final sum = records
          .where((r) => r.type == RecordType.progress && r.delta != null)
          .fold<double>(0, (value, r) => value + r.delta!);
      fulfilled = amount > 0 && sum >= amount - 1e-9;
      ratio = amount == 0 ? null : sum / amount;
      summary =
          '已推进 ${formatNumberSigned(sum)} / ${formatNumberSigned(amount)} ${goal.unit}'
              .trim();
      detail = '按周期内真实增量计算，不受目标值修改影响';
      break;
    case Mechanism.metric:
      final expected = commitment.plannedAmount;
      final readings = records
          .where((r) => r.type == RecordType.progress && r.reading != null)
          .toList();
      if (expected != null) {
        fulfilled = readings.any(
          (r) => _atOrBeyond(goal!, r.reading!, expected),
        );
        summary = readings.isEmpty
            ? '期望读数 ${formatNumber(expected)} ${goal.unit}'.trim()
            : '最新读数 ${formatNumber(readings.last.reading!)} / 期望 ${formatNumber(expected)} ${goal.unit}'
                  .trim();
        if (readings.isNotEmpty) {
          final span = expected - (commitment.baselineValue ?? goal.startValue);
          if (span != 0) {
            ratio =
                (readings.last.reading! -
                    (commitment.baselineValue ?? goal.startValue)) /
                span;
          }
        }
      } else {
        fulfilled =
            goal.completedAt != null &&
            _inWindow(goal.completedAt!, commitment);
        summary = fulfilled ? '已达成' : '尚未达成';
        ratio = fulfilled ? 1 : 0;
      }
      detail = '指标型承诺是结果期望，波动不代表投入不足';
      break;
    case Mechanism.subjective:
      final amount = commitment.plannedAmount ?? 0;
      final baseline = commitment.baselineValue ?? 0;
      int? latest;
      for (final record in records) {
        if (record.subjectivePercent != null) {
          latest = record.subjectivePercent;
        }
      }
      final current = latest ?? baseline.round();
      fulfilled = amount > 0 && current - baseline >= amount - 1e-9;
      ratio = amount == 0 ? null : (current - baseline) / amount;
      summary =
          '自评 ${baseline.round()}% → $current%（目标 +${formatNumber(amount)} 点）';
      detail = '进度完全由你判断，系统不判断落后';
      break;
    case Mechanism.milestone:
      Goal? target;
      if (commitment.targetChildId != null) {
        for (final candidate in data.goals) {
          if (candidate.id == commitment.targetChildId) {
            target = candidate;
            break;
          }
        }
      }
      if (target != null) {
        fulfilled =
            target.completedAt != null &&
            _inWindow(target.completedAt!, commitment);
        summary = '子项「${target.title}」${fulfilled ? '已完成' : '尚未完成'}';
        detail = '里程碑承诺：指定子项完成即兑现';
      } else {
        fulfilled =
            goal.completedAt != null &&
            _inWindow(goal.completedAt!, commitment);
        summary = fulfilled ? '里程碑已完成' : '里程碑尚未完成';
        detail = '里程碑承诺：必需子项全部完成即兑现';
      }
      ratio = fulfilled ? 1 : 0;
      break;
  }

  final statusLabel = fulfilled
      ? '已兑现'
      : expired
      ? '已到期未兑现'
      : commitment.status == CommitmentStatus.adjusted
      ? '已调整'
      : '进行中';

  return CommitmentProgress(
    fulfilled: fulfilled,
    expired: expired,
    statusLabel: statusLabel,
    summary: summary,
    ratio: ratio,
    detail: detail,
  );
}

List<Commitment> commitmentsForGoal(
  String goalId,
  List<Commitment> commitments,
) {
  final list = commitments.where((c) => c.goalId == goalId).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return list;
}

String commitmentAmountLabel(Commitment commitment, Goal? goal) {
  if (commitment.plannedAmount == null) return '';
  final unit = goal?.unit ?? '';
  switch (goal?.mechanism) {
    case Mechanism.subjective:
      return '+${formatNumber(commitment.plannedAmount!)} 点';
    case Mechanism.cumulative:
      return '+${formatNumber(commitment.plannedAmount!)} $unit'.trim();
    case Mechanism.metric:
      return '读数 ${formatNumber(commitment.plannedAmount!)} $unit'.trim();
    default:
      return formatNumber(commitment.plannedAmount!);
  }
}
