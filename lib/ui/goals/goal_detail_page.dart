import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../core/enums.dart';
import '../../core/numbers.dart';
import '../../logic/commitment_logic.dart';
import '../../logic/progress.dart';
import '../../logic/record_format.dart';
import '../../models/commitment.dart';
import '../../models/goal.dart';
import '../../models/update_record.dart';
import '../home.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/commitment_card.dart';
import '../widgets/commitment_sheet.dart';
import '../widgets/common.dart';
import 'goal_editor_page.dart';
import 'update_sheet.dart';

class GoalDetailPage extends StatelessWidget {
  const GoalDetailPage({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    final goal = repo.goalById(goalId);
    if (goal == null) {
      return Scaffold(
        appBar: AppBar(actions: const [HomeButton()]),
        body: const EmptyState(
          icon: Icons.search_off,
          title: '目标不存在',
          message: '它可能已经被删除或归档。',
        ),
      );
    }
    final snapshot = computeSnapshot(
      goal,
      repo.goals,
      repo.records,
      metricMinObservations: repo.settings.metricMinObservations,
    );
    final pacing = computePacing(goal, snapshot, repo.goals, DateTime.now());
    final parent = goal.parentGoalId == null
        ? null
        : repo.goalById(goal.parentGoalId!);
    final children = goal.isMilestone
        ? repo.childrenOf(goal.id)
        : const <Goal>[];
    final commitments = commitmentsForGoal(goal.id, repo.commitments);
    final timeline = repo.recordsFor(goal.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          const HomeButton(),
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context, goal),
          ),
          PopupMenuButton<_GoalAction>(
            tooltip: '更多',
            onSelected: (action) => _handleAction(context, goal, action),
            itemBuilder: (context) => _menuItems(goal),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
        children: [
          _Header(
            goal: goal,
            parent: parent,
            snapshot: snapshot,
            onOpenParent: parent == null
                ? null
                : () => _openGoal(context, parent.id),
          ),
          if (_notice(goal) != null) ...[
            const SizedBox(height: 10),
            _Notice(
              icon: _noticeIcon(goal),
              text: _notice(goal)!,
              color: _noticeColor(goal, context),
            ),
          ],
          const SizedBox(height: 12),
          _ProgressCard(
            goal: goal,
            snapshot: snapshot,
            pacing: pacing,
            onStart: () => _start(context, goal),
            onUpdate: () => showUpdateSheet(context, goal.id),
            onComplete: () => _complete(context, goal),
            onReopen: () => _reopen(context, goal),
            onNote: () => showNoteSheet(context, goal.id),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            goal: goal,
            parent: parent,
            onOpenParent: parent == null
                ? null
                : () => _openGoal(context, parent.id),
          ),
          const SizedBox(height: 8),
          _CommitmentSection(goal: goal, commitments: commitments),
          if (goal.isMilestone) ...[
            const SizedBox(height: 8),
            _ChildrenSection(goal: goal, children: children),
          ],
          const SizedBox(height: 8),
          _TimelineSection(goal: goal, records: timeline),
        ],
      ),
    );
  }

  void _edit(BuildContext context, Goal goal) {
    final repo = RepositoryScope.read(context);
    final parent = goal.parentGoalId == null
        ? null
        : repo.goalById(goal.parentGoalId!);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoalEditorPage(goal: goal, parent: parent),
      ),
    );
  }

  List<PopupMenuEntry<_GoalAction>> _menuItems(Goal goal) {
    final items = <PopupMenuEntry<_GoalAction>>[];
    switch (goal.lifecycle) {
      case Lifecycle.pending:
        items.add(
          const PopupMenuItem(value: _GoalAction.start, child: Text('开始目标')),
        );
        break;
      case Lifecycle.active:
        items.add(
          const PopupMenuItem(value: _GoalAction.pause, child: Text('暂停目标')),
        );
        break;
      case Lifecycle.paused:
        items.add(
          const PopupMenuItem(value: _GoalAction.resume, child: Text('继续目标')),
        );
        break;
      case Lifecycle.completed:
        items.add(
          const PopupMenuItem(value: _GoalAction.reopen, child: Text('重新打开')),
        );
        break;
      case Lifecycle.terminated:
        items.add(
          const PopupMenuItem(value: _GoalAction.restore, child: Text('恢复目标')),
        );
        break;
    }
    if (goal.lifecycle != Lifecycle.completed &&
        goal.lifecycle != Lifecycle.terminated) {
      items.add(
        const PopupMenuItem(value: _GoalAction.terminate, child: Text('终止目标')),
      );
    }
    if (goal.parentGoalId != null) {
      items.add(
        const PopupMenuItem(value: _GoalAction.detach, child: Text('从父级移除')),
      );
    }
    items.add(
      PopupMenuItem(
        value: goal.isArchived ? _GoalAction.unarchive : _GoalAction.archive,
        child: Text(goal.isArchived ? '取消归档' : '归档目标'),
      ),
    );
    return items;
  }

  Future<void> _handleAction(
    BuildContext context,
    Goal goal,
    _GoalAction action,
  ) async {
    final repo = RepositoryScope.read(context);
    String? error;
    switch (action) {
      case _GoalAction.pause:
        if (!await confirmAction(
          context,
          title: '暂停目标？',
          message: '暂停期间不会再产生任何关注提醒，随时可以继续。',
          confirmLabel: '暂停',
        )) {
          return;
        }
        error = repo.changeLifecycle(goal.id, Lifecycle.paused);
        break;
      case _GoalAction.resume:
        error = repo.changeLifecycle(goal.id, Lifecycle.active);
        break;
      case _GoalAction.start:
        error = repo.changeLifecycle(goal.id, Lifecycle.active);
        break;
      case _GoalAction.restore:
        if (!await confirmAction(
          context,
          title: '恢复目标？',
          message: '恢复后会重新参与关注信号与统计。',
          confirmLabel: '恢复',
        )) {
          return;
        }
        error = repo.changeLifecycle(goal.id, Lifecycle.active);
        break;
      case _GoalAction.reopen:
        await _reopen(context, goal);
        return;
      case _GoalAction.terminate:
        if (!await confirmAction(
          context,
          title: '终止目标？',
          message: '终止不会删除历史和记录，目标不再参与统计与提醒。之后可以恢复。',
          confirmLabel: '终止',
          destructive: true,
        )) {
          return;
        }
        error = repo.changeLifecycle(goal.id, Lifecycle.terminated);
        break;
      case _GoalAction.archive:
        if (!await confirmAction(
          context,
          title: '归档目标？',
          message: '归档会连同子项一起隐藏，但不影响已完成状态；随时可以取消归档。',
          confirmLabel: '归档',
        )) {
          return;
        }
        repo.setArchived(goal.id, true);
        break;
      case _GoalAction.unarchive:
        repo.setArchived(goal.id, false);
        break;
      case _GoalAction.detach:
        if (!await confirmAction(
          context,
          title: '从父级移除？',
          message: '移除后它将成为独立目标，历史记录会保留。',
          confirmLabel: '移除',
        )) {
          return;
        }
        repo.detachChild(goal.id);
        break;
    }
    if (context.mounted) {
      if (error != null) {
        showAppSnack(context, error, error: true);
      } else {
        showAppSnack(context, '已更新');
      }
    }
  }

  void _start(BuildContext context, Goal goal) {
    final repo = RepositoryScope.read(context);
    final error = repo.changeLifecycle(goal.id, Lifecycle.active);
    if (context.mounted) {
      if (error != null) {
        showAppSnack(context, error, error: true);
      } else {
        showAppSnack(context, '已启动目标');
      }
    }
  }

  void _complete(BuildContext context, Goal goal) {
    if (goal.mechanism == Mechanism.completion) {
      showUpdateSheet(context, goal.id);
      return;
    }
    if (goal.mechanism == Mechanism.milestone) {
      final repo = RepositoryScope.read(context);
      final error = repo.markComplete(goal.id);
      if (error != null) {
        showAppSnack(context, error, error: true);
      } else {
        showAppSnack(context, '里程碑已完成');
      }
      return;
    }
    showUpdateSheet(context, goal.id);
  }

  Future<void> _reopen(BuildContext context, Goal goal) async {
    final repo = RepositoryScope.read(context);
    final reason = await promptText(
      context,
      title: '重新打开目标',
      hint: '原因（可选）',
      confirmLabel: '重新打开',
      allowEmpty: true,
    );
    if (reason == null) return;
    final error = repo.reopen(goal.id, reason: reason);
    if (context.mounted) {
      if (error != null) {
        showAppSnack(context, error, error: true);
      } else {
        showAppSnack(context, '已重新打开');
      }
    }
  }

  void _openGoal(BuildContext context, String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GoalDetailPage(goalId: id)),
    );
  }

  String? _notice(Goal goal) {
    if (goal.isArchived) return '已归档，不参与关注信号和默认列表。';
    return switch (goal.lifecycle) {
      Lifecycle.pending => '未激活。点击启动后开始推进，也可以直接记录。',
      Lifecycle.paused => '已暂停，不产生任何关注提醒。',
      Lifecycle.completed =>
        '已完成于 ${formatDateTime(goal.completedAt ?? goal.updatedAt)}。后续记录不会自动重新打开。',
      Lifecycle.terminated => '已终止，历史记录完整保留。',
      Lifecycle.active => null,
    };
  }

  IconData _noticeIcon(Goal goal) {
    if (goal.isArchived) return Icons.inventory_2_outlined;
    return switch (goal.lifecycle) {
      Lifecycle.pending => Icons.schedule,
      Lifecycle.paused => Icons.pause_circle_outline,
      Lifecycle.completed => Icons.check_circle_outline,
      Lifecycle.terminated => Icons.block,
      Lifecycle.active => Icons.info_outline,
    };
  }

  Color _noticeColor(Goal goal, BuildContext context) {
    if (goal.isArchived) return Theme.of(context).colorScheme.outline;
    return lifecycleColor(goal.lifecycle);
  }
}

enum _GoalAction {
  pause,
  resume,
  start,
  reopen,
  terminate,
  restore,
  archive,
  unarchive,
  detach,
}

class _Header extends StatelessWidget {
  const _Header({
    required this.goal,
    required this.parent,
    required this.snapshot,
    this.onOpenParent,
  });

  final Goal goal;
  final Goal? parent;
  final ProgressSnapshot snapshot;
  final VoidCallback? onOpenParent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            MechanismChip(goal.mechanism),
            LifecycleChip(goal.lifecycle),
            if (goal.domain.isNotEmpty) TagPill(goal.domain),
            ...goal.tags.map((tag) => TagPill('#$tag')),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          goal.title,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
        ),
        if (goal.why.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '“${goal.why}”',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (parent != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: onOpenParent,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.subdirectory_arrow_right,
                    size: 14,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '属于 ${parent!.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.primary),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 15, color: scheme.primary),
                ],
              ),
            ),
          ),
        ],
        if (goal.dueDate != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${formatDate(goal.startDate)} → ${formatDate(goal.dueDate)} · ${remainingText(goal.dueDate, DateTime.now())}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.goal,
    required this.snapshot,
    required this.pacing,
    required this.onStart,
    required this.onUpdate,
    required this.onComplete,
    required this.onReopen,
    required this.onNote,
  });

  final Goal goal;
  final ProgressSnapshot snapshot;
  final PacingInfo pacing;
  final VoidCallback onStart;
  final VoidCallback onUpdate;
  final VoidCallback onComplete;
  final VoidCallback onReopen;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = mechanismColor(goal.mechanism);
    final percent = snapshot.ratio == null
        ? null
        : formatPercent(snapshot.ratio!);
    final gap = gapText(pacing);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot.rawValueText,
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        snapshot.detailText,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (percent != null &&
                    goal.mechanism != Mechanism.subjective &&
                    goal.mechanism != Mechanism.milestone)
                  Text(
                    percent,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
              ],
            ),
            if (snapshot.ratio != null) ...[
              const SizedBox(height: 12),
              ProgressTrack(ratio: snapshot.ratio, color: color, height: 9),
            ],
            if (goal.mechanism == Mechanism.milestone &&
                snapshot.childTotal > 0) ...[
              const SizedBox(height: 8),
              Text(
                '已完成 ${snapshot.childDone}/${snapshot.childTotal} 个子项'
                '${snapshot.readyToComplete ? ' · 可以完成里程碑' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: snapshot.readyToComplete
                      ? color
                      : scheme.onSurfaceVariant,
                  fontWeight: snapshot.readyToComplete
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
            if (goal.mechanism == Mechanism.metric) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.filter_alt_outlined, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    '连续达标 ${snapshot.stableCount}/${snapshot.stableWindow} 次 · 共 ${snapshot.readingCount} 次读数',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _MetaRow(icon: Icons.schedule, text: pacing.timeText ?? ''),
            if (pacing.remainingText != null)
              _MetaRow(
                icon: Icons.hourglass_bottom,
                text: pacing.remainingText!,
              ),
            if (pacing.plannedText != null)
              _MetaRow(
                icon: Icons.stacked_line_chart,
                text: pacing.plannedText!,
              ),
            if (gap.isNotEmpty)
              _MetaRow(
                icon: pacing.isBehind
                    ? Icons.trending_down
                    : pacing.isAhead
                    ? Icons.trending_up
                    : Icons.trending_flat,
                text: gap,
                color: pacing.isBehind
                    ? const Color(0xFFB2501E)
                    : pacing.isAhead
                    ? const Color(0xFF2E7D5B)
                    : null,
              ),
            if (pacing.paceText != null)
              _MetaRow(icon: Icons.speed, text: pacing.paceText!),
            if (pacing.note != null) ...[
              const SizedBox(height: 8),
              Text(
                pacing.note!,
                style: TextStyle(
                  fontSize: 10.5,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (goal.lifecycle == Lifecycle.pending ||
                    goal.lifecycle == Lifecycle.paused)
                  FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('启动'),
                  ),
                if (goal.lifecycle == Lifecycle.completed)
                  OutlinedButton.icon(
                    onPressed: onReopen,
                    icon: const Icon(Icons.replay, size: 17),
                    label: const Text('重新打开'),
                  )
                else if (goal.lifecycle != Lifecycle.terminated) ...[
                  if (goal.mechanism == Mechanism.milestone)
                    FilledButton.icon(
                      onPressed: snapshot.readyToComplete ? onComplete : null,
                      icon: const Icon(Icons.check, size: 17),
                      label: const Text('标记完成'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: onUpdate,
                      icon: Icon(
                        goal.mechanism == Mechanism.cumulative
                            ? Icons.add
                            : goal.mechanism == Mechanism.metric
                            ? Icons.monitor_heart_outlined
                            : Icons.check,
                        size: 17,
                      ),
                      label: Text(
                        goal.mechanism == Mechanism.cumulative
                            ? '记录增量'
                            : goal.mechanism == Mechanism.metric
                            ? '记录读数'
                            : goal.mechanism == Mechanism.subjective
                            ? '更新自评'
                            : '标记完成',
                      ),
                    ),
                  if (goal.mechanism == Mechanism.milestone &&
                      !snapshot.readyToComplete)
                    FilledButton.tonalIcon(
                      onPressed: onNote,
                      icon: const Icon(Icons.edit_note, size: 17),
                      label: const Text('写说明'),
                    ),
                ],
                if (goal.lifecycle != Lifecycle.terminated &&
                    goal.mechanism != Mechanism.milestone)
                  TextButton.icon(
                    onPressed: onNote,
                    icon: const Icon(Icons.edit_note, size: 16),
                    label: const Text('写说明'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color ?? scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color ?? scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.goal,
    required this.parent,
    this.onOpenParent,
  });

  final Goal goal;
  final Goal? parent;
  final VoidCallback? onOpenParent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '目标定义',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            InfoLine(
              label: '达成条件',
              value: goal.successCriteria.isEmpty
                  ? '未填写'
                  : goal.successCriteria,
            ),
            InfoLine(
              label: '起止日期',
              value:
                  '${formatDate(goal.startDate)} → ${formatDate(goal.dueDate)}',
            ),
            if (goal.domain.isNotEmpty)
              InfoLine(label: '领域', value: goal.domain),
            if (goal.tags.isNotEmpty)
              InfoLine(label: '标签', value: goal.tags.join('、')),
            if (parent != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: InkWell(
                  onTap: onOpenParent,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          '父目标',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          parent!.title,
                          style: TextStyle(fontSize: 13, color: scheme.primary),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            if (parent != null)
              InfoLine(
                label: '权重 / 必需',
                value:
                    '${formatNumber(goal.weight)} / ${goal.isRequired ? '是' : '否'}',
              ),
            InfoLine(label: '机制', value: goal.mechanism.description),
            if (goal.isMilestone)
              InfoLine(label: '子项模式', value: goal.executionMode.label),
            if (goal.completedAt != null)
              InfoLine(label: '完成时间', value: formatDateTime(goal.completedAt!)),
          ],
        ),
      ),
    );
  }
}

class _CommitmentSection extends StatelessWidget {
  const _CommitmentSection({required this.goal, required this.commitments});

  final Goal goal;
  final List<Commitment> commitments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '周期承诺',
          subtitle: '承诺未兑现不会改变目标状态，也不会标记失败',
          trailing: TextButton.icon(
            onPressed: () async {
              final result = await showCommitmentSheet(context, goal);
              if (result == true && context.mounted) {
                showAppSnack(context, '承诺已创建');
              }
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('新建'),
          ),
        ),
        if (commitments.isEmpty)
          const EmptyState(
            icon: Icons.flag_outlined,
            title: '还没有周期承诺',
            message: '给本周定一个具体的量，让推进更聚焦。',
            compact: true,
          )
        else
          ...commitments.map(
            (commitment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CommitmentCard(
                commitment: commitment,
                goal: goal,
                trailing: PopupMenuButton<String>(
                  tooltip: '承诺操作',
                  icon: const Icon(Icons.more_horiz, size: 18),
                  onSelected: (value) =>
                      _handleCommitment(context, commitment, value),
                  itemBuilder: (context) => [
                    if (commitment.plannedAmount != null &&
                        commitment.status != CommitmentStatus.cancelled)
                      const PopupMenuItem(value: 'adjust', child: Text('调整承诺')),
                    if (commitment.status != CommitmentStatus.cancelled)
                      const PopupMenuItem(value: 'cancel', child: Text('取消承诺')),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _handleCommitment(
    BuildContext context,
    Commitment commitment,
    String action,
  ) async {
    final repo = RepositoryScope.read(context);
    if (action == 'adjust') {
      final result = await showAdjustCommitmentSheet(context, commitment, goal);
      if (result == true && context.mounted) {
        showAppSnack(context, '承诺已调整，历史已保留');
      }
      return;
    }
    if (action == 'cancel') {
      final confirmed = await confirmAction(
        context,
        title: '取消承诺？',
        message: '取消会保留历史，不会影响目标状态。',
        confirmLabel: '取消承诺',
        destructive: true,
      );
      if (confirmed) {
        repo.cancelCommitment(commitment.id);
        if (context.mounted) showAppSnack(context, '承诺已取消');
      }
    }
  }
}

class _ChildrenSection extends StatelessWidget {
  const _ChildrenSection({required this.goal, required this.children});

  final Goal goal;
  final List<Goal> children;

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    final focus = focusedChild(goal, repo.goals);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '子目标',
          subtitle: '${goal.executionMode.label} · 父级进度由子项加权上卷，不可直接修改',
          trailing: TextButton.icon(
            onPressed: () async {
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => GoalEditorPage(parent: goal)),
              );
              if (result != null && context.mounted) {
                showAppSnack(context, '子项已添加');
              }
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('添加'),
          ),
        ),
        if (children.isEmpty)
          const EmptyState(
            icon: Icons.account_tree_outlined,
            title: '还没有子项',
            message: '子项可以是任意机制，也可以继续嵌套。',
            compact: true,
          )
        else
          ...children.asMap().entries.map((entry) {
            final index = entry.key;
            final child = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChildRow(
                parent: goal,
                child: child,
                index: index,
                total: children.length,
                isFocus: focus?.id == child.id,
              ),
            );
          }),
      ],
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({
    required this.parent,
    required this.child,
    required this.index,
    required this.total,
    required this.isFocus,
  });

  final Goal parent;
  final Goal child;
  final int index;
  final int total;
  final bool isFocus;

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final snapshot = computeSnapshot(
      child,
      repo.goals,
      repo.records,
      metricMinObservations: repo.settings.metricMinObservations,
    );
    final locked = isChildLocked(child, repo.goals);
    final color = mechanismColor(child.mechanism);
    final sequential = parent.executionMode == ExecutionMode.sequential;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isFocus
              ? scheme.primary.withValues(alpha: 0.55)
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GoalDetailPage(goalId: child.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChildMarker(
                sequential: sequential,
                index: index,
                child: child,
                locked: locked,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            child.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: child.lifecycle == Lifecycle.terminated
                                  ? scheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                        ),
                        Text(
                          snapshot.ratio == null
                              ? ''
                              : formatPercent(snapshot.ratio!),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          locked ? '待解锁' : child.lifecycle.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: locked
                                ? scheme.onSurfaceVariant
                                : lifecycleColor(child.lifecycle),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          child.mechanism.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (isFocus) ...[
                          const SizedBox(width: 6),
                          Text(
                            '当前聚焦',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (snapshot.ratio != null) ...[
                      const SizedBox(height: 6),
                      ProgressTrack(
                        ratio: snapshot.ratio,
                        color: locked ? scheme.outline : color,
                        height: 5,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '子项操作',
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (action) =>
                    _handleChildAction(context, action, locked),
                itemBuilder: (context) => [
                  if (locked)
                    const PopupMenuItem(value: 'start', child: Text('提前开始')),
                  if (child.mechanism == Mechanism.completion &&
                      child.lifecycle != Lifecycle.completed)
                    const PopupMenuItem(value: 'complete', child: Text('标记完成')),
                  if (sequential && index > 0)
                    const PopupMenuItem(value: 'up', child: Text('上移')),
                  if (sequential && index < total - 1)
                    const PopupMenuItem(value: 'down', child: Text('下移')),
                  const PopupMenuItem(value: 'edit', child: Text('编辑')),
                  const PopupMenuItem(value: 'detach', child: Text('从父级移除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleChildAction(
    BuildContext context,
    String action,
    bool locked,
  ) async {
    final repo = RepositoryScope.read(context);
    String? error;
    switch (action) {
      case 'start':
        error = repo.changeLifecycle(child.id, Lifecycle.active, note: '提前开始');
        break;
      case 'complete':
        error = repo.markComplete(child.id);
        break;
      case 'up':
        repo.moveChild(child.id, -1);
        return;
      case 'down':
        repo.moveChild(child.id, 1);
        return;
      case 'edit':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GoalEditorPage(goal: child, parent: parent),
          ),
        );
        return;
      case 'detach':
        if (await confirmAction(
          context,
          title: '从父级移除？',
          message: '移除后子项会变成独立目标，历史记录保留。',
          confirmLabel: '移除',
        )) {
          repo.detachChild(child.id);
        }
        return;
    }
    if (context.mounted) {
      if (error != null) {
        showAppSnack(context, error, error: true);
      } else {
        showAppSnack(context, '已更新');
      }
    }
  }
}

class _ChildMarker extends StatelessWidget {
  const _ChildMarker({
    required this.sequential,
    required this.index,
    required this.child,
    required this.locked,
    required this.color,
  });

  final bool sequential;
  final int index;
  final Goal child;
  final bool locked;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!sequential) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(
          child.mechanism == Mechanism.completion
              ? child.lifecycle == Lifecycle.completed
                    ? Icons.check_box
                    : Icons.check_box_outline_blank
              : Icons.circle_outlined,
          size: 18,
          color: child.lifecycle == Lifecycle.completed
              ? color
              : scheme.outline,
        ),
      );
    }
    final completed = child.lifecycle == Lifecycle.completed;
    final active = child.lifecycle == Lifecycle.active;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed
            ? color
            : active
            ? color.withValues(alpha: 0.14)
            : Colors.transparent,
        border: Border.all(
          color: completed || active ? color : scheme.outlineVariant,
        ),
      ),
      child: Center(
        child: completed
            ? const Icon(Icons.check, size: 13, color: Colors.white)
            : locked
            ? Icon(Icons.lock_outline, size: 11, color: scheme.outline)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: active ? color : scheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.goal, required this.records});

  final Goal goal;
  final List<UpdateRecord> records;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '时间线',
          subtitle: '原始读数、增量与配置变更全部保留',
          trailing: TextButton.icon(
            onPressed: () => showNoteSheet(context, goal.id),
            icon: const Icon(Icons.edit_note, size: 16),
            label: const Text('写说明'),
          ),
        ),
        if (records.isEmpty)
          const EmptyState(
            icon: Icons.history,
            title: '还没有记录',
            message: '每次更新的原始量和说明都会出现在这里。',
            compact: true,
          )
        else
          Card(
            child: Column(
              children: records.asMap().entries.map((entry) {
                final record = entry.value;
                return Column(
                  children: [
                    _RecordTile(record: record, goal: goal),
                    if (entry.key != records.length - 1)
                      const Divider(height: 1, indent: 48, endIndent: 14),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.goal});

  final UpdateRecord record;
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (record.type) {
      RecordType.progress => (
        Icons.trending_up,
        mechanismColor(goal.mechanism),
      ),
      RecordType.configChange => (Icons.tune, const Color(0xFF60707C)),
      RecordType.reopen => (Icons.replay, const Color(0xFF2F6DB5)),
      RecordType.lifecycleChange => (
        Icons.flag_outlined,
        const Color(0xFF2E7D5B),
      ),
    };
    final body = recordBody(record);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        recordTitle(record, goal),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      formatRelative(DateTime.now(), record.timestamp),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
