import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../core/enums.dart';
import '../../core/ids.dart';
import '../../models/review.dart';
import '../home.dart';
import '../scope.dart';

class ReviewEditorPage extends StatefulWidget {
  const ReviewEditorPage({super.key});

  @override
  State<ReviewEditorPage> createState() => _ReviewEditorPageState();
}

class _ReviewEditorPageState extends State<ReviewEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _whatHappened = TextEditingController();
  final _reflection = TextEditingController();
  final _nextStep = TextEditingController();

  final Set<String> _goalIds = {};
  bool _stillWorthPlan = true;
  ReviewDecision _decision = ReviewDecision.continuePlan;

  @override
  void dispose() {
    _whatHappened.dispose();
    _reflection.dispose();
    _nextStep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    final now = DateTime.now();
    final start = weekStart(now);
    final end = weekEnd(now);
    final goals = repo.goals
        .where((g) => !g.isArchived && g.lifecycle != Lifecycle.terminated)
        .toList();
    final scheme = Theme.of(context).colorScheme;
    final showHome = shouldShowHomeButton(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('新建复盘'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: showHome ? const HomeFloatingButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, showHome ? 104 : 32),
          children: [
            Text(
              '${dayRangeText(start, end)} · 本周期复盘',
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '1 · 发生了什么',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '只写事实：推进了多少、发生了什么变化、哪些没有按计划发生。',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _whatHappened,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: '例如：本周累积记录 3 次，共 +1200；周三没有按计划记录。',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请先记录本周期发生了什么';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            Text(
              '2 · 原计划仍然值得吗',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Card(
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                value: _stillWorthPlan,
                onChanged: (value) => setState(() => _stillWorthPlan = value),
                title: Text(
                  _stillWorthPlan ? '仍然值得' : '需要重新考虑',
                  style: const TextStyle(fontSize: 13.5),
                ),
                subtitle: Text(
                  _stillWorthPlan ? '继续按原方向推进' : '在下方说明哪里需要调整',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reflection,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(hintText: '可选：为什么值得 / 哪部分需要调整'),
            ),
            const SizedBox(height: 22),
            Text(
              '3 · 下一步决定',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReviewDecision.values.map((decision) {
                return ChoiceChip(
                  label: Text(decision.label),
                  selected: _decision == decision,
                  onSelected: (_) => setState(() => _decision = decision),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nextStep,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '可选：一条简短的下一步（不引入任务清单）',
              ),
            ),
            if (goals.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(
                '关联目标',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '可选：这次复盘主要针对哪些目标。',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: goals.map((goal) {
                  final selected = _goalIds.contains(goal.id);
                  return FilterChip(
                    label: Text(goal.title),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _goalIds.add(goal.id);
                        } else {
                          _goalIds.remove(goal.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(onPressed: _save, child: const Text('保存复盘')),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final repo = RepositoryScope.read(context);
    repo.addReview(
      Review(
        id: newId(),
        start: weekStart(now),
        end: weekEnd(now),
        goalIds: _goalIds.toList(),
        whatHappened: _whatHappened.text.trim(),
        stillWorthPlan: _stillWorthPlan,
        planReflection: _reflection.text.trim(),
        decision: _decision,
        nextStep: _nextStep.text.trim(),
        createdAt: now,
      ),
    );
    Navigator.pop(context, true);
  }
}
