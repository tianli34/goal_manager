import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../core/enums.dart';
import '../../core/numbers.dart';
import '../../logic/progress.dart';
import '../../models/goal.dart';
import '../scope.dart';
import '../theme.dart';
import 'common.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, required this.onTap});

  final Goal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    final snapshot = computeSnapshot(
      goal,
      repo.goals,
      repo.records,
      metricMinObservations: repo.settings.metricMinObservations,
    );
    final pacing = computePacing(goal, snapshot, repo.goals, DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    final color = mechanismColor(goal.mechanism);
    final canStart =
        !goal.isArchived &&
        (goal.lifecycle == Lifecycle.pending ||
            goal.lifecycle == Lifecycle.paused);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  if (goal.isArchived) ...[
                    const SizedBox(width: 6),
                    TagPill('已归档'),
                  ],
                  if (snapshot.ratio != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      formatPercent(snapshot.ratio!),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  MechanismChip(goal.mechanism, compact: true),
                  if (goal.lifecycle != Lifecycle.active)
                    LifecycleChip(goal.lifecycle),
                ],
              ),
              if (snapshot.ratio != null) ...[
                const SizedBox(height: 12),
                ProgressTrack(ratio: snapshot.ratio, color: color, height: 7),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        snapshot.rawValueText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (goal.dueDate != null)
                      Text(
                        pacing.remainingText ?? '',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
              if (snapshot.ratio == null && goal.dueDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  remainingText(goal.dueDate, DateTime.now()),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ] else if (snapshot.ratio == null &&
                  goal.dueDate == null &&
                  goal.durationLabel != null) ...[
                const SizedBox(height: 8),
                Text(
                  '期限 ${goal.durationLabel} · 待开始日期',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (canStart) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _start(context),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('启动'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _start(BuildContext context) {
    final repo = RepositoryScope.read(context);
    final error = repo.changeLifecycle(goal.id, Lifecycle.active);
    if (error != null) {
      showAppSnack(context, error, error: true);
    } else {
      showAppSnack(context, '已启动目标');
    }
  }
}
