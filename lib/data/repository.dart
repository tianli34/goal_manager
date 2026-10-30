import 'dart:convert';

import 'package:flutter/foundation.dart';

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

  List<Goal> topLevelGoals({bool includeArchived = false}) {
    return _data.goals
        .where(
          (g) => g.parentGoalId == null && (includeArchived || !g.isArchived),
        )
        .toList();
  }

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
        prepared.lifecycle == Lifecycle.pending) {
      prepared = prepared.copyWith(lifecycle: Lifecycle.active);
    }
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
    final normalized = updated.copyWith(
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

    final changes = <String>[];
    if (old.title != normalized.title) changes.add('标题');
    if (old.why != normalized.why) changes.add('为什么');
    if (old.successCriteria != normalized.successCriteria) changes.add('达成条件');
    if (old.startDate != normalized.startDate) changes.add('开始日期');
    if (old.dueDate != normalized.dueDate) changes.add('截止日期');
    if (old.domain != normalized.domain) changes.add('领域');
    if (old.tags.join('|') != normalized.tags.join('|')) changes.add('标签');
    if (old.executionMode != normalized.executionMode) changes.add('子项模式');
    if (old.unit != normalized.unit) changes.add('单位');
    if (old.startValue != normalized.startValue) changes.add('起始值');
    if (old.targetValue != normalized.targetValue) changes.add('目标值');
    if (old.stableWindow != normalized.stableWindow) changes.add('稳定达标窗口');
    if (old.weight != normalized.weight) changes.add('权重');
    if (old.isRequired != normalized.isRequired) changes.add('是否必需');

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
      goal.copyWith(
        lifecycle: Lifecycle.active,
        completedAt: null,
        updatedAt: time,
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
    _replace(goal.copyWith(lifecycle: status, updatedAt: time));
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
        goal.copyWith(
          parentGoalId: parentId,
          subjectivePercent: goal.subjectivePercent.clamp(0, 100).toInt(),
          stableWindow: goal.stableWindow.clamp(1, 30).toInt(),
          completedAt:
              goal.lifecycle == Lifecycle.completed && goal.completedAt == null
              ? goal.updatedAt
              : goal.completedAt,
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
            if (child.lifecycle == Lifecycle.pending) {
              _replace(
                child.copyWith(lifecycle: Lifecycle.active, updatedAt: time),
              );
              changed = true;
            }
            break;
          }
        } else {
          for (final child in children) {
            if (child.lifecycle == Lifecycle.pending) {
              _replace(
                child.copyWith(lifecycle: Lifecycle.active, updatedAt: time),
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
