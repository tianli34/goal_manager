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
  const GoalCard({
    super.key,
    required this.goal,
    required this.onTap,
    this.showFocus = true,
  });

  final Goal goal;
  final VoidCallback onTap;
  final bool showFocus;

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
    final focus = showFocus ? focusedChild(goal, repo.goals) : null;
    final scheme = Theme.of(context).colorScheme;
    final color = mechanismColor(goal.mechanism);

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
                  if (goal.domain.isNotEmpty) TagPill(goal.domain),
                  ...goal.tags.take(2).map((tag) => TagPill('#$tag')),
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
              ],
              if (focus != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      size: 13,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '当前：${focus.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
