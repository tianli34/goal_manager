import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../core/enums.dart';
import '../../logic/signals.dart';
import '../../models/goal.dart';
import '../goals/goal_detail_page.dart';
import '../goals/goal_editor_page.dart';
import '../goals/update_sheet.dart';
import '../inbox/inbox_page.dart';
import '../scope.dart';
import '../widgets/commitment_card.dart';
import '../widgets/commitment_sheet.dart';
import '../widgets/common.dart';
import '../widgets/goal_card.dart';
import '../widgets/pickers.dart';

class NowPage extends StatelessWidget {
  const NowPage({super.key, required this.onOpenGoals});

  final VoidCallback onOpenGoals;

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    final now = DateTime.now();
    final week = weekStart(now);
    final weekLast = weekEnd(now);
    final commitments = repo.commitmentsBetween(week, weekLast);
    final signals = computeSignals(repo.data, now);
    final activeGoals =
        repo
            .topLevelGoals()
            .where((g) => g.lifecycle == Lifecycle.active)
            .toList()
          ..sort(_compareGoals);
    final focusGoals = activeGoals.take(5).toList();

    if (!repo.hasData) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _NowHeader(now: now, commitments: 0, signals: 0, active: 0),
          const SizedBox(height: 30),
          EmptyState(
            icon: Icons.flag_outlined,
            title: '从第一个目标开始',
            message: '先选一个真正想推进的目标，再决定用哪种机制记录。',
            action: Column(
              children: [
                FilledButton.icon(
                  onPressed: () => _createGoal(context),
                  icon: const Icon(Icons.add),
                  label: const Text('创建目标'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    repo.loadSample();
                    showAppSnack(context, '已载入示例数据');
                  },
                  child: const Text('先看看示例数据'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InboxCard(count: repo.inbox.length),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _NowHeader(
          now: now,
          commitments: commitments.length,
          signals: signals.length,
          active: activeGoals.length,
        ),
        if (repo.loadError != null || repo.saveError != null) ...[
          const SizedBox(height: 10),
          _ErrorBanner(text: repo.loadError ?? repo.saveError!),
        ],
        SectionHeader(
          title: '本期承诺',
          subtitle: '${dayRangeText(week, weekLast)} · 未兑现也不等于失败',
          trailing: TextButton.icon(
            onPressed: () => _newCommitment(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('新建'),
          ),
        ),
        if (commitments.isEmpty)
          EmptyState(
            icon: Icons.flag_outlined,
            title: '本周还没有承诺',
            message: '只挑一两个真正想推进的目标，定一个具体的量。',
            compact: true,
            action: OutlinedButton(
              onPressed: () => _newCommitment(context),
              child: const Text('新建承诺'),
            ),
          )
        else
          ...commitments.map(
            (commitment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CommitmentCard(
                commitment: commitment,
                goal: repo.goalById(commitment.goalId),
                showGoalTitle: true,
                onTap: () => _openGoal(context, commitment.goalId),
              ),
            ),
          ),
        SectionHeader(
          title: '重点目标',
          subtitle: '只看少数正在推进的目标',
          trailing: TextButton(onPressed: onOpenGoals, child: const Text('全部')),
        ),
        if (focusGoals.isEmpty)
          const EmptyState(
            icon: Icons.play_circle_outline,
            title: '没有进行中的目标',
            message: '可以在目标页开始一个待开始的目标。',
            compact: true,
          )
        else
          ...focusGoals.map(
            (goal) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GoalCard(
                goal: goal,
                onTap: () => _openGoal(context, goal.id),
              ),
            ),
          ),
        SectionHeader(title: '需要关注', subtitle: '每条提醒都来自真实记录，并附带一个可执行动作'),
        if (signals.isEmpty)
          const EmptyState(
            icon: Icons.check_circle_outline,
            title: '暂时没有需要关注的信号',
            message: '继续按自己的节奏记录即可。',
            compact: true,
          )
        else
          ...signals.take(5).map((signal) {
            final goal = repo.goalById(signal.goalId);
            if (goal == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SignalTile(
                signal: signal,
                goal: goal,
                onPrimary: () => _handleSignal(context, signal, goal),
                onSecondary: () => _handleSecondary(context, signal, goal),
              ),
            );
          }),
        const SizedBox(height: 16),
        _InboxCard(count: repo.inbox.length),
      ],
    );
  }

  static int _compareGoals(Goal a, Goal b) {
    final aDue = a.dueDate;
    final bDue = b.dueDate;
    if (aDue == null && bDue == null) {
      return b.updatedAt.compareTo(a.updatedAt);
    }
    if (aDue == null) return 1;
    if (bDue == null) return -1;
    return aDue.compareTo(bDue);
  }

  void _openGoal(BuildContext context, String goalId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GoalDetailPage(goalId: goalId)),
    );
  }

  Future<void> _createGoal(BuildContext context) async {
    await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const GoalEditorPage()),
    );
  }

  Future<void> _newCommitment(BuildContext context) async {
    final repo = RepositoryScope.read(context);
    final goals = repo.goals
        .where(
          (g) =>
              !g.isArchived &&
              g.lifecycle != Lifecycle.terminated &&
              g.lifecycle != Lifecycle.completed,
        )
        .toList();
    if (goals.isEmpty) {
      showAppSnack(context, '先创建一个目标，再定承诺');
      return;
    }
    final goal = await showGoalPicker(context, goals, title: '为哪个目标定承诺？');
    if (goal == null || !context.mounted) return;
    final result = await showCommitmentSheet(context, goal);
    if (result == true && context.mounted) {
      showAppSnack(context, '承诺已创建');
    }
  }

  Future<void> _handleSignal(
    BuildContext context,
    GoalSignal signal,
    Goal goal,
  ) async {
    switch (signal.type) {
      case AttentionSignal.dateRisk:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GoalEditorPage(goal: goal)),
        );
        break;
      case AttentionSignal.possibleStall:
        await showNoteSheet(
          context,
          goal.id,
          title: '发生了什么？',
          hint: '记录预期变化没有发生的原因，或下一步怎么调整',
        );
        break;
      case AttentionSignal.noRecentUpdate:
      case AttentionSignal.insufficientData:
        await showUpdateSheet(context, goal.id);
        break;
    }
  }

  Future<void> _handleSecondary(
    BuildContext context,
    GoalSignal signal,
    Goal goal,
  ) async {
    switch (signal.type) {
      case AttentionSignal.noRecentUpdate:
        final repo = RepositoryScope.read(context);
        final error = repo.recordNote(goal.id, '确认无变化');
        if (context.mounted) {
          if (error != null) {
            showAppSnack(context, error, error: true);
          } else {
            showAppSnack(context, '已记录：确认无变化');
          }
        }
        break;
      case AttentionSignal.dateRisk:
        await showUpdateSheet(context, goal.id);
        break;
      case AttentionSignal.possibleStall:
      case AttentionSignal.insufficientData:
        _openGoal(context, goal.id);
        break;
    }
  }
}

class _NowHeader extends StatelessWidget {
  const _NowHeader({
    required this.now,
    required this.commitments,
    required this.signals,
    required this.active,
  });

  final DateTime now;
  final int commitments;
  final int signals;
  final int active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${formatMonthDay(now)} · ${weekdayName(now)}',
          style: TextStyle(
            fontSize: 12.5,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '把注意力放在少数重要的事上',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatPill(label: '本周承诺', value: '$commitments'),
            StatPill(
              label: '需要关注',
              value: '$signals',
              color: signals > 0 ? const Color(0xFFB26A1E) : null,
            ),
            StatPill(
              label: '进行中',
              value: '$active',
              color: const Color(0xFF2E7D5B),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({
    required this.signal,
    required this.goal,
    required this.onPrimary,
    required this.onSecondary,
  });

  final GoalSignal signal;
  final Goal goal;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (signal.type) {
      AttentionSignal.dateRisk => const Color(0xFFB2501E),
      AttentionSignal.possibleStall => const Color(0xFFB26A1E),
      AttentionSignal.noRecentUpdate => const Color(0xFF2F6DB5),
      AttentionSignal.insufficientData => const Color(0xFF60707C),
    };
    final icon = switch (signal.type) {
      AttentionSignal.dateRisk => Icons.event_busy,
      AttentionSignal.possibleStall => Icons.pause_circle_outline,
      AttentionSignal.noRecentUpdate => Icons.notifications_none,
      AttentionSignal.insufficientData => Icons.help_outline,
    };
    final primaryLabel = switch (signal.type) {
      AttentionSignal.dateRisk => '调整日期',
      AttentionSignal.possibleStall => '写说明',
      AttentionSignal.noRecentUpdate => '更新',
      AttentionSignal.insufficientData => '记录读数',
    };
    final secondaryLabel = switch (signal.type) {
      AttentionSignal.dateRisk => '更新',
      AttentionSignal.possibleStall => '查看目标',
      AttentionSignal.noRecentUpdate => '确认无变化',
      AttentionSignal.insufficientData => '查看目标',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              goal.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            signal.type.label,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        signal.message,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onSecondary, child: Text(secondaryLabel)),
                const SizedBox(width: 4),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onPrimary,
                  child: Text(primaryLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.inbox_outlined, size: 18, color: scheme.primary),
        ),
        title: const Text(
          '收集箱',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          count == 0 ? '把还没想清楚的想法先放进来' : '$count 条待处理',
          style: const TextStyle(fontSize: 11.5),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InboxPage()),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: scheme.error),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
