import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../goals/goal_detail_page.dart';
import '../goals/goal_editor_page.dart';
import '../scope.dart';
import '../widgets/common.dart';
import '../widgets/goal_card.dart';

enum _GoalFilter { active, inactive, finished }

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  _GoalFilter _filter = _GoalFilter.active;
  String? _domain;
  String? _tag;
  bool _includeArchived = false;

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final allGoals = repo.goals;
    final domains =
        allGoals
            .map((g) => g.domain)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final tags = allGoals.expand((g) => g.tags).toSet().toList()..sort();
    final selectedDomain = _domain != null && domains.contains(_domain)
        ? _domain
        : null;
    final selectedTag = _tag != null && tags.contains(_tag) ? _tag : null;

    var goals = repo.topLevelGoals(includeArchived: _includeArchived);
    goals = goals.where((goal) {
      final matchesFilter = switch (_filter) {
        _GoalFilter.active => goal.lifecycle == Lifecycle.active,
        _GoalFilter.inactive =>
          goal.lifecycle == Lifecycle.pending ||
              goal.lifecycle == Lifecycle.paused,
        _GoalFilter.finished => goal.lifecycle.isFinished,
      };
      final matchesDomain =
          selectedDomain == null || goal.domain == selectedDomain;
      final matchesTag = selectedTag == null || goal.tags.contains(selectedTag);
      return matchesFilter && matchesDomain && matchesTag;
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
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          EmptyState(
            icon: Icons.flag_outlined,
            title: '还没有目标',
            message: '目标可以简单到“读完一本书”，也可以是一个里程碑项目。',
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
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
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
                    '机制、生命周期和领域彼此独立，不做层级化的人生目标树。',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _createGoal(context),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('新建'),
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
          children: [
            Expanded(
              child: _CompactDropdown(
                label: '领域',
                value: selectedDomain ?? '',
                allLabel: '全部领域',
                values: domains,
                onChanged: (value) =>
                    setState(() => _domain = value.isEmpty ? null : value),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactDropdown(
                label: '标签',
                value: selectedTag ?? '',
                allLabel: '全部标签',
                values: tags,
                onChanged: (value) =>
                    setState(() => _tag = value.isEmpty ? null : value),
              ),
            ),
            const SizedBox(width: 6),
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
            message: '可以调整领域、标签或生命周期筛选。',
            action: OutlinedButton(
              onPressed: () => setState(() {
                _domain = null;
                _tag = null;
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
    );
  }

  Future<void> _createGoal(BuildContext context) async {
    await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const GoalEditorPage()),
    );
  }
}

class _CompactDropdown extends StatelessWidget {
  const _CompactDropdown({
    required this.label,
    required this.value,
    required this.allLabel,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String allLabel;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          style: TextStyle(
            fontSize: 12.5,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          items: [
            DropdownMenuItem(value: '', child: Text(allLabel)),
            ...values.map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (value) => onChanged(value ?? ''),
        ),
      ),
    );
  }
}
