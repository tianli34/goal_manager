import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/enums.dart';
import '../../core/numbers.dart';
import '../../data/repository.dart';
import '../../models/goal.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showUpdateSheet(BuildContext context, String goalId) async {
  final repo = RepositoryScope.read(context);
  final goal = repo.goalById(goalId);
  if (goal == null) return;
  if (goal.lifecycle == Lifecycle.terminated) {
    showAppSnack(context, '已终止的目标需要先在详情中恢复', error: true);
    return;
  }

  bool? saved;
  switch (goal.mechanism) {
    case Mechanism.completion:
      saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => _CompletionUpdateSheet(repo: repo, goal: goal),
      );
      break;
    case Mechanism.cumulative:
      saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => _CumulativeUpdateSheet(repo: repo, goal: goal),
      );
      break;
    case Mechanism.metric:
      saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => _MetricUpdateSheet(repo: repo, goal: goal),
      );
      break;
    case Mechanism.subjective:
      saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => _SubjectiveUpdateSheet(repo: repo, goal: goal),
      );
      break;
    case Mechanism.milestone:
      await showNoteSheet(
        context,
        goalId,
        title: '写给里程碑的说明',
        hint: '父级进度由子项上卷；下拉详情可更新子项',
      );
      return;
  }
  if (saved == true && context.mounted) {
    showAppSnack(context, '已记录');
  }
}

Future<void> showNoteSheet(
  BuildContext context,
  String goalId, {
  String title = '写一条说明',
  String hint = '记录事实、变化或判断',
  String initialValue = '',
}) async {
  final repo = RepositoryScope.read(context);
  final controller = TextEditingController(text: initialValue);
  String? error;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => Padding(
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
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: initialValue.isEmpty,
              maxLines: 4,
              decoration: InputDecoration(hintText: hint, errorText: error),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) {
                    setState(() => error = '写点什么再保存');
                    return;
                  }
                  final message = repo.recordNote(goalId, text);
                  if (message != null) {
                    setState(() => error = message);
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('保存记录'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  controller.dispose();
  if (result == true && context.mounted) {
    showAppSnack(context, '已记录');
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompletionUpdateSheet extends StatefulWidget {
  const _CompletionUpdateSheet({required this.repo, required this.goal});

  final GoalRepository repo;
  final Goal goal;

  @override
  State<_CompletionUpdateSheet> createState() => _CompletionUpdateSheetState();
}

class _CompletionUpdateSheetState extends State<_CompletionUpdateSheet> {
  final _note = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.goal.lifecycle == Lifecycle.completed;
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
          _SheetHeader(
            icon: completed ? Icons.replay : Icons.check_circle_outline,
            title: completed ? '重新打开目标' : '完成这个目标',
            subtitle: completed
                ? '完成状态不会因后续记录自动改变，需要你显式重新打开'
                : '完成型目标只有 0% 和 100%，做完即达成',
            color: mechanismColor(Mechanism.completion),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: completed ? '重新打开的原因（可选）' : '完成说明（可选）',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: Icon(completed ? Icons.replay : Icons.check),
              label: Text(completed ? '重新打开' : '标记完成'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final completed = widget.goal.lifecycle == Lifecycle.completed;
    final message = completed
        ? widget.repo.reopen(widget.goal.id, reason: _note.text.trim())
        : widget.repo.markComplete(widget.goal.id, note: _note.text.trim());
    if (message != null) {
      setState(() {
        _busy = false;
        _error = message;
      });
      return;
    }
    if (mounted) Navigator.pop(context, true);
  }
}

class _CumulativeUpdateSheet extends StatefulWidget {
  const _CumulativeUpdateSheet({required this.repo, required this.goal});

  final GoalRepository repo;
  final Goal goal;

  @override
  State<_CumulativeUpdateSheet> createState() => _CumulativeUpdateSheetState();
}

class _CumulativeUpdateSheetState extends State<_CumulativeUpdateSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _adding = true;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
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
            _SheetHeader(
              icon: Icons.trending_up,
              title: '记录增量',
              subtitle:
                  '当前 ${formatNumber(goal.currentValue)} / 目标 ${formatNumber(goal.targetValue)} ${goal.unit}'
                      .trim(),
              color: mechanismColor(Mechanism.cumulative),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('增加'),
                  icon: Icon(Icons.add, size: 16),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('减少'),
                  icon: Icon(Icons.remove, size: 16),
                ),
              ],
              selected: {_adding},
              onSelectionChanged: (value) =>
                  setState(() => _adding = value.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: '增量 ${goal.unit}',
                hintText: '例如 100',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [10, 50, 100, 500]
                  .map(
                    (value) => ActionChip(
                      label: Text('$value'),
                      onPressed: () => _amount.text = '$value',
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '备注（可选）'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(_adding ? '记录增加' : '记录减少'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final amount = parseDouble(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = '请输入大于 0 的增量');
      return;
    }
    final message = widget.repo.recordCumulative(
      widget.goal.id,
      _adding ? amount : -amount,
      note: _note.text.trim(),
    );
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    Navigator.pop(context, true);
  }
}

class _MetricUpdateSheet extends StatefulWidget {
  const _MetricUpdateSheet({required this.repo, required this.goal});

  final GoalRepository repo;
  final Goal goal;

  @override
  State<_MetricUpdateSheet> createState() => _MetricUpdateSheetState();
}

class _MetricUpdateSheetState extends State<_MetricUpdateSheet> {
  late final TextEditingController _reading;
  final _note = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _reading = TextEditingController(
      text: formatNumber(widget.goal.currentValue),
    );
  }

  @override
  void dispose() {
    _reading.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
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
            _SheetHeader(
              icon: Icons.monitor_heart_outlined,
              title: '记录读数',
              subtitle:
                  '起点 ${formatNumber(goal.startValue)} → 目标 ${formatNumber(goal.targetValue)} ${goal.unit}；读数会覆盖当前值，但历史全部保留'
                      .trim(),
              color: mechanismColor(Mechanism.metric),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reading,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
              ],
              decoration: InputDecoration(
                labelText: '当前读数 ${goal.unit}',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '备注（可选）'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('保存读数'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final reading = parseDouble(_reading.text);
    if (reading == null) {
      setState(() => _error = '请输入有效读数');
      return;
    }
    final message = widget.repo.recordMetric(
      widget.goal.id,
      reading,
      note: _note.text.trim(),
    );
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    Navigator.pop(context, true);
  }
}

class _SubjectiveUpdateSheet extends StatefulWidget {
  const _SubjectiveUpdateSheet({required this.repo, required this.goal});

  final GoalRepository repo;
  final Goal goal;

  @override
  State<_SubjectiveUpdateSheet> createState() => _SubjectiveUpdateSheetState();
}

class _SubjectiveUpdateSheetState extends State<_SubjectiveUpdateSheet> {
  late double _percent;
  final _note = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _percent = widget.goal.subjectivePercent.toDouble();
  }

  @override
  void dispose() {
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHeader(
              icon: Icons.edit_note,
              title: '更新自评',
              subtitle: '进度只由你判断，系统不会自动修改，也不会判断“落后”',
              color: mechanismColor(Mechanism.subjective),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '${_percent.round()}%',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: mechanismColor(Mechanism.subjective),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('主观进度')),
              ],
            ),
            Slider(
              value: _percent,
              min: 0,
              max: 100,
              divisions: 20,
              label: '${_percent.round()}%',
              onChanged: (value) => setState(() => _percent = value),
            ),
            TextField(
              controller: _note,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '这段时间发生了什么？（可选）',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('保存自评'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final message = widget.repo.recordSubjective(
      widget.goal.id,
      _percent.round(),
      note: _note.text.trim(),
    );
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    Navigator.pop(context, true);
  }
}
