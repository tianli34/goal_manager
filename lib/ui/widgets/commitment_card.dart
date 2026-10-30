import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../core/enums.dart';
import '../../logic/commitment_logic.dart';
import '../../models/commitment.dart';
import '../../models/goal.dart';
import '../scope.dart';
import 'common.dart';

class CommitmentCard extends StatelessWidget {
  const CommitmentCard({
    super.key,
    required this.commitment,
    required this.goal,
    this.showGoalTitle = false,
    this.onTap,
    this.trailing,
  });

  final Commitment commitment;
  final Goal? goal;
  final bool showGoalTitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    final progress = computeCommitmentProgress(
      commitment,
      repo.data,
      DateTime.now(),
    );
    final scheme = Theme.of(context).colorScheme;
    final color = _statusColor(progress, commitment, scheme);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      showGoalTitle && goal != null
                          ? goal!.title
                          : dayRangeText(commitment.start, commitment.end),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      progress.statusLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              if (showGoalTitle) ...[
                const SizedBox(height: 2),
                Text(
                  dayRangeText(commitment.start, commitment.end),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                progress.summary,
                style: const TextStyle(fontSize: 12.5, height: 1.35),
              ),
              if (progress.ratio != null) ...[
                const SizedBox(height: 8),
                ProgressTrack(ratio: progress.ratio, color: color, height: 6),
              ],
              if (commitment.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  commitment.note,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (progress.detail != null) ...[
                const SizedBox(height: 4),
                Text(
                  progress.detail!,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(
    CommitmentProgress progress,
    Commitment commitment,
    ColorScheme scheme,
  ) {
    if (commitment.status == CommitmentStatus.cancelled) {
      return scheme.outline;
    }
    if (progress.fulfilled) return const Color(0xFF2E7D5B);
    if (progress.expired) return const Color(0xFFB26A1E);
    if (commitment.status == CommitmentStatus.adjusted) {
      return const Color(0xFF2F6DB5);
    }
    return scheme.primary;
  }
}
