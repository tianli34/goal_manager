import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../core/enums.dart';
import '../../logic/commitment_logic.dart';
import '../../models/goal.dart';
import '../../models/review.dart';
import '../goals/goal_detail_page.dart';
import '../scope.dart';
import '../widgets/common.dart';
import 'review_editor_page.dart';

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    final now = DateTime.now();
    final week = weekStart(now);
    final weekNext = weekEnd(now);
    final records = repo.records
        .where(
          (r) =>
              r.type == RecordType.progress &&
              !r.timestamp.isBefore(week) &&
              r.timestamp.isBefore(weekNext),
        )
        .toList();
    final completed = repo.goals
        .where(
          (g) =>
              g.lifecycle == Lifecycle.completed &&
              g.completedAt != null &&
              !g.completedAt!.isBefore(week) &&
              g.completedAt!.isBefore(weekNext),
        )
        .toList();
    final commitments = repo.commitmentsBetween(week, weekNext);
    final fulfilled = commitments
        .where((c) => computeCommitmentProgress(c, repo.data, now).fulfilled)
        .toList();
    final currentReviews =
        repo.reviews.where((r) => dateOnly(r.start) == week).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final history =
        repo.reviews.where((r) => dateOnly(r.start) != week).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final achievements =
        repo.goals.where((g) => g.lifecycle == Lifecycle.completed).toList()
          ..sort(
            (a, b) => (b.completedAt ?? b.updatedAt).compareTo(
              a.completedAt ?? a.updatedAt,
            ),
          );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          '${dayRangeText(week, weekNext)} · ${weekdayName(now)}',
          style: TextStyle(
            fontSize: 12.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '记录事实 → 看信号 → 复盘 → 做决定',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本周期变化',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatPill(label: '推进记录', value: '${records.length}'),
                    StatPill(
                      label: '完成目标',
                      value: '${completed.length}',
                      color: const Color(0xFF2E7D5B),
                    ),
                    StatPill(
                      label: '兑现承诺',
                      value: '${fulfilled.length}',
                      color: const Color(0xFF2F6DB5),
                    ),
                    StatPill(
                      label: '复盘',
                      value: '${currentReviews.length}',
                      color: const Color(0xFF7A4FA3),
                    ),
                  ],
                ),
                if (completed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _CompactList(
                    title: '本周完成',
                    items: completed.map((g) => g.title).toList(),
                  ),
                ],
                if (fulfilled.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _CompactList(
                    title: '本周兑现',
                    items: fulfilled
                        .map((c) => repo.goalById(c.goalId)?.title ?? '已删除的目标')
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        SectionHeader(
          title: '本周期复盘',
          subtitle: '三个问题：发生了什么、是否仍值得、下一步决定',
          trailing: TextButton.icon(
            onPressed: () => _newReview(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('新建'),
          ),
        ),
        if (currentReviews.isEmpty)
          EmptyState(
            icon: Icons.rate_review_outlined,
            title: '本周还没有复盘',
            message: '不用等到周末，现在就可以记录事实并做一个小决定。',
            compact: true,
            action: OutlinedButton(
              onPressed: () => _newReview(context),
              child: const Text('开始复盘'),
            ),
          )
        else
          ...currentReviews.map(
            (review) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ReviewCard(
                review: review,
                goals: repo.goals,
                initiallyExpanded: true,
              ),
            ),
          ),
        if (history.isNotEmpty) ...[
          const SectionHeader(title: '历史复盘', subtitle: '决定和调整都会留下痕迹'),
          ...history.map(
            (review) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ReviewCard(
                review: review,
                goals: repo.goals,
                initiallyExpanded: false,
              ),
            ),
          ),
        ],
        SectionHeader(
          title: '达成记录',
          subtitle: achievements.isEmpty
              ? '完成的目标会出现在这里'
              : '共 ${achievements.length} 个已完成目标',
        ),
        if (achievements.isEmpty)
          const EmptyState(
            icon: Icons.emoji_events_outlined,
            title: '还没有完成的目标',
            message: '完成不是唯一价值，但值得被看见。',
            compact: true,
          )
        else
          Card(
            child: Column(
              children: achievements.asMap().entries.map((entry) {
                final goal = entry.value;
                return Column(
                  children: [
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.check_circle,
                        size: 20,
                        color: Color(0xFF2E7D5B),
                      ),
                      title: Text(
                        goal.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        '${formatDate(goal.completedAt)} · ${goal.mechanism.label}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GoalDetailPage(goalId: goal.id),
                        ),
                      ),
                    ),
                    if (entry.key != achievements.length - 1)
                      const Divider(height: 1, indent: 52, endIndent: 16),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Future<void> _newReview(BuildContext context) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ReviewEditorPage()),
    );
    if (created == true && context.mounted) {
      showAppSnack(context, '复盘已保存');
    }
  }
}

class _CompactList extends StatelessWidget {
  const _CompactList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            title,
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            items.join('、'),
            style: const TextStyle(fontSize: 11.5, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.goals,
    required this.initiallyExpanded,
  });

  final Review review;
  final List<Goal> goals;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (review.decision) {
      ReviewDecision.continuePlan => const Color(0xFF2E7D5B),
      ReviewDecision.adjust => const Color(0xFF2F6DB5),
      ReviewDecision.pause => const Color(0xFFB26A1E),
      ReviewDecision.end => scheme.outline,
    };
    final linked = goals.where((g) => review.goalIds.contains(g.id)).toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Row(
          children: [
            Expanded(
              child: Text(
                dayRangeText(review.start, review.end),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                review.decision.label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '记录于 ${formatDateTime(review.createdAt)}',
          style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          _Answer(label: '1 发生了什么', text: review.whatHappened),
          _Answer(
            label: '2 原计划仍值得吗',
            text:
                '${review.stillWorthPlan ? '是' : '否'}${review.planReflection.isEmpty ? '' : ' · ${review.planReflection}'}',
          ),
          _Answer(
            label: '3 下一步决定',
            text:
                '${review.decision.label}${review.nextStep.isEmpty ? '' : ' · ${review.nextStep}'}',
          ),
          if (linked.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: linked.map((g) => TagPill(g.title)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text.isEmpty ? '未填写' : text,
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}
