import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../goals/goal_detail_page.dart';
import '../goals/goal_editor_page.dart';
import '../goals/update_sheet.dart';
import '../scope.dart';
import '../widgets/common.dart';
import '../widgets/goal_card.dart';
import '../widgets/pickers.dart';

enum _GoalFilter { active, inactive, finished }

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => GoalsPageState();
}

class GoalsPageState extends State<GoalsPage> {
  _GoalFilter _filter = _GoalFilter.active;
  bool _includeArchived = false;

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    var goals = repo.leafGoals(includeArchived: _includeArchived);
    goals = goals.where((goal) {
      return switch (_filter) {
        _GoalFilter.active => goal.lifecycle == Lifecycle.active,
        _GoalFilter.inactive =>
          goal.lifecycle == Lifecycle.pending ||
              goal.lifecycle == Lifecycle.paused,
        _GoalFilter.finished => goal.lifecycle.isFinished,
      };
    }).toList();
    goals.sort((a, b) {
      if (_filter == _GoalFilter.finished) {
        final aTime = a.completedAt ?? a.updatedAt;
        final bTime = b.completedAt ?? b.updatedAt;
        return bTime.compareTo(aTime);
      }
      final aDue = a.dueDate;
      final bDue = b.dueDate;
      if (aDue == null && bDue == null) {
        return b.updatedAt.compareTo(a.updatedAt);
      }
      if (aDue == null) return 1;
      if (bDue == null) return -1;
      return aDue.compareTo(bDue);
    });

    if (!repo.hasData) {
      return _withBottomActions(
        context,
        showCreate: !repo.settings.newGoalInAppBar,
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 110),
          children: [
            EmptyState(
              icon: Icons.flag_outlined,
              title: '还没有目标',
              message: '目标可以简单到“读完一本书”，也可以是一个里程碑项目。',
              action: Column(
                children: [
                  FilledButton.icon(
                    onPressed: createGoal,
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
          ],
        ),
      );
    }

    return _withBottomActions(
      context,
      showCreate: !repo.settings.newGoalInAppBar,
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${goals.length} 个目标',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '列表只显示最底层的可执行目标，进入目标后可回到父级。',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_GoalFilter>(
              segments: const [
                ButtonSegment(value: _GoalFilter.active, label: Text('进行中')),
                ButtonSegment(value: _GoalFilter.inactive, label: Text('未激活')),
                ButtonSegment(value: _GoalFilter.finished, label: Text('已结束')),
              ],
              selected: {_filter},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _filter = value.first),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: _includeArchived ? '隐藏归档' : '包含归档',
                onPressed: () =>
                    setState(() => _includeArchived = !_includeArchived),
                icon: Icon(
                  _includeArchived
                      ? Icons.inventory_2
                      : Icons.inventory_2_outlined,
                  size: 20,
                  color: _includeArchived
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (goals.isEmpty)
            EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: '这个筛选下没有目标',
              message: '可以调整生命周期筛选。',
              action: OutlinedButton(
                onPressed: () => setState(() {
                  _includeArchived = false;
                }),
                child: const Text('清除筛选'),
              ),
            )
          else
            ...goals.map(
              (goal) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GoalCard(
                  goal: goal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GoalDetailPage(goalId: goal.id),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _withBottomActions(
    BuildContext context,
    Widget content, {
    required bool showCreate,
  }) {
    return Stack(
      children: [
        content,
        Positioned(
          right: 16,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: _GoalActions(
              showCreate: showCreate,
              onCreate: createGoal,
              onUpdate: () => _updateGoal(context),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _updateGoal(BuildContext context) async {
    final repo = RepositoryScope.read(context);
    final goals = repo
        .leafGoals()
        .where(
          (goal) =>
              goal.lifecycle != Lifecycle.completed &&
              goal.lifecycle != Lifecycle.terminated,
        )
        .toList();
    if (goals.isEmpty) {
      showAppSnack(context, '还没有可以更新的目标');
      return;
    }
    final goal = await showGoalPicker(context, goals, title: '更新哪个目标？');
    if (goal == null || !context.mounted) return;
    await showUpdateSheet(context, goal.id);
  }

  Future<void> createGoal() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const GoalEditorPage()),
    );
    if (id != null && mounted) {
      setState(() => _filter = _GoalFilter.inactive);
    }
  }
}

class _GoalActions extends StatelessWidget {
  const _GoalActions({
    required this.showCreate,
    required this.onCreate,
    required this.onUpdate,
  });

  final bool showCreate;
  final VoidCallback onCreate;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCreate) ...[
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新建'),
          ),
          const SizedBox(width: 8),
        ],
        FilledButton.tonalIcon(
          onPressed: onUpdate,
          icon: const Icon(Icons.update, size: 18),
          label: const Text('更新'),
        ),
      ],
    );
  }
}
