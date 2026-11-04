import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/date_utils.dart';
import '../../core/enums.dart';
import '../../core/ids.dart';
import '../../core/numbers.dart';
import '../../models/goal.dart';
import '../home.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

class GoalEditorPage extends StatefulWidget {
  const GoalEditorPage({super.key, this.goal, this.parent, this.initialTitle});

  final Goal? goal;
  final Goal? parent;
  final String? initialTitle;

  @override
  State<GoalEditorPage> createState() => _GoalEditorPageState();
}

class _GoalEditorPageState extends State<GoalEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _why;
  late final TextEditingController _criteria;
  late final TextEditingController _domain;
  late final TextEditingController _tags;
  late final TextEditingController _unit;
  late final TextEditingController _startValue;
  late final TextEditingController _targetValue;
  late final TextEditingController _currentValue;
  late final TextEditingController _weight;
  late final TextEditingController _reason;

  late Mechanism _mechanism;
  late ExecutionMode _executionMode;
  late bool _isRequired;
  late int _stableWindow;
  late double _subjectivePercent;
  DateTime? _startDate;
  DateTime? _dueDate;

  /// 「期限」输入框。时长规则会随目标一起保存，结束日期由开始日期推导。
  late final TextEditingController _duration;
  late DurationUnit _durationUnit;

  /// 已有日期无法反推成正时长时（无开始日期、或结束日期不晚于开始日期），
  /// 该次编辑临时退回日期选择，并说明原因。
  late bool _durationUsable;
  late String _durationFallbackReason;

  bool get _isEditing => widget.goal != null;
  bool get _hasParent =>
      widget.parent != null || widget.goal?.parentGoalId != null;

  bool get _startsImmediately {
    final start = _startDate;
    return start != null && !dateOnly(start).isAfter(dateOnly(DateTime.now()));
  }

  /// 期限只从开始日期起算；没有开始日期就没有锚点，也不产生结束日期。
  int? get _durationAmount {
    final amount = int.tryParse(_duration.text.trim());
    return amount == null || amount <= 0 ? null : amount;
  }

  String _durationHint() {
    final raw = _duration.text.trim();
    if (raw.isEmpty) return '填写时长后从开始日期推算结束日期；留空表示不设期限。';
    final amount = _durationAmount;
    if (amount == null) return '请输入大于 0 的整数时长。';
    final start = _startDate;
    final unit = _durationUnit.label;
    if (start == null) {
      return '$raw $unit，从开始日期起算；未设置开始日期，暂不计算结束日期，规则会随目标保存。';
    }
    final due = addCalendarDuration(start, amount, _durationUnit);
    return '从 ${formatDate(start)} 起 $raw $unit，结束于 ${formatDate(due)}；改动开始日期会同步顺延。';
  }

  /// 编辑旧目标时，补上开始日期后可以把已有结束日期反推回时长输入。
  void _refreshDurationFromDates() {
    if (_durationUsable || _duration.text.trim().isNotEmpty) return;
    final start = _startDate;
    final due = _dueDate;
    if (start == null || due == null) return;
    final inferred = inferCalendarDuration(start, due);
    if (inferred == null) return;
    setState(() {
      _durationUsable = true;
      _duration.text = '${inferred.amount}';
      _durationUnit = inferred.unit;
    });
  }

  /// 时长输入需要「数字 + 单位下拉」，窄屏下与开始日期并排会被挤没，故改为上下排列。
  Widget _dateFields(bool useDuration, String dueLabel) {
    final startField = _DateField(
      label: _isEditing ? '开始日期' : '定时启动',
      value: _startDate,
      onPick: () async {
        final date = await pickDate(
          context,
          initial: _startDate,
          helpText: _isEditing ? '选择开始日期' : '选择定时启动日期',
        );
        if (date != null) {
          setState(() => _startDate = date);
          _refreshDurationFromDates();
        }
      },
      onClear: _isEditing && widget.goal!.lifecycle == Lifecycle.active
          ? null
          : () => setState(() => _startDate = null),
    );
    final dueField = useDuration
        ? _DurationField(
            controller: _duration,
            unit: _durationUnit,
            onChanged: (_) => setState(() {}),
            onUnitChanged: (unit) => setState(() => _durationUnit = unit),
            onClear: () {
              _duration.clear();
              setState(() {});
            },
          )
        : _DateField(
            label: dueLabel,
            value: _dueDate,
            onPick: () async {
              final date = await pickDate(
                context,
                initial: _dueDate,
                helpText: '选择$dueLabel',
              );
              if (date != null) setState(() => _dueDate = date);
            },
            onClear: () => setState(() => _dueDate = null),
          );
    if (useDuration) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [startField, const SizedBox(height: 10), dueField],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: startField),
        const SizedBox(width: 10),
        Expanded(child: dueField),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _title = TextEditingController(
      text: goal?.title ?? widget.initialTitle ?? '',
    );
    _why = TextEditingController(text: goal?.why ?? '');
    _criteria = TextEditingController(text: goal?.successCriteria ?? '');
    _domain = TextEditingController(text: goal?.domain ?? '');
    _tags = TextEditingController(text: goal?.tags.join('，') ?? '');
    _unit = TextEditingController(text: goal?.unit ?? '');
    _startValue = TextEditingController(
      text: goal == null ? '' : formatNumber(goal.startValue),
    );
    _targetValue = TextEditingController(
      text: goal == null ? '' : formatNumber(goal.targetValue),
    );
    _currentValue = TextEditingController(
      text: goal == null ? '' : formatNumber(goal.currentValue),
    );
    _weight = TextEditingController(
      text: goal == null ? '1' : formatNumber(goal.weight),
    );
    _reason = TextEditingController();
    _mechanism = goal?.mechanism ?? Mechanism.completion;
    _executionMode = goal?.executionMode ?? ExecutionMode.parallel;
    _isRequired = goal?.isRequired ?? true;
    _stableWindow = goal?.stableWindow ?? 3;
    _subjectivePercent = (goal?.subjectivePercent ?? 0).toDouble();
    _startDate = goal?.startDate;
    _dueDate = goal?.dueDate;

    _duration = TextEditingController();
    _durationUnit = DurationUnit.month;
    _durationUsable = true;
    _durationFallbackReason = '';
    final rule = goal?.durationRule;
    if (rule != null) {
      // 有规则时以规则为准，不再拿已有 dueDate 反推。
      _duration.text = '${rule.amount}';
      _durationUnit = rule.unit;
    } else {
      final start = _startDate;
      final due = goal?.dueDate;
      if (due != null) {
        final inferred = start == null
            ? null
            : inferCalendarDuration(start, due);
        if (inferred == null) {
          _durationUsable = false;
          _durationFallbackReason = start == null
              ? '已有结束日期但未设置开始日期，期限无法起算，这里临时改回日期选择；补上开始日期后会自动恢复时长输入。'
              : '当前结束日期不晚于开始日期，无法用正时长表示，这里临时改回日期选择；可在「设置 - 目标表单」切换为「截止日期」。';
        } else {
          _duration.text = '${inferred.amount}';
          _durationUnit = inferred.unit;
        }
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _why.dispose();
    _criteria.dispose();
    _domain.dispose();
    _tags.dispose();
    _unit.dispose();
    _startValue.dispose();
    _targetValue.dispose();
    _currentValue.dispose();
    _weight.dispose();
    _reason.dispose();
    _duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showHome = shouldShowHomeButton(context);
    final dueMode = RepositoryScope.of(context).settings.dueFieldMode;
    final useDuration = dueMode == DueFieldMode.duration && _durationUsable;
    final dueLabel = useDuration ? '期限' : '截止日期';
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '编辑目标' : '新建目标')),
      floatingActionButton: showHome ? const HomeFloatingButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, showHome ? 104 : 32),
        children: [
          if (widget.parent != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '作为「${widget.parent!.title}」的子项',
                style: TextStyle(fontSize: 12.5, color: scheme.primary),
              ),
            ),
          _Section(
            title: '基本信息',
            children: [
              TextField(
                controller: _title,
                autofocus: !_isEditing,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: '目标标题',
                  hintText: '想达成什么？',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _criteria,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '达成条件',
                  hintText: '怎样算达成？',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _why,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '为什么重要',
                  hintText: '写下动机，复盘和正反馈会用到',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: '目标机制',
            children: [
              if (_isEditing)
                _ReadonlyValue(
                  label: '机制',
                  value: '${_mechanism.label} · ${_mechanism.description}',
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mechanism in Mechanism.values)
                      _MechanismOption(
                        mechanism: mechanism,
                        selected: _mechanism == mechanism,
                        onTap: () => setState(() => _mechanism = mechanism),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _mechanism.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_mechanism == Mechanism.cumulative ||
                  _mechanism == Mechanism.metric) ...[
                TextField(
                  controller: _unit,
                  decoration: const InputDecoration(
                    labelText: '单位',
                    hintText: '如 元 / 公里 / 次',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        controller: _startValue,
                        label: '起始值',
                        signed: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _NumberField(
                        controller: _targetValue,
                        label: '目标值',
                        signed: true,
                      ),
                    ),
                  ],
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 12),
                  _NumberField(
                    controller: _currentValue,
                    label: '当前值（可选，默认等于起始值）',
                    signed: true,
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    '当前值由更新记录维护：${formatNumber(widget.goal!.currentValue)} ${widget.goal!.unit}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (_mechanism == Mechanism.metric) ...[
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '稳定达标窗口',
                      helperText: '连续 N 次读数达到目标后自动完成，用于过滤波动',
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _stableWindow,
                        isExpanded: true,
                        items: List.generate(8, (index) => index + 1)
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text('连续 $value 次'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _stableWindow = value);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ],
              if (_mechanism == Mechanism.subjective) ...[
                if (!_isEditing) ...[
                  Row(
                    children: [
                      Text(
                        '初始自评 ${_subjectivePercent.round()}%',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  Slider(
                    value: _subjectivePercent,
                    max: 100,
                    divisions: 20,
                    label: '${_subjectivePercent.round()}%',
                    onChanged: (value) =>
                        setState(() => _subjectivePercent = value),
                  ),
                ] else
                  Text(
                    '当前自评 ${widget.goal!.subjectivePercent}%，请在详情页通过「更新自评」推进',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
              if (_mechanism == Mechanism.milestone) ...[
                Text(
                  '里程碑进度由子项加权上卷，父级不直接填写百分比。',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<ExecutionMode>(
                  segments: const [
                    ButtonSegment(
                      value: ExecutionMode.parallel,
                      label: Text('并列'),
                      icon: Icon(Icons.grid_view, size: 16),
                    ),
                    ButtonSegment(
                      value: ExecutionMode.sequential,
                      label: Text('串行'),
                      icon: Icon(Icons.format_list_numbered, size: 16),
                    ),
                  ],
                  selected: {_executionMode},
                  onSelectionChanged: (value) =>
                      setState(() => _executionMode = value.first),
                ),
                const SizedBox(height: 6),
                Text(
                  '并列：所有子项同时激活。串行：按顺序解锁，可提前开始。',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: '时间与分类',
            children: [
              _dateFields(useDuration, dueLabel),
              const SizedBox(height: 8),
              Text(
                _isEditing
                    ? (widget.goal!.lifecycle == Lifecycle.active
                          ? '进行中的目标必须保留开始日期；$dueLabel可选。'
                          : '日期可选。没有起止日期时，不计算时间线和配速。')
                    : '设为今天或更早：创建后立即启动；设为未来日期：到达当天自动启动；不设置则先保持未激活。',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              if (useDuration) ...[
                const SizedBox(height: 6),
                Text(
                  _durationHint(),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ] else if (dueMode == DueFieldMode.duration) ...[
                const SizedBox(height: 6),
                Text(
                  _durationFallbackReason,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          if (_hasParent) ...[
            const SizedBox(height: 14),
            _Section(
              title: '作为子项',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(controller: _weight, label: '权重'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          '必需子项',
                          style: TextStyle(fontSize: 13),
                        ),
                        value: _isRequired,
                        onChanged: (value) =>
                            setState(() => _isRequired = value),
                      ),
                    ),
                  ],
                ),
                Text(
                  '父级进度按权重加权；只有必需子项全部完成，父级才判定完成。',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          if (_isEditing) ...[
            const SizedBox(height: 14),
            _Section(
              title: '变更原因（可选）',
              children: [
                TextField(
                  controller: _reason,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: '修改目标值、日期或范围的原因，会写入历史',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(
              _isEditing ? '保存修改' : (_startsImmediately ? '启动目标' : '创建目标'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isEditing ? '机制、生命周期和当前值不能在这里直接修改。' : '创建后可通过记录推进，历史会完整保留。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _save() {
    final dueMode = RepositoryScope.read(context).settings.dueFieldMode;
    final useDuration = dueMode == DueFieldMode.duration && _durationUsable;
    final dueLabel = useDuration ? '期限' : '截止日期';
    final rawDuration = _duration.text.trim();
    if (useDuration && rawDuration.isNotEmpty && _durationAmount == null) {
      showAppSnack(context, '请输入大于 0 的整数时长', error: true);
      return;
    }
    // 时长规则随目标保存；只有开始日期存在时才有可写入的结束日期。
    final amount = useDuration ? _durationAmount : null;
    final DateTime? dueDate = useDuration
        ? (_startDate == null || amount == null
              ? null
              : addCalendarDuration(_startDate!, amount, _durationUnit))
        : _dueDate;

    final title = _title.text.trim();
    if (title.isEmpty) {
      showAppSnack(context, '请填写目标标题', error: true);
      return;
    }
    if (_startDate != null &&
        dueDate != null &&
        dueDate.isBefore(_startDate!)) {
      showAppSnack(context, '$dueLabel不能早于开始日期', error: true);
      return;
    }

    final isValueMechanism =
        _mechanism == Mechanism.cumulative || _mechanism == Mechanism.metric;
    var startValue = 0.0;
    var targetValue = 1.0;
    var currentValue = 0.0;
    if (isValueMechanism) {
      startValue = parseDouble(_startValue.text) ?? 0;
      final parsedTarget = parseDouble(_targetValue.text);
      if (parsedTarget == null) {
        showAppSnack(context, '请填写有效的目标值', error: true);
        return;
      }
      targetValue = parsedTarget;
      if (targetValue == startValue) {
        showAppSnack(context, '起始值和目标值不能相同', error: true);
        return;
      }
      currentValue = _isEditing
          ? widget.goal!.currentValue
          : (parseDouble(_currentValue.text) ?? startValue);
    }

    final tags = _tags.text
        .split(RegExp(r'[,，]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    final existing = widget.goal;
    final goal = Goal(
      id: existing?.id ?? newId(),
      title: title,
      why: _why.text.trim(),
      successCriteria: _criteria.text.trim(),
      mechanism: existing?.mechanism ?? _mechanism,
      lifecycle:
          existing?.lifecycle ??
          (_startsImmediately ? Lifecycle.active : Lifecycle.pending),
      startDate: _startDate,
      dueDate: dueDate,
      durationAmount: amount,
      durationUnit: amount == null ? null : _durationUnit,
      domain: _domain.text.trim(),
      tags: tags,
      parentGoalId: existing?.parentGoalId ?? widget.parent?.id,
      weight: parseDouble(_weight.text) ?? 1,
      isRequired: _isRequired,
      isArchived: existing?.isArchived ?? false,
      createdAt: existing?.createdAt ?? DateTime.now(),
      completedAt: existing?.completedAt,
      executionMode: _executionMode,
      unit: _unit.text.trim(),
      startValue: startValue,
      targetValue: targetValue,
      currentValue: currentValue,
      subjectivePercent:
          existing?.subjectivePercent ?? _subjectivePercent.round(),
      stableWindow: _stableWindow,
    );

    final repo = RepositoryScope.read(context);
    if (existing == null) {
      repo.addGoal(goal);
    } else {
      final message = repo.updateGoal(goal, reason: _reason.text.trim());
      if (message != null) {
        showAppSnack(context, message, error: true);
        return;
      }
    }
    Navigator.pop(context, goal.id);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.signed = false,
  });

  final TextEditingController controller;
  final String label;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: signed,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(signed ? r'[0-9.\-]' : r'[0-9.]'),
        ),
      ],
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _MechanismOption extends StatelessWidget {
  const _MechanismOption({
    required this.mechanism,
    required this.selected,
    required this.onTap,
  });

  final Mechanism mechanism;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = mechanismColor(mechanism);
    final foreground = selected ? color : scheme.onSurfaceVariant;
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? color : scheme.outlineVariant,
          width: selected ? 1.2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_mechanismIcon(mechanism), size: 16, color: foreground),
              const SizedBox(width: 5),
              Text(
                mechanism.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _mechanismIcon(Mechanism mechanism) => switch (mechanism) {
  Mechanism.completion => Icons.check_circle_outline,
  Mechanism.cumulative => Icons.stacked_line_chart,
  Mechanism.metric => Icons.trending_up,
  Mechanism.milestone => Icons.account_tree_outlined,
  Mechanism.subjective => Icons.tune,
};

class _ReadonlyValue extends StatelessWidget {
  const _ReadonlyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(value, style: const TextStyle(fontSize: 13)),
    );
  }
}

/// 「期限」= 时长输入：数字 + 日历单位，结束日期由外部按锚点推导。
class _DurationField extends StatelessWidget {
  const _DurationField({
    required this.controller,
    required this.unit,
    required this.onChanged,
    required this.onUnitChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final DurationUnit unit;
  final ValueChanged<String> onChanged;
  final ValueChanged<DurationUnit> onUnitChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: '期限',
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: '清除',
                icon: const Icon(Icons.close, size: 17),
                onPressed: onClear,
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('duration-field'),
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '如 3',
                isCollapsed: true,
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 4),
          DropdownButton<DurationUnit>(
            key: const Key('duration-unit'),
            value: unit,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: DurationUnit.values
                .map(
                  (item) => DropdownMenuItem<DurationUnit>(
                    value: item,
                    child: Text(
                      item.label,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onUnitChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: value != null && onClear != null
            ? IconButton(
                tooltip: '清除',
                icon: const Icon(Icons.close, size: 17),
                onPressed: onClear,
              )
            : const Icon(Icons.calendar_today_outlined, size: 18),
      ),
      child: InkWell(
        onTap: onPick,
        child: Text(
          formatDate(value),
          style: TextStyle(
            fontSize: 13,
            color: value == null
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
          ),
        ),
      ),
    );
  }
}
