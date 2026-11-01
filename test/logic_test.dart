import 'package:flutter_test/flutter_test.dart';
import 'package:goal_manager/core/date_utils.dart';
import 'package:goal_manager/core/enums.dart';
import 'package:goal_manager/data/repository.dart';
import 'package:goal_manager/data/storage.dart';
import 'package:goal_manager/logic/commitment_logic.dart';
import 'package:goal_manager/logic/progress.dart';
import 'package:goal_manager/logic/signals.dart';
import 'package:goal_manager/models/app_data.dart';
import 'package:goal_manager/models/goal.dart';
import 'package:goal_manager/models/review.dart';
import 'package:goal_manager/models/settings.dart';
import 'package:goal_manager/models/update_record.dart';

Future<GoalRepository> emptyRepo() async {
  final repo = GoalRepository(MemoryAppStorage());
  await repo.init();
  return repo;
}

Goal goalOf(
  String id,
  Mechanism mechanism, {
  Lifecycle lifecycle = Lifecycle.active,
  double start = 0,
  double target = 100,
  double current = 0,
  double weight = 1,
  bool required = true,
  int stableWindow = 3,
  ExecutionMode executionMode = ExecutionMode.parallel,
  String? parent,
  DateTime? due,
  DateTime? createdAt,
}) {
  return Goal(
    id: id,
    title: id,
    mechanism: mechanism,
    lifecycle: lifecycle,
    startValue: start,
    targetValue: target,
    currentValue: current,
    weight: weight,
    isRequired: required,
    stableWindow: stableWindow,
    executionMode: executionMode,
    parentGoalId: parent,
    dueDate: due,
    createdAt: createdAt,
  );
}

UpdateRecord reading(String goalId, double value, {required DateTime at}) {
  return UpdateRecord(
    id: '$goalId-${at.millisecondsSinceEpoch}',
    goalId: goalId,
    type: RecordType.progress,
    timestamp: at,
    reading: value,
  );
}

void main() {
  group('进度计算', () {
    test('累积型允许负值与超过 100% 的派生比例', () {
      final goal = goalOf(
        'c',
        Mechanism.cumulative,
        start: 0,
        target: 100,
        current: 130,
      );
      expect(computeSnapshot(goal, [goal], []).ratio, 1.3);

      final negative = goalOf(
        'n',
        Mechanism.cumulative,
        start: 0,
        target: 100,
        current: -20,
      );
      expect(computeSnapshot(negative, [negative], []).ratio, -0.2);
    });

    test('指标型按同方向判定并统计连续达标', () {
      final goal = goalOf(
        'm',
        Mechanism.metric,
        start: 80,
        target: 70,
        current: 68,
        stableWindow: 3,
      );
      final base = DateTime(2026, 1, 1);
      final records = [
        reading('m', 72, at: base),
        reading('m', 69, at: base.add(const Duration(days: 1))),
        reading('m', 68, at: base.add(const Duration(days: 2))),
      ];
      final info = stableReadingInfo(goal, records);
      expect(info.count, 2);
      expect(info.achieved, isFalse);
      expect(reachedTarget(goal, 65), isTrue);
      expect(reachedTarget(goal, 75), isFalse);
    });

    test('里程碑按权重上卷子项进度', () {
      final parent = goalOf('p', Mechanism.milestone, target: 1);
      final doneChild = goalOf(
        'a',
        Mechanism.completion,
        lifecycle: Lifecycle.completed,
        parent: 'p',
        weight: 1,
      );
      final halfChild = goalOf(
        'b',
        Mechanism.cumulative,
        parent: 'p',
        weight: 3,
        target: 100,
        current: 50,
      );
      final snapshot = computeSnapshot(parent, [
        parent,
        doneChild,
        halfChild,
      ], []);
      expect(snapshot.ratio, closeTo(0.625, 1e-9));
      expect(snapshot.childDone, 1);
      expect(snapshot.childTotal, 2);
    });

    test('串行里程碑锁定后续子项并聚焦第一个未完成项', () {
      final parent = goalOf(
        'p',
        Mechanism.milestone,
        executionMode: ExecutionMode.sequential,
      );
      final first = goalOf('a', Mechanism.completion, parent: 'p');
      final second = goalOf(
        'b',
        Mechanism.completion,
        parent: 'p',
        lifecycle: Lifecycle.pending,
      );
      final all = [parent, first, second];
      expect(isChildLocked(second, all), isTrue);
      expect(isChildLocked(first, all), isFalse);
      expect(focusedChild(parent, all)?.id, 'a');
    });
  });

  group('仓储规则', () {
    test('累积型达标自动完成，完成后回退不重开', () async {
      final repo = await emptyRepo();
      repo.addGoal(goalOf('c', Mechanism.cumulative, target: 100));

      repo.recordCumulative('c', 120);
      expect(repo.goalById('c')!.lifecycle, Lifecycle.completed);

      repo.recordCumulative('c', -50);
      final goal = repo.goalById('c')!;
      expect(goal.lifecycle, Lifecycle.completed);
      expect(goal.currentValue, 70);
      expect(repo.recordsFor('c').where((r) => r.delta != null).length, 2);
    });

    test('指标型连续稳定达标后自动完成', () async {
      final repo = await emptyRepo();
      repo.addGoal(
        goalOf(
          'm',
          Mechanism.metric,
          start: 80,
          target: 70,
          current: 80,
          stableWindow: 2,
        ),
      );

      repo.recordMetric('m', 72);
      expect(repo.goalById('m')!.lifecycle, Lifecycle.active);
      repo.recordMetric('m', 70);
      expect(repo.goalById('m')!.lifecycle, Lifecycle.active);
      repo.recordMetric('m', 68);
      expect(repo.goalById('m')!.lifecycle, Lifecycle.completed);
    });

    test('串行里程碑逐项解锁，全部必需子项完成后父级完成', () async {
      final repo = await emptyRepo();
      repo.addGoal(
        goalOf(
          'p',
          Mechanism.milestone,
          executionMode: ExecutionMode.sequential,
        ),
      );
      repo.addGoal(goalOf('a', Mechanism.completion, parent: 'p'));
      repo.addGoal(goalOf('b', Mechanism.completion, parent: 'p'));

      expect(repo.goalById('a')!.lifecycle, Lifecycle.active);
      expect(repo.goalById('b')!.lifecycle, Lifecycle.pending);

      repo.markComplete('a');
      expect(repo.goalById('b')!.lifecycle, Lifecycle.active);
      expect(repo.goalById('p')!.lifecycle, Lifecycle.active);

      repo.markComplete('b');
      expect(repo.goalById('p')!.lifecycle, Lifecycle.completed);
    });

    test('并列里程碑子项达标后父级自动完成', () async {
      final repo = await emptyRepo();
      repo.addGoal(goalOf('p', Mechanism.milestone));
      repo.addGoal(goalOf('child', Mechanism.cumulative, parent: 'p'));

      repo.recordCumulative('child', 100);
      expect(repo.goalById('child')!.lifecycle, Lifecycle.completed);
      expect(repo.goalById('p')!.lifecycle, Lifecycle.completed);
    });

    test('到达定时启动日期的目标激活，未来日期保持未激活', () async {
      final repo = await emptyRepo();
      final today = dateOnly(DateTime.now());
      repo.addGoal(
        Goal(
          id: 'today',
          title: 'today',
          lifecycle: Lifecycle.pending,
          startDate: today,
        ),
      );
      repo.addGoal(
        Goal(
          id: 'future',
          title: 'future',
          lifecycle: Lifecycle.pending,
          startDate: today.add(const Duration(days: 2)),
        ),
      );

      repo.activateScheduledGoals();
      expect(repo.goalById('today')!.lifecycle, Lifecycle.active);
      expect(repo.goalById('future')!.lifecycle, Lifecycle.pending);
      expect(repo.recordsFor('today').any((r) => r.note == '定时启动'), isTrue);
    });

    test('重启应用时自动激活已到期的定时启动目标', () async {
      final storage = MemoryAppStorage();
      final repo = GoalRepository(storage);
      await repo.init();
      repo.addGoal(
        Goal(
          id: 'scheduled',
          title: 'scheduled',
          lifecycle: Lifecycle.pending,
          startDate: dateOnly(DateTime.now()),
        ),
      );
      await repo.flush();

      final reopened = GoalRepository(storage);
      await reopened.init();
      expect(reopened.goalById('scheduled')!.lifecycle, Lifecycle.active);
    });

    test('未来定时启动的里程碑子项不会被立即激活', () async {
      final repo = await emptyRepo();
      repo.addGoal(goalOf('p', Mechanism.milestone));
      repo.addGoal(
        Goal(
          id: 'child',
          title: 'child',
          parentGoalId: 'p',
          lifecycle: Lifecycle.pending,
          startDate: dateOnly(DateTime.now()).add(const Duration(days: 3)),
        ),
      );

      expect(repo.goalById('child')!.lifecycle, Lifecycle.pending);
      repo.activateScheduledGoals();
      expect(repo.goalById('child')!.lifecycle, Lifecycle.pending);
    });

    test('启动未激活目标时写入开始日期', () async {
      final repo = await emptyRepo();
      repo.addGoal(Goal(id: 'g', title: 'g', lifecycle: Lifecycle.pending));
      expect(repo.goalById('g')!.startDate, isNull);

      repo.changeLifecycle('g', Lifecycle.active);
      expect(repo.goalById('g')!.lifecycle, Lifecycle.active);
      expect(repo.goalById('g')!.startDate, dateOnly(DateTime.now()));
    });

    test('提前启动未来定时目标时开始日期改为实际启动日', () async {
      final repo = await emptyRepo();
      repo.addGoal(
        Goal(
          id: 'g',
          title: 'g',
          lifecycle: Lifecycle.pending,
          startDate: dateOnly(DateTime.now()).add(const Duration(days: 3)),
        ),
      );

      repo.changeLifecycle('g', Lifecycle.active);
      expect(repo.goalById('g')!.startDate, dateOnly(DateTime.now()));
    });

    test('里程碑子项自动激活时写入开始日期', () async {
      final repo = await emptyRepo();
      repo.addGoal(goalOf('p', Mechanism.milestone));
      repo.addGoal(
        Goal(
          id: 'child',
          title: 'child',
          parentGoalId: 'p',
          lifecycle: Lifecycle.pending,
        ),
      );

      expect(repo.goalById('child')!.lifecycle, Lifecycle.active);
      expect(repo.goalById('child')!.startDate, dateOnly(DateTime.now()));
    });

    test('加载旧数据时为进行中目标回填最早激活日期', () async {
      final repo = await emptyRepo();
      repo.importJson('''
{
  "schemaVersion": 1,
  "goals": [
    {
      "id": "g",
      "title": "旧目标",
      "lifecycle": "active",
      "createdAt": "2026-01-01T09:00:00.000",
      "updatedAt": "2026-02-03T10:00:00.000"
    }
  ],
  "records": [
    {
      "id": "r1",
      "goalId": "g",
      "type": "lifecycleChange",
      "timestamp": "2026-02-03T10:00:00.000",
      "note": "状态：未激活 → 进行中"
    },
    {
      "id": "r2",
      "goalId": "g",
      "type": "lifecycleChange",
      "timestamp": "2026-02-10T10:00:00.000",
      "note": "状态：进行中 → 暂停"
    }
  ]
}
''');

      expect(repo.goalById('g')!.startDate, DateTime(2026, 2, 3));
    });

    test('目标列表只返回最底层叶子目标', () async {
      final repo = await emptyRepo();
      repo.addGoal(goalOf('a', Mechanism.milestone));
      repo.addGoal(goalOf('b', Mechanism.milestone, parent: 'a'));
      repo.addGoal(goalOf('c', Mechanism.completion, parent: 'b'));
      repo.addGoal(goalOf('d', Mechanism.completion));

      expect(repo.leafGoals().map((g) => g.id).toList(), ['c', 'd']);
    });

    test('标题栏新建计数排除归档、未激活与子目标', () async {
      final repo = await emptyRepo();
      repo.addGoal(goalOf('active', Mechanism.completion));
      repo.addGoal(
        goalOf('pending', Mechanism.completion, lifecycle: Lifecycle.pending),
      );
      repo.addGoal(
        goalOf('paused', Mechanism.completion, lifecycle: Lifecycle.paused),
      );
      repo.addGoal(
        goalOf(
          'completed',
          Mechanism.completion,
          lifecycle: Lifecycle.completed,
        ),
      );
      repo.addGoal(goalOf('parent', Mechanism.milestone));
      repo.addGoal(goalOf('child', Mechanism.completion, parent: 'parent'));
      repo.addGoal(goalOf('archived', Mechanism.completion));
      repo.setArchived('archived', true);

      expect(repo.topLevelGoalCount, 3);
    });

    test('标题栏新建标记可随设置持久化', () {
      expect(
        AppSettings.fromJson(AppSettings().toJson()).newGoalInAppBar,
        isFalse,
      );
      expect(
        AppSettings.fromJson(AppSettings(newGoalInAppBar: true).toJson())
            .newGoalInAppBar,
        isTrue,
      );
    });

    test('承诺按周期内真实增量判定，修改目标值不会自动兑现', () async {
      final repo = await emptyRepo();
      repo.addGoal(goalOf('c', Mechanism.cumulative, target: 1000));
      final start = DateTime.now().subtract(const Duration(days: 1));
      final end = DateTime.now().add(const Duration(days: 1));
      final commitment = repo.createCommitment(
        goalId: 'c',
        start: start,
        end: end,
        plannedAmount: 100,
      )!;

      repo.recordCumulative('c', 40);
      var progress = computeCommitmentProgress(
        commitment,
        repo.data,
        DateTime.now(),
      );
      expect(progress.fulfilled, isFalse);

      final goal = repo.goalById('c')!.copyWith(targetValue: 50);
      repo.updateGoal(goal);
      progress = computeCommitmentProgress(
        commitment,
        repo.data,
        DateTime.now(),
      );
      expect(progress.fulfilled, isFalse);
      expect(repo.goalById('c')!.lifecycle, Lifecycle.active);

      repo.recordCumulative('c', 60);
      progress = computeCommitmentProgress(
        commitment,
        repo.data,
        DateTime.now(),
      );
      expect(progress.fulfilled, isTrue);
      expect(progress.ratio, 1);
    });

    test('JSON 导出后可完整恢复，Markdown 可读', () async {
      final repo = await emptyRepo();
      repo.addGoal(goalOf('c', Mechanism.cumulative, target: 100));
      repo.recordCumulative('c', 30, note: '本周推进');
      repo.addInbox('想学做面包');
      repo.addReview(
        Review(
          id: 'r1',
          start: DateTime(2026, 1, 5),
          end: DateTime(2026, 1, 12),
          whatHappened: '完成了一次推进',
          decision: ReviewDecision.continuePlan,
        ),
      );

      final raw = repo.exportJson();
      expect(raw, contains('"schemaVersion": 1'));
      expect(repo.exportMarkdown(), contains('本周推进'));

      final restored = await emptyRepo();
      restored.importJson(raw);
      expect(restored.goals.single.title, 'c');
      expect(restored.goalById('c')!.currentValue, 30);
      expect(restored.records.length, repo.records.length);
      expect(restored.reviews.single.whatHappened, '完成了一次推进');
      expect(restored.inbox.single.text, '想学做面包');
    });
  });

  group('关注信号', () {
    final now = DateTime(2026, 10, 30, 12);

    test('长期未记录触发 noRecentUpdate', () {
      final goal = goalOf(
        'g',
        Mechanism.completion,
        createdAt: now.subtract(const Duration(days: 30)),
      );
      final signals = computeSignals(AppData(goals: [goal]), now);
      expect(signals.single.type, AttentionSignal.noRecentUpdate);
    });

    test('完成型目标临近截止仍未完成触发 dateRisk', () {
      final goal = goalOf(
        'g',
        Mechanism.completion,
        due: now.add(const Duration(days: 2)),
        createdAt: now,
      );
      final signals = computeSignals(AppData(goals: [goal]), now);
      expect(signals.single.type, AttentionSignal.dateRisk);
    });

    test('指标读数不足时输出 insufficientData', () {
      final goal = goalOf(
        'm',
        Mechanism.metric,
        start: 80,
        target: 70,
        current: 80,
        createdAt: now,
      );
      final signals = computeSignals(AppData(goals: [goal]), now);
      expect(signals.single.type, AttentionSignal.insufficientData);
    });
  });
}
