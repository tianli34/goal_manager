import 'dart:convert';

import '../core/enums.dart';
import '../core/date_utils.dart';
import '../core/numbers.dart';
import '../logic/commitment_logic.dart';
import '../logic/record_format.dart';
import '../models/app_data.dart';
import '../models/goal.dart';

String buildJsonExport(AppData data) =>
    const JsonEncoder.withIndent('  ').convert(data.toJson());

String _goalRawValue(Goal goal) {
  switch (goal.mechanism) {
    case Mechanism.completion:
      return goal.lifecycle == Lifecycle.completed ? '已完成' : '未完成';
    case Mechanism.cumulative:
      return '当前 ${formatNumber(goal.currentValue)} / 目标 ${formatNumber(goal.targetValue)} ${goal.unit}'
          .trim();
    case Mechanism.metric:
      return '${formatNumber(goal.startValue)} → ${formatNumber(goal.targetValue)} ${goal.unit}，当前 ${formatNumber(goal.currentValue)}'
          .trim();
    case Mechanism.subjective:
      return '${goal.subjectivePercent}%';
    case Mechanism.milestone:
      return '由子项加权上卷';
  }
}

String buildMarkdownExport(AppData data, DateTime now) {
  final buffer = StringBuffer()
    ..writeln('# 目标管理备份')
    ..writeln()
    ..writeln('- 导出时间：${formatDateTime(now)}')
    ..writeln('- 目标数：${data.goals.length}')
    ..writeln('- 更新记录：${data.records.length}')
    ..writeln('- 承诺：${data.commitments.length}')
    ..writeln('- 复盘：${data.reviews.length}')
    ..writeln();

  final topLevel = data.goals.where((g) => g.parentGoalId == null).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  buffer
    ..writeln('## 目标')
    ..writeln();
  for (final goal in topLevel) {
    _writeGoal(buffer, goal, data, 0);
  }
  if (topLevel.isEmpty) {
    buffer
      ..writeln('（无）')
      ..writeln();
  }

  buffer
    ..writeln('## 承诺')
    ..writeln();
  if (data.commitments.isEmpty) {
    buffer.writeln('（无）');
  } else {
    final sorted = [...data.commitments]
      ..sort((a, b) => a.start.compareTo(b.start));
    for (final commitment in sorted) {
      Goal? goal;
      for (final candidate in data.goals) {
        if (candidate.id == commitment.goalId) {
          goal = candidate;
          break;
        }
      }
      final progress = computeCommitmentProgress(commitment, data, now);
      buffer
        ..writeln(
          '- ${goal?.title ?? '（目标已删除）'} · ${dayRangeText(commitment.start, commitment.end)} · ${progress.statusLabel}',
        )
        ..writeln('  - ${progress.summary}');
      if (commitment.note.isNotEmpty) {
        buffer.writeln('  - 备注：${commitment.note}');
      }
      for (final change in commitment.changes) {
        buffer.writeln(
          '  - 变更 ${formatDateTime(change.at)}：${change.note}'
          '${change.oldAmount == null ? '' : '（${formatNumber(change.oldAmount!)} → ${change.newAmount == null ? '-' : formatNumber(change.newAmount!)}）'}',
        );
      }
    }
  }
  buffer.writeln();

  buffer
    ..writeln('## 复盘')
    ..writeln();
  if (data.reviews.isEmpty) {
    buffer.writeln('（无）');
  } else {
    final sorted = [...data.reviews]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final review in sorted) {
      buffer
        ..writeln(
          '### ${dayRangeText(review.start, review.end)} · ${review.decision.label}',
        )
        ..writeln('- 发生了什么：${review.whatHappened}')
        ..writeln('- 原计划仍值得吗：${review.stillWorthPlan ? '是' : '否'}')
        ..writeln('- 反思：${review.planReflection}')
        ..writeln('- 下一步：${review.nextStep}')
        ..writeln();
    }
  }

  buffer
    ..writeln('## 收集箱')
    ..writeln();
  if (data.inbox.isEmpty) {
    buffer.writeln('（空）');
  } else {
    for (final item in data.inbox) {
      buffer.writeln('- ${formatDateTime(item.createdAt)} · ${item.text}');
    }
  }
  buffer.writeln();

  return buffer.toString();
}

void _writeGoal(StringBuffer buffer, Goal goal, AppData data, int depth) {
  final mark = '#' * (2 + depth).clamp(2, 6).toInt();
  buffer
    ..writeln('$mark ${goal.title}')
    ..writeln('- 机制：${goal.mechanism.label} · 状态：${goal.lifecycle.label}');
  if (goal.domain.isNotEmpty) {
    buffer.writeln('- 领域：${goal.domain}');
  }
  if (goal.tags.isNotEmpty) {
    buffer.writeln('- 标签：${goal.tags.join('、')}');
  }
  buffer
    ..writeln(
      '- 起止：${formatDate(goal.startDate)} → ${formatDate(goal.dueDate)}',
    )
    ..writeln('- 原始量：${_goalRawValue(goal)}');
  if (goal.successCriteria.isNotEmpty) {
    buffer.writeln('- 达成条件：${goal.successCriteria}');
  }
  if (goal.why.isNotEmpty) {
    buffer.writeln('- 为什么：${goal.why}');
  }
  if (goal.mechanism == Mechanism.milestone) {
    buffer.writeln(
      '- 子项模式：${goal.executionMode.label} · 权重：${formatNumber(goal.weight)} · 必需：${goal.isRequired ? '是' : '否'}',
    );
  }
  if (goal.completedAt != null) {
    buffer.writeln('- 完成时间：${formatDateTime(goal.completedAt!)}');
  }
  if (goal.isArchived) {
    buffer.writeln('- 已归档');
  }
  buffer.writeln();

  final records = data.records.where((r) => r.goalId == goal.id).toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (records.isNotEmpty) {
    final recordMark = '#' * (3 + depth).clamp(3, 6).toInt();
    buffer.writeln('$recordMark 更新记录');
    for (final record in records) {
      final body = recordBody(record);
      buffer.writeln(
        '- ${formatDateTime(record.timestamp)} · ${record.type.label} · ${recordTitle(record, goal)}${body.isEmpty ? '' : ' — $body'}',
      );
    }
    buffer.writeln();
  }

  final children = data.goals.where((g) => g.parentGoalId == goal.id).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  for (final child in children) {
    _writeGoal(buffer, child, data, depth + 1);
  }
}
