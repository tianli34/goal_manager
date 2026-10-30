import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../models/goal.dart';
import '../../models/inbox_item.dart';
import 'common.dart';

Future<DateTime?> pickDate(
  BuildContext context, {
  DateTime? initial,
  String helpText = '选择日期',
}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: DateTime(2000),
    lastDate: DateTime(2200),
    helpText: helpText,
  );
}

Future<Goal?> showGoalPicker(
  BuildContext context,
  List<Goal> goals, {
  String title = '选择目标',
}) {
  return showModalBottomSheet<Goal>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _GoalPickerSheet(goals: goals, title: title),
  );
}

class _GoalPickerSheet extends StatefulWidget {
  const _GoalPickerSheet({required this.goals, required this.title});

  final List<Goal> goals;
  final String title;

  @override
  State<_GoalPickerSheet> createState() => _GoalPickerSheetState();
}

class _GoalPickerSheetState extends State<_GoalPickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.goals
        .where(
          (g) =>
              _query.isEmpty ||
              g.title.toLowerCase().contains(_query.toLowerCase()) ||
              g.domain.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.66,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${filtered.length} 个',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: const InputDecoration(
                  hintText: '搜索标题或领域',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off,
                      title: '没有匹配的目标',
                      compact: true,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final goal = filtered[index];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: Text(
                            goal.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              goal.mechanism.label,
                              goal.lifecycle.label,
                              if (goal.domain.isNotEmpty) goal.domain,
                              if (goal.dueDate != null)
                                '截止 ${formatDate(goal.dueDate)}',
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, goal),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> captureIdeaDialog(BuildContext context) {
  return promptText(
    context,
    title: '捕获一个想法',
    hint: '不要求机制和日期，先记下来',
    maxLines: 4,
    confirmLabel: '放入收集箱',
  );
}

String inboxPreview(InboxItem item) => item.text;
