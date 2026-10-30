import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/date_utils.dart';
import '../../core/enums.dart';
import '../../core/numbers.dart';
import '../../data/repository.dart';
import '../../models/commitment.dart';
import '../../models/goal.dart';
import '../scope.dart';
import 'common.dart';
import 'pickers.dart';

Future<bool?> showCommitmentSheet(BuildContext context, Goal goal) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) =>
        _CommitmentSheet(repo: RepositoryScope.read(context), goal: goal),
  );
}

Future<bool?> showAdjustCommitmentSheet(
  BuildContext context,
  Commitment commitment,
  Goal goal,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _AdjustCommitmentSheet(
      repo: RepositoryScope.read(context),
      commitment: commitment,
      goal: goal,
    ),
  );
}

class _CommitmentSheet extends StatefulWidget {
  const _CommitmentSheet({required this.repo, required this.goal});

  final GoalRepository repo;
  final Goal goal;

  @override
  State<_CommitmentSheet> createState() => _CommitmentSheetState();
}

class _CommitmentSheetState extends State<_CommitmentSheet> {
  late DateTime _start;
  late DateTime _end;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _targetChildId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = weekStart(now);
    _end = weekEnd(now);
    if (widget.goal.mechanism == Mechanism.milestone) {
      final children = widget.repo.childrenOf(widget.goal.id);
      if (children.isNotEmpty) _targetChildId = children.first.id;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _needsAmount => switch (widget.goal.mechanism) {
    Mechanism.cumulative => true,
    Mechanism.subjective => true,
    Mechanism.metric => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final children = widget.repo.childrenOf(goal.id);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '新建周期承诺',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                MechanismChip(goal.mechanism),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              goal.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _DateBox(
                    label: '开始',
                    value: _start,
                    onTap: () async {
                      final date = await pickDate(
                        context,
                        initial: _start,
                        helpText: '选择承诺开始日期',
                      );
                      if (date != null) setState(() => _start = date);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateBox(
                    label: '结束',
                    value: _end,
                    onTap: () async {
                      final date = await pickDate(
                        context,
                        initial: _end,
                        helpText: '选择承诺结束日期',
                      );
                      if (date != null) setState(() => _end = date);
                    },
                  ),
                ),
              ],
            ),
            if (_needsAmount) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: switch (goal.mechanism) {
                    Mechanism.cumulative => '承诺增量（${goal.unit}）',
                    Mechanism.subjective => '自评推进点数',
                    Mechanism.metric => '期望读数（${goal.unit}）',
                    _ => '数值',
                  },
                  hintText: switch (goal.mechanism) {
                    Mechanism.cumulative => '周期内累计增加多少',
                    Mechanism.subjective => '如 10，表示推进 10 个点',
                    Mechanism.metric => '一个具体读数',
                    _ => '',
                  },
                  errorText: _error,
                ),
              ),
            ],
            if (goal.mechanism == Mechanism.milestone &&
                children.isNotEmpty) ...[
              const SizedBox(height: 14),
              InputDecorator(
                decoration: const InputDecoration(labelText: '指定子项（可选）'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _targetChildId,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('整个里程碑完成'),
                      ),
                      ...children.map(
                        (child) => DropdownMenuItem<String?>(
                          value: child.id,
                          child: Text(
                            child.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _targetChildId = value),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '承诺说明（可选）',
                hintText: '为什么是这个量？',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hint(goal.mechanism),
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('创建承诺'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hint(Mechanism mechanism) => switch (mechanism) {
    Mechanism.completion => '完成型承诺：在这个周期内标记完成即兑现。',
    Mechanism.cumulative => '累积型承诺按周期内真实增量计算，调整承诺会保留历史。',
    Mechanism.metric => '指标型承诺是结果期望，未达不解读为投入不足。',
    Mechanism.subjective => '主观型承诺按自评推进点数计算，系统不判断落后。',
    Mechanism.milestone => '里程碑承诺按指定子项或整个里程碑完成判定。',
  };

  void _submit() {
    if (!_end.isAfter(_start)) {
      setState(() => _error = '结束日期需要晚于开始日期');
      return;
    }
    double? amount;
    if (_needsAmount) {
      amount = parseDouble(_amount.text);
      if (amount == null || amount <= 0) {
        setState(() => _error = '请输入大于 0 的数值');
        return;
      }
    }
    final commitment = widget.repo.createCommitment(
      goalId: widget.goal.id,
      start: _start,
      end: _end,
      plannedAmount: amount,
      targetChildId: widget.goal.mechanism == Mechanism.milestone
          ? _targetChildId
          : null,
      note: _note.text.trim(),
    );
    if (commitment == null) {
      setState(() => _error = '承诺创建失败');
      return;
    }
    Navigator.pop(context, true);
  }
}

class _AdjustCommitmentSheet extends StatefulWidget {
  const _AdjustCommitmentSheet({
    required this.repo,
    required this.commitment,
    required this.goal,
  });

  final GoalRepository repo;
  final Commitment commitment;
  final Goal goal;

  @override
  State<_AdjustCommitmentSheet> createState() => _AdjustCommitmentSheetState();
}

class _AdjustCommitmentSheetState extends State<_AdjustCommitmentSheet> {
  late final TextEditingController _amount;
  final _note = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.commitment.plannedAmount == null
          ? ''
          : formatNumber(widget.commitment.plannedAmount!),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '调整承诺',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            dayRangeText(widget.commitment.start, widget.commitment.end),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(labelText: '新的承诺量', errorText: _error),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '调整说明',
              hintText: '例如：本周出差，下调到 500',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '调整会追加历史记录，不会覆盖原承诺。',
            style: TextStyle(
              fontSize: 11.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _submit, child: const Text('保存调整')),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final amount = parseDouble(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = '请输入大于 0 的数值');
      return;
    }
    widget.repo.adjustCommitment(
      widget.commitment.id,
      plannedAmount: amount,
      note: _note.text.trim().isEmpty ? '调整承诺' : _note.text.trim(),
    );
    Navigator.pop(context, true);
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: InkWell(
        onTap: onTap,
        child: Text(formatDate(value), style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
