import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/date_utils.dart';
import '../core/enums.dart';
import '../core/ids.dart';
import '../data/export.dart';
import '../data/sample_data.dart';
import '../data/storage.dart';
import '../logic/progress.dart';
import '../models/app_data.dart';
import '../models/commitment.dart';
import '../models/goal.dart';
import '../models/inbox_item.dart';
import '../models/json_helpers.dart';
import '../models/review.dart';
import '../models/settings.dart';
import '../models/update_record.dart';

class GoalRepository extends ChangeNotifier {
  GoalRepository(this.storage);

  final AppStorage storage;

  AppData _data = AppData();
  String? loadError;
  String? saveError;
  bool _disposed = false;
  Future<void> _saveQueue = Future<void>.value();

  AppData get data => _data;
  List<Goal> get goals => _data.goals;
  List<UpdateRecord> get records => _data.records;
  List<Commitment> get commitments => _data.commitments;
  List<Review> get reviews => _data.reviews;
  List<InboxItem> get inbox => _data.inbox;
  AppSettings get settings => _data.settings;
  String get storageDescription => storage.description;
  bool get hasData => !_data.isEmpty;

  Goal? goalById(String id) {
    for (final goal in _data.goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  List<Goal> childrenOf(String parentId, {bool includeArchived = false}) {
    return _data.goals
        .where(
          (g) =>
              g.parentGoalId == parentId && (includeArchived || !g.isArchived),
        )
        .toList();
  }

  /// 列表只展示最底层的可执行目标，有可见子项的目标视为容器而不直接出现。
  List<Goal> leafGoals({bool includeArchived = false}) {
    final visible = _data.goals
        .where((g) => includeArchived || !g.isArchived)
        .toList();
    final parentIds = visible
        .map((g) => g.parentGoalId)
        .whereType<String>()
        .toSet();
    return visible.where((g) => !parentIds.contains(g.id)).toList();
  }

  /// 决定是否把「新建」移到标题栏的计数：顶层、未归档、且不属于未激活。
  int get topLevelGoalCount => _data.goals
      .where(
        (g) =>
            g.parentGoalId == null &&
            !g.isArchived &&
            g.lifecycle != Lifecycle.pending &&
            g.lifecycle != Lifecycle.paused,
      )
      .length;

  List<UpdateRecord> recordsFor(String goalId, {bool descending = true}) {
    final list = _data.records.where((r) => r.goalId == goalId).toList();
    list.sort(
      (a, b) => descending
          ? b.timestamp.compareTo(a.timestamp)
          : a.timestamp.compareTo(b.timestamp),
    );
    return list;
  }

  List<Goal> ancestorsOf(Goal goal) {
    final result = <Goal>[];
    final visited = <String>{goal.id};
    var current = goal;
    while (current.parentGoalId != null) {
      final parent = goalById(current.parentGoalId!);
      if (parent == null || !visited.add(parent.id)) break;
      result.add(parent);
      current = parent;
    }
    return result;
  }

  Future<void> init() async {
    try {
      final raw = await storage.read();
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          throw const FormatException('本地数据格式不正确');
        }
        _data = _sanitize(AppData.fromJson(asMap(decoded)));
      }
    } catch (error) {
      loadError = '本地数据读取失败：$error';
      _data = AppData();
    }
    activateScheduledGoals();
  }

  Future<void> flush() => _saveQueue;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _commit() {
    _notify();
    final snapshot = jsonEncode(_data.toJson());
    _saveQueue = _saveQueue.then((_) async {
      try {
        await storage.write(snapshot);
        if (saveError != null) {
          saveError = null;
          _notify();
        }
      } catch (error) {
        saveError = '保存失败：$error';
        _notify();
      }
    });
  }

  void _replace(Goal goal) {
    final index = _data.goals.indexWhere((g) => g.id == goal.id);
    if (index >= 0) _data.goals[index] = goal;
  }

  UpdateRecord _appendRecord({
    required String goalId,
    required RecordType type,
    required DateTime at,
    String note = '',
    String reason = '',
    double? delta,
    double? reading,
    int? subjectivePercent,
    double? valueAfter,
  }) {
    final record = UpdateRecord(
      id: newId(),
      goalId: goalId,
      type: type,
      timestamp: at,
      delta: delta,
      reading: reading,
      subjectivePercent: subjectivePercent,
      valueAfter: valueAfter,
      note: note,
      reason: reason,
    );
    _data.records.add(record);
    return record;
  }

  // ---------------------------------------------------------------- 目标

  void addGoal(Goal goal) {
    if (goalById(goal.id) != null) return;
    final now = DateTime.now();
    var prepared = goal.copyWith(createdAt: now, updatedAt: now);
    final parent = goal.parentGoalId == null
        ? null
        : goalById(goal.parentGoalId!);
    if (parent == null || !parent.isMilestone) {
      prepared = prepared.copyWith(parentGoalId: null);
    } else if (parent.executionMode == ExecutionMode.sequential) {
      prepared = prepared.copyWith(lifecycle: Lifecycle.pending);
    } else if (parent.lifecycle == Lifecycle.active &&
        prepared.lifecycle == Lifecycle.pending &&
        _startReached(prepared, now)) {
      prepared = prepared.copyWith(lifecycle: Lifecycle.active);
    }
    prepared = _ensureStartDate(prepared, now);
    _data.goals.add(prepared);
    _appendRecord(
      goalId: prepared.id,
      type: RecordType.configChange,
      at: now,
      note: '创建目标',
    );
    _applyMilestoneRules(at: now);
    _commit();
  }

  /// 返回错误信息；null 表示成功。
  String? updateGoal(Goal updated, {String reason = ''}) {
    final old = goalById(updated.id);
    if (old == null) return '目标不存在';
    final now = DateTime.now();
    var normalized = updated.copyWith(
      createdAt: old.createdAt,
      updatedAt: now,
      mechanism: old.mechanism,
      lifecycle: old.lifecycle,
      completedAt: old.completedAt,
      isArchived: old.isArchived,
      currentValue: old.currentValue,
      subjectivePercent: old.subjectivePercent,
      parentGoalId: old.parentGoalId,
    );
    normalized = _applyDurationRule(normalized);

    final changes = <String>[];
    if (old.title != normalized.title) changes.add('标题');
    if (old.why != normalized.why) changes.add('为什么');
    if (old.successCriteria != normalized.successCriteria) changes.add('达成条件');
    if (old.startDate != normalized.startDate) changes.add('开始日期');
    // 历史记录里跟随用户选择的叫法，但底层始终是同一个 dueDate 字段。
    if (old.dueDate != normalized.dueDate) {
      changes.add(_data.settings.dueFieldMode.label);
    }
    if (old.domain != normalized.domain) changes.add('领域');
    if (old.tags.join('|') != normalized.tags.join('|')) changes.add('标签');
    if (old.executionMode != normalized.executionMode) changes.add('子项模式');
    if (old.unit != normalized.unit) changes.add('单位');
    if (old.startValue != normalized.startValue) changes.add('起始值');
    if (old.targetValue != normalized.targetValue) changes.add('目标值');
    if (old.stableWindow != normalized.stableWindow) changes.add('稳定达标窗口');
    if (old.weight != normalized.weight) changes.add('权重');
    if (old.isRequired != normalized.isRequired) changes.add('是否必需');

    if (normalized.lifecycle == Lifecycle.active &&
        (normalized.startDate == null ||
            dateOnly(normalized.startDate!).isAfter(dateOnly(now)))) {
      return '进行中的目标必须保留不晚于今天的开始日期';
    }

    _replace(normalized);
    if (changes.isNotEmpty) {
      _appendRecord(
        goalId: normalized.id,
        type: RecordType.configChange,
        at: now,
        note: '修改：${changes.join('、')}',
        reason: reason,
      );
    }
    _applyMilestoneRules(at: now);
    _commit();
    return null;
  }

  String? recordCumulative(
    String goalId,
    double delta, {
    String note = '',
    DateTime? at,
  }) {
    final goal = goalById(goalId);
    if (goal == null) return '目标不存在';
    if (goal.mechanism != Mechanism.cumulative) return '该目标不是累积型';
    if (goal.lifecycle == Lifecycle.terminated) return '已终止的目标需要先恢复';
    final time = at ?? DateTime.now();
    final after = goal.currentValue + delta;
    final updated = goal.copyWith(currentValue: after, updatedAt: time);
    _replace(updated);
    _appendRecord(
      goalId: goalId,
      type: RecordType.progress,
      at: time,
      delta: delta,
      valueAfter: after,
      note: note,
    );
    _autoComplete(updated, time);
    _applyMilestoneRules(at: time);
    _commit();
    return null;
  }

  String? recordMetric(
    String goalId,
    double reading, {
    String note = '',
    DateTime? at,
  }) {
    final goal = goalById(goalId);
    if (goal == null) return '目标不存在';
    if (goal.mechanism != Mechanism.metric) return '该目标不是指标型';
    if (goal.lifecycle == Lifecycle.terminated) return '已终止的目标需要先恢复';
    final time = at ?? DateTime.now();
    final updated = goal.copyWith(currentValue: reading, updatedAt: time);
    _replace(updated);
    _appendRecord(
      goalId: goalId,
      type: RecordType.progress,
      at: time,
      reading: reading,
      valueAfter: reading,
      note: note,
    );
    _autoComplete(updated, time);
    _applyMilestoneRules(at: time);
    _commit();
    return null;
  }

  String? recordSubjective(
    String goalId,
    int percent, {
    String note = '',
    DateTime? at,
  }) {
    final goal = goalById(goalId);
    if (goal == null) return '目标不存在';
    if (goal.mechanism != Mechanism.subjective) return '该目标不是主观型';
    if (goal.lifecycle == Lifecycle.terminated) return '已终止的目标需要先恢复';
    final time = at ?? DateTime.now();
    final value = percent.clamp(0, 100).toInt();
    final updated = goal.copyWith(subjectivePercent: value, updatedAt: time);
    _replace(updated);
    _appendRecord(
      goalId: goalId,
      type: RecordType.progress,
      at: time,
      subjectivePercent: value,
      valueAfter: value.toDouble(),
      note: note,
    );
    _applyMilestoneRules(at: time);
    _commit();
    return null;
  }

  /// 添加上一条不带数值的推进记录，用于“确认无变化”或写说明。
  String? recordNote(String goalId, String note, {DateTime? at}) {
    final goal = goalById(goalId);
    if (goal == null) return '目标不存在';
    if (goal.lifecycle == Lifecycle.terminated) return '已终止的目标需要先恢复';
    final time = at ?? DateTime.now();
    _appendRecord(
      goalId: goalId,
      type: RecordType.progress,
      at: time,
      note: note.trim().isEmpty ? '确认无变化' : note.trim(),
    );
    _replace(goal.copyWith(updatedAt: time));
    _applyMilestoneRules(at: time);
    _commit();
    return null;
  }

  String? markComplete(String goalId, {String note = ''}) {
    final goal = goalById(goalId);
    if (goal == null) return '目标不存在';
    if (goal.lifecycle == Lifecycle.completed) return null;
    if (goal.lifecycle == Lifecycle.terminated) return '已终止的目标需要先恢复';
    if (goal.isMilestone && !milestoneRequirementsMet(goal, _data.goals)) {
      return '还有必需子项未完成，暂时不能完成里程碑';
    }
    final time = DateTime.now();
    _completeGoal(goal, time, note: note.isEmpty ? '标记完成' : '标记完成：$note');
    _applyMilestoneRules(at: time);
    _commit();
    return null;
  }

  String? reopen(String goalId, {String reason = ''}) {
    final goal = goalById(goalId);
    if (goal == null) return '目标不存在';
    if (goal.lifecycle != Lifecycle.completed) return '只有已完成的目标可以重新打开';
    final time = DateTime.now();
    _replace(
      _ensureStartDate(
        goal.copyWith(
          lifecycle: Lifecycle.active,
          completedAt: null,
          updatedAt: time,
        ),
        time,
      ),
    );
    _appendRecord(
      goalId: goalId,
      type: RecordType.reopen,
      at: time,
      note: '重新打开',
      reason: reason,
    );
    _applyMilestoneRules(at: time);
    _commit();
    return null;
  }

  String? changeLifecycle(String goalId, Lifecycle status, {String note = ''}) {
    final goal = goalById(goalId);
    if (goal == null) return '目标不存在';
    if (status == Lifecycle.completed) return markComplete(goalId, note: note);
    if (goal.lifecycle == status) return null;
    if (goal.lifecycle == Lifecycle.completed) {
      return '已完成的目标请使用「重新打开」';
    }
    final time = DateTime.now();
    _replace(
      _ensureStartDate(goal.copyWith(lifecycle: status, updatedAt: time), time),
    );
    _appendRecord(
      goalId: goalId,
      type: RecordType.lifecycleChange,
      at: time,
      note:
          '状态：${goal.lifecycle.label} → ${status.label}'
          '${note.isEmpty ? '' : ' · $note'}',
    );
    _applyMilestoneRules(at: time);
    _commit();
    return null;
  }

  /// 到达定时启动日期的未激活目标转为进行中；日期为空的目标不受影响。
  void activateScheduledGoals({DateTime? at}) {
    final time = at ?? DateTime.now();
    final today = dateOnly(time);
    var changed = false;
    for (final goal in List<Goal>.from(_data.goals)) {
      final start = goal.startDate;
      if (goal.lifecycle != Lifecycle.pending ||
          goal.isArchived ||
          start == null ||
          dateOnly(start).isAfter(today)) {
        continue;
      }
      _replace(
        _ensureStartDate(
          goal.copyWith(lifecycle: Lifecycle.active, updatedAt: time),
          time,
        ),
      );
      _appendRecord(
        goalId: goal.id,
        type: RecordType.lifecycleChange,
        at: time,
        note: '定时启动',
      );
      changed = true;
    }
    if (!changed) return;
    _applyMilestoneRules(at: time);
    _commit();
  }

  bool _startReached(Goal goal, DateTime now) {
    final start = goal.startDate;
    return start == null || !dateOnly(start).isAfter(dateOnly(now));
  }

  /// 进行中的目标必须有开始日期；首次激活时记为激活当天。
  Goal _ensureStartDate(Goal goal, DateTime time) {
    if (goal.lifecycle != Lifecycle.active) return _applyDurationRule(goal);
    final start = goal.startDate;
    final today = dateOnly(time);
    if (start != null && !dateOnly(start).isAfter(today)) {
      return _applyDurationRule(goal);
    }
    return _applyDurationRule(goal.copyWith(startDate: today));
  }

  /// 「期限」是一条规则而非一个日期：结束日期只从开始日期推导。
  /// 没有开始日期时规则先保留，结束日期为空，绝不拿今天兜底。
  /// 创建、编辑、定时启动、状态变更、里程碑激活、导入恢复都会经过这里。
  Goal _applyDurationRule(Goal goal) {
    final rule = goal.durationRule;
    if (rule == null) return goal;
    final start = goal.startDate;
    return goal.copyWith(
      dueDate: start == null
          ? null
          : addCalendarDuration(start, rule.amount, rule.unit),
    );
  }

  /// 旧数据里缺少开始日期的进行中目标，按最早一次激活记录回填。
  DateTime? _legacyStartDate(Goal goal, List<UpdateRecord> records) {
    if (goal.startDate != null || goal.lifecycle != Lifecycle.active) {
      return goal.startDate;
    }
    DateTime? first;
    for (final record in records) {
      if (record.goalId != goal.id ||
          record.type != RecordType.lifecycleChange ||
          !_isActivationNote(record.note)) {
        continue;
      }
      if (first == null || record.timestamp.isBefore(first)) {
        first = record.timestamp;
      }
    }
    return dateOnly(first ?? goal.createdAt);
  }

  bool _isActivationNote(String note) =>
      note.contains('→ 进行中') || note == '定时启动' || note == '重新打开';

  void setArchived(String goalId, bool archived) {
    final goal = goalById(goalId);
    if (goal == null) return;
    final now = DateTime.now();
    final ids = <String>{goalId};
    if (archived) {
      void collect(Goal parent) {
        for (final child in childrenOf(parent.id, includeArchived: true)) {
          if (ids.add(child.id)) collect(child);
        }
      }

      collect(goal);
    }
    for (final goal in _data.goals) {
      if (ids.contains(goal.id) && goal.isArchived != archived) {
        _replace(goal.copyWith(isArchived: archived, updatedAt: now));
      }
    }
    _appendRecord(
      goalId: goalId,
      type: RecordType.configChange,
      at: now,
      note: archived ? '归档目标' : '取消归档',
    );
    _applyMilestoneRules(at: now);
    _commit();
  }

  void detachChild(String childId) {
    final child = goalById(childId);
    if (child == null || child.parentGoalId == null) return;
    final now = DateTime.now();
    final parent = goalById(child.parentGoalId!);
    _replace(child.copyWith(parentGoalId: null, updatedAt: now));
    _appendRecord(
      goalId: childId,
      type: RecordType.configChange,
      at: now,
      note: '从里程碑中移除',
    );
    if (parent != null) {
      _appendRecord(
        goalId: parent.id,
        type: RecordType.configChange,
        at: now,
        note: '移除子项「${child.title}」',
      );
    }
    _applyMilestoneRules(at: now);
    _commit();
  }

  void moveChild(String childId, int direction) {
    final child = goalById(childId);
    if (child == null || child.parentGoalId == null) return;
    final siblings = childrenOf(child.parentGoalId!, includeArchived: true);
    final index = siblings.indexWhere((g) => g.id == childId);
    final targetIndex = index + direction;
    if (index < 0 || targetIndex < 0 || targetIndex >= siblings.length) return;
    final other = siblings[targetIndex];
    final a = _data.goals.indexWhere((g) => g.id == child.id);
    final b = _data.goals.indexWhere((g) => g.id == other.id);
    if (a < 0 || b < 0) return;
    final temp = _data.goals[a];
    _data.goals[a] = _data.goals[b];
    _data.goals[b] = temp;
    _appendRecord(
      goalId: child.parentGoalId!,
      type: RecordType.configChange,
      at: DateTime.now(),
      note: '调整子项顺序',
    );
    _applyMilestoneRules();
    _commit();
  }

  // ---------------------------------------------------------------- 承诺

  Commitment? createCommitment({
    required String goalId,
    required DateTime start,
    required DateTime end,
    double? plannedAmount,
    String? targetChildId,
    String note = '',
  }) {
    final goal = goalById(goalId);
    if (goal == null) return null;
    final commitment = Commitment(
      id: newId(),
      goalId: goalId,
      start: start,
      end: end,
      plannedAmount: plannedAmount,
      baselineValue: goal.mechanism == Mechanism.subjective
          ? goal.subjectivePercent.toDouble()
          : goal.currentValue,
      targetChildId: targetChildId,
      note: note,
    );
    _data.commitments.add(commitment);
    _commit();
    return commitment;
  }

  Commitment? adjustCommitment(
    String commitmentId, {
    double? plannedAmount,
    String note = '调整承诺',
  }) {
    final commitment = _data.commitments
        .where((c) => c.id == commitmentId)
        .toList();
    if (commitment.isEmpty) return null;
    final current = commitment.first;
    final change = CommitmentChange(
      note: note,
      oldAmount: current.plannedAmount,
      newAmount: plannedAmount ?? current.plannedAmount,
    );
    final updated = current.copyWith(
      plannedAmount: plannedAmount ?? current.plannedAmount,
      status: CommitmentStatus.adjusted,
      changes: [...current.changes, change],
    );
    final index = _data.commitments.indexWhere((c) => c.id == commitmentId);
    _data.commitments[index] = updated;
    _commit();
    return updated;
  }

  Commitment? cancelCommitment(String commitmentId, {String note = '取消承诺'}) {
    final index = _data.commitments.indexWhere((c) => c.id == commitmentId);
    if (index < 0) return null;
    final current = _data.commitments[index];
    final updated = current.copyWith(
      status: CommitmentStatus.cancelled,
      changes: [
        ...current.changes,
        CommitmentChange(note: note, oldAmount: current.plannedAmount),
      ],
    );
    _data.commitments[index] = updated;
    _commit();
    return updated;
  }

  List<Commitment> commitmentsBetween(DateTime start, DateTime end) {
    final list =
        _data.commitments
            .where((c) => c.status != CommitmentStatus.cancelled)
            .where((c) => c.start.isBefore(end) && c.end.isAfter(start))
            .toList()
          ..sort((a, b) => a.end.compareTo(b.end));
    return list;
  }

  // ---------------------------------------------------------------- 复盘 / 收集箱 / 设置

  void addReview(Review review) {
    _data.reviews.add(review);
    _commit();
  }

  void addInbox(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    _data.inbox.add(InboxItem(id: newId(), text: value));
    _commit();
  }

  void removeInbox(String id) {
    _data.inbox.removeWhere((item) => item.id == id);
    _commit();
  }

  void updateSettings(AppSettings settings) {
    _data.settings = settings;
    _commit();
  }

  String exportJson() => buildJsonExport(_data);

  String exportMarkdown() => buildMarkdownExport(_data, DateTime.now());

  void importJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('不是有效的 JSON 对象');
    final imported = AppData.fromJson(asMap(decoded));
    _data = _sanitize(imported);
    _commit();
  }

  void loadSample() {
    _data = buildSampleData();
    _commit();
  }

  void clearAll() {
    _data = AppData(settings: _data.settings);
    _commit();
  }

  AppData _sanitize(AppData input) {
    final goalsById = <String, Goal>{};
    for (final goal in input.goals) {
      if (goal.id.isEmpty) continue;
      goalsById[goal.id] = goal;
    }
    final goals = <Goal>[];
    for (final goal in goalsById.values) {
      var parentId = goal.parentGoalId;
      if (parentId != null) {
        final parent = goalsById[parentId];
        if (parent == null ||
            parent.id == goal.id ||
            !parent.isMilestone ||
            _hasParentCycle(goal, goalsById)) {
          parentId = null;
        }
      }
      goals.add(
        _applyDurationRule(
          goal.copyWith(
            parentGoalId: parentId,
            startDate: _legacyStartDate(goal, input.records),
            subjectivePercent: goal.subjectivePercent.clamp(0, 100).toInt(),
            stableWindow: goal.stableWindow.clamp(1, 30).toInt(),
            completedAt:
                goal.lifecycle == Lifecycle.completed &&
                    goal.completedAt == null
                ? goal.updatedAt
                : goal.completedAt,
          ),
        ),
      );
    }
    final ids = goals.map((g) => g.id).toSet();
    final records = input.records.where((r) => ids.contains(r.goalId)).toList();
    final commitments = input.commitments
        .where((c) => ids.contains(c.goalId))
        .map(
          (c) => c.targetChildId != null && !ids.contains(c.targetChildId)
              ? c.copyWith(targetChildId: null)
              : c,
        )
        .toList();
    final reviews = input.reviews
        .map(
          (r) => Review(
            id: r.id,
            start: r.start,
            end: r.end,
            goalIds: r.goalIds.where(ids.contains).toList(),
            whatHappened: r.whatHappened,
            stillWorthPlan: r.stillWorthPlan,
            planReflection: r.planReflection,
            decision: r.decision,
            nextStep: r.nextStep,
            createdAt: r.createdAt,
          ),
        )
        .toList();
    return AppData(
      goals: goals,
      records: records,
      commitments: commitments,
      reviews: reviews,
      inbox: input.inbox,
      settings: input.settings,
    );
  }

  bool _hasParentCycle(Goal goal, Map<String, Goal> goalsById) {
    final visited = <String>{goal.id};
    var current = goal;
    while (current.parentGoalId != null) {
      final parent = goalsById[current.parentGoalId!];
      if (parent == null) return false;
      if (!visited.add(parent.id)) return true;
      current = parent;
    }
    return false;
  }

  // ---------------------------------------------------------------- 内部规则

  void _completeGoal(Goal goal, DateTime at, {required String note}) {
    if (goal.lifecycle == Lifecycle.completed) return;
    _replace(
      goal.copyWith(
        lifecycle: Lifecycle.completed,
        completedAt: at,
        updatedAt: at,
      ),
    );
    _appendRecord(
      goalId: goal.id,
      type: RecordType.lifecycleChange,
      at: at,
      note: note,
    );
  }

  void _autoComplete(Goal goal, DateTime at) {
    if (goal.lifecycle == Lifecycle.completed ||
        goal.lifecycle == Lifecycle.terminated ||
        goal.isArchived) {
      return;
    }
    switch (goal.mechanism) {
      case Mechanism.cumulative:
        if (reachedTarget(goal, goal.currentValue)) {
          _completeGoal(goal, at, note: '自动完成：累计达到目标值');
        }
        break;
      case Mechanism.metric:
        final stable = stableReadingInfo(goal, _data.records);
        if (stable.achieved) {
          _completeGoal(goal, at, note: '自动完成：连续 ${stable.required} 次稳定达标');
        }
        break;
      case Mechanism.milestone:
        if (milestoneRequirementsMet(goal, _data.goals)) {
          _completeGoal(goal, at, note: '自动完成：所有必需子项已完成');
        }
        break;
      case Mechanism.completion:
      case Mechanism.subjective:
        break;
    }
  }

  void _applyMilestoneRules({DateTime? at}) {
    final time = at ?? DateTime.now();
    for (var pass = 0; pass < 8; pass++) {
      var changed = false;

      for (final parent in List<Goal>.from(_data.goals)) {
        if (!parent.isMilestone ||
            parent.isArchived ||
            parent.lifecycle != Lifecycle.active) {
          continue;
        }
        final children = childrenOf(parent.id);
        if (children.isEmpty) continue;
        if (parent.executionMode == ExecutionMode.sequential) {
          for (final child in children) {
            if (child.lifecycle == Lifecycle.completed ||
                child.lifecycle == Lifecycle.terminated) {
              continue;
            }
            if (child.lifecycle == Lifecycle.pending &&
                _startReached(child, time)) {
              _replace(
                _ensureStartDate(
                  child.copyWith(lifecycle: Lifecycle.active, updatedAt: time),
                  time,
                ),
              );
              changed = true;
            }
            break;
          }
        } else {
          for (final child in children) {
            if (child.lifecycle == Lifecycle.pending &&
                _startReached(child, time)) {
              _replace(
                _ensureStartDate(
                  child.copyWith(lifecycle: Lifecycle.active, updatedAt: time),
                  time,
                ),
              );
              changed = true;
            }
          }
        }
      }

      for (final parent in List<Goal>.from(_data.goals)) {
        if (!parent.isMilestone ||
            parent.isArchived ||
            parent.lifecycle == Lifecycle.completed ||
            parent.lifecycle == Lifecycle.terminated) {
          continue;
        }
        if (milestoneRequirementsMet(parent, _data.goals)) {
          _completeGoal(parent, time, note: '自动完成：所有必需子项已完成');
          changed = true;
        }
      }

      if (!changed) break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
